from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

import torch
from torch import nn
import torch.nn.functional as F

try:
    import regex as unicode_regex
except ImportError as exc:  # pragma: no cover - preflight message
    raise RuntimeError("native tokenizer requires the already-lightweight 'regex' package") from exc


@dataclass(frozen=True)
class LlamaConfig:
    vocab_size: int
    hidden_size: int
    intermediate_size: int
    num_hidden_layers: int
    num_attention_heads: int
    num_key_value_heads: int
    max_position_embeddings: int = 8192
    rms_norm_eps: float = 1e-5
    rope_theta: float = 10000.0
    bos_token_id: int = 0
    eos_token_id: int = 0
    pad_token_id: int | None = None
    tie_word_embeddings: bool = True

    @property
    def head_dim(self) -> int:
        if self.hidden_size % self.num_attention_heads:
            raise ValueError("hidden_size must be divisible by num_attention_heads")
        return self.hidden_size // self.num_attention_heads

    @classmethod
    def from_json(cls, path: Path) -> "LlamaConfig":
        value = json.loads(path.read_text(encoding="utf-8"))
        if value.get("model_type") != "llama":
            raise ValueError("native lane currently supports model_type=llama only")
        return cls(
            vocab_size=int(value["vocab_size"]),
            hidden_size=int(value["hidden_size"]),
            intermediate_size=int(value["intermediate_size"]),
            num_hidden_layers=int(value["num_hidden_layers"]),
            num_attention_heads=int(value["num_attention_heads"]),
            num_key_value_heads=int(value["num_key_value_heads"]),
            max_position_embeddings=int(value.get("max_position_embeddings", 8192)),
            rms_norm_eps=float(value.get("rms_norm_eps", 1e-5)),
            rope_theta=float(value.get("rope_theta", 10000.0)),
            bos_token_id=int(value.get("bos_token_id", 0)),
            eos_token_id=int(value.get("eos_token_id", 0)),
            pad_token_id=value.get("pad_token_id"),
            tie_word_embeddings=bool(value.get("tie_word_embeddings", True)),
        )


class RMSNorm(nn.Module):
    def __init__(self, hidden_size: int, eps: float) -> None:
        super().__init__()
        self.weight = nn.Parameter(torch.ones(hidden_size))
        self.eps = eps

    def forward(self, hidden_states: torch.Tensor) -> torch.Tensor:
        dtype = hidden_states.dtype
        variance = hidden_states.float().pow(2).mean(-1, keepdim=True)
        hidden_states = hidden_states.float() * torch.rsqrt(variance + self.eps)
        return (self.weight.float() * hidden_states).to(dtype)


def rotate_half(value: torch.Tensor) -> torch.Tensor:
    half = value.shape[-1] // 2
    return torch.cat((-value[..., half:], value[..., :half]), dim=-1)


def apply_rope(q: torch.Tensor, k: torch.Tensor, theta: float, position_offset: int = 0) -> tuple[torch.Tensor, torch.Tensor]:
    head_dim = q.shape[-1]
    if head_dim % 2:
        raise ValueError("RoPE head dimension must be even")
    device = q.device
    inv_freq = 1.0 / (theta ** (torch.arange(0, head_dim, 2, device=device, dtype=torch.float32) / head_dim))
    positions = torch.arange(position_offset, position_offset + q.shape[-2], device=device, dtype=torch.float32)
    freqs = torch.outer(positions, inv_freq)
    emb = torch.cat((freqs, freqs), dim=-1)
    cos = emb.cos()[None, None, :, :].to(q.dtype)
    sin = emb.sin()[None, None, :, :].to(q.dtype)
    return q * cos + rotate_half(q) * sin, k * cos + rotate_half(k) * sin


def repeat_kv(value: torch.Tensor, groups: int) -> torch.Tensor:
    if groups == 1:
        return value
    return value.repeat_interleave(groups, dim=1)


class Attention(nn.Module):
    def __init__(self, config: LlamaConfig) -> None:
        super().__init__()
        hidden = config.hidden_size
        head_dim = config.head_dim
        self.num_heads = config.num_attention_heads
        self.num_kv_heads = config.num_key_value_heads
        if self.num_heads % self.num_kv_heads:
            raise ValueError("num_attention_heads must be divisible by num_key_value_heads")
        self.kv_groups = self.num_heads // self.num_kv_heads
        self.head_dim = head_dim
        self.rope_theta = config.rope_theta
        self.q_proj = nn.Linear(hidden, self.num_heads * head_dim, bias=False)
        self.k_proj = nn.Linear(hidden, self.num_kv_heads * head_dim, bias=False)
        self.v_proj = nn.Linear(hidden, self.num_kv_heads * head_dim, bias=False)
        self.o_proj = nn.Linear(self.num_heads * head_dim, hidden, bias=False)

    def forward(self, hidden_states: torch.Tensor) -> torch.Tensor:
        batch, seq, _ = hidden_states.shape
        q = self.q_proj(hidden_states).view(batch, seq, self.num_heads, self.head_dim).transpose(1, 2)
        k = self.k_proj(hidden_states).view(batch, seq, self.num_kv_heads, self.head_dim).transpose(1, 2)
        v = self.v_proj(hidden_states).view(batch, seq, self.num_kv_heads, self.head_dim).transpose(1, 2)
        q, k = apply_rope(q, k, self.rope_theta)
        k = repeat_kv(k, self.kv_groups)
        v = repeat_kv(v, self.kv_groups)
        scores = torch.matmul(q, k.transpose(-2, -1)) / math.sqrt(self.head_dim)
        causal = torch.ones(seq, seq, device=hidden_states.device, dtype=torch.bool).triu(1)
        scores = scores.masked_fill(causal[None, None, :, :], torch.finfo(scores.dtype).min)
        probabilities = torch.softmax(scores.float(), dim=-1).to(q.dtype)
        output = torch.matmul(probabilities, v).transpose(1, 2).contiguous().view(batch, seq, -1)
        return self.o_proj(output)


class MLP(nn.Module):
    def __init__(self, config: LlamaConfig) -> None:
        super().__init__()
        self.gate_proj = nn.Linear(config.hidden_size, config.intermediate_size, bias=False)
        self.up_proj = nn.Linear(config.hidden_size, config.intermediate_size, bias=False)
        self.down_proj = nn.Linear(config.intermediate_size, config.hidden_size, bias=False)

    def forward(self, hidden_states: torch.Tensor) -> torch.Tensor:
        return self.down_proj(F.silu(self.gate_proj(hidden_states)) * self.up_proj(hidden_states))


class DecoderLayer(nn.Module):
    def __init__(self, config: LlamaConfig) -> None:
        super().__init__()
        self.self_attn = Attention(config)
        self.mlp = MLP(config)
        self.input_layernorm = RMSNorm(config.hidden_size, config.rms_norm_eps)
        self.post_attention_layernorm = RMSNorm(config.hidden_size, config.rms_norm_eps)

    def forward(self, hidden_states: torch.Tensor) -> torch.Tensor:
        hidden_states = hidden_states + self.self_attn(self.input_layernorm(hidden_states))
        hidden_states = hidden_states + self.mlp(self.post_attention_layernorm(hidden_states))
        return hidden_states


class LlamaBackbone(nn.Module):
    def __init__(self, config: LlamaConfig) -> None:
        super().__init__()
        self.embed_tokens = nn.Embedding(config.vocab_size, config.hidden_size)
        self.layers = nn.ModuleList([DecoderLayer(config) for _ in range(config.num_hidden_layers)])
        self.norm = RMSNorm(config.hidden_size, config.rms_norm_eps)

    def forward(self, input_ids: torch.Tensor) -> torch.Tensor:
        hidden_states = self.embed_tokens(input_ids)
        for layer in self.layers:
            hidden_states = layer(hidden_states)
        return self.norm(hidden_states)


class LlamaForCausalLM(nn.Module):
    def __init__(self, config: LlamaConfig) -> None:
        super().__init__()
        self.config = config
        self.model = LlamaBackbone(config)
        self.lm_head = nn.Linear(config.hidden_size, config.vocab_size, bias=False)
        if config.tie_word_embeddings:
            self.lm_head.weight = self.model.embed_tokens.weight

    def forward(self, input_ids: torch.Tensor, labels: torch.Tensor | None = None) -> dict[str, torch.Tensor]:
        logits = self.lm_head(self.model(input_ids))
        result = {"logits": logits}
        if labels is not None:
            shift_logits = logits[:, :-1, :].contiguous().float()
            shift_labels = labels[:, 1:].contiguous()
            result["loss"] = F.cross_entropy(
                shift_logits.view(-1, shift_logits.shape[-1]),
                shift_labels.view(-1),
                ignore_index=-100,
            )
        return result

    @torch.inference_mode()
    def generate_greedy(self, input_ids: torch.Tensor, max_new_tokens: int, eos_token_id: int | None = None) -> torch.Tensor:
        output = input_ids
        for _ in range(max_new_tokens):
            logits = self(output)["logits"][:, -1, :]
            next_id = logits.argmax(dim=-1, keepdim=True)
            output = torch.cat((output, next_id), dim=1)
            if eos_token_id is not None and bool(torch.all(next_id == eos_token_id)):
                break
        return output


def load_hf_safetensors(model: LlamaForCausalLM, path: Path) -> dict[str, Any]:
    try:
        from safetensors.torch import load_file
    except ImportError as exc:  # pragma: no cover
        raise RuntimeError("safetensors is required to load model weights") from exc
    weights = load_file(str(path), device="cpu")
    result = model.load_state_dict(weights, strict=False)
    allowed_missing = {"lm_head.weight"} if model.config.tie_word_embeddings else set()
    missing = set(result.missing_keys) - allowed_missing
    if missing or result.unexpected_keys:
        raise ValueError(f"weight key mismatch: missing={sorted(missing)}, unexpected={sorted(result.unexpected_keys)}")
    if model.config.tie_word_embeddings:
        model.lm_head.weight = model.model.embed_tokens.weight
    return {"tensor_count": len(weights), "missing_tied_keys": sorted(set(result.missing_keys) & allowed_missing)}


# GPT-2 byte-level BPE tokenizer used by the SmolLM2 base tokenizer.
def bytes_to_unicode() -> dict[int, str]:
    bs = list(range(ord("!"), ord("~") + 1)) + list(range(ord("¡"), ord("¬") + 1)) + list(range(ord("®"), ord("ÿ") + 1))
    cs = bs[:]
    n = 0
    for value in range(256):
        if value not in bs:
            bs.append(value)
            cs.append(256 + n)
            n += 1
    return dict(zip(bs, map(chr, cs)))


class GPT2BPETokenizer:
    PATTERN = unicode_regex.compile(r"'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+")

    def __init__(self, vocab: dict[str, int], merges: Iterable[str], special_tokens: dict[str, int] | None = None) -> None:
        self.vocab = vocab
        self.decoder = {value: key for key, value in vocab.items()}
        self.byte_encoder = bytes_to_unicode()
        self.byte_decoder = {value: key for key, value in self.byte_encoder.items()}
        cleaned = [line.strip() for line in merges if line.strip() and not line.startswith("#")]
        self.bpe_ranks = {tuple(line.split()): rank for rank, line in enumerate(cleaned)}
        self.cache: dict[str, tuple[str, ...]] = {}
        self.special_tokens = special_tokens or {}
        self.special_ids = {value: key for key, value in self.special_tokens.items()}

    @classmethod
    def from_pack(cls, root: Path) -> "GPT2BPETokenizer":
        vocab = json.loads((root / "vocab.json").read_text(encoding="utf-8"))
        merges = (root / "merges.txt").read_text(encoding="utf-8").splitlines()
        config_path = root / "tokenizer_config.json"
        specials: dict[str, int] = {}
        if config_path.exists():
            config = json.loads(config_path.read_text(encoding="utf-8"))
            for raw_id, item in config.get("added_tokens_decoder", {}).items():
                if isinstance(item, dict) and item.get("special") and isinstance(item.get("content"), str):
                    specials[item["content"]] = int(raw_id)
        return cls(vocab, merges, specials)

    def _pairs(self, word: tuple[str, ...]) -> set[tuple[str, str]]:
        return set(zip(word, word[1:]))

    def bpe(self, token: str) -> tuple[str, ...]:
        cached = self.cache.get(token)
        if cached is not None:
            return cached
        word = tuple(token)
        if len(word) <= 1:
            self.cache[token] = word
            return word
        while True:
            pairs = self._pairs(word)
            ranked = [(self.bpe_ranks[pair], pair) for pair in pairs if pair in self.bpe_ranks]
            if not ranked:
                break
            _, best = min(ranked)
            first, second = best
            new_word: list[str] = []
            i = 0
            while i < len(word):
                try:
                    j = word.index(first, i)
                except ValueError:
                    new_word.extend(word[i:])
                    break
                new_word.extend(word[i:j])
                i = j
                if i < len(word) - 1 and word[i] == first and word[i + 1] == second:
                    new_word.append(first + second)
                    i += 2
                else:
                    new_word.append(word[i])
                    i += 1
            word = tuple(new_word)
            if len(word) <= 1:
                break
        self.cache[token] = word
        return word

    def encode(self, text: str, add_bos: bool = False, bos_token_id: int = 0) -> list[int]:
        ids: list[int] = [bos_token_id] if add_bos else []
        # Preserve exact special-token strings when they appear in text.
        if self.special_tokens:
            special_pattern = "(" + "|".join(unicode_regex.escape(x) for x in sorted(self.special_tokens, key=len, reverse=True)) + ")"
            chunks = unicode_regex.split(special_pattern, text)
        else:
            chunks = [text]
        for chunk in chunks:
            if not chunk:
                continue
            if chunk in self.special_tokens:
                ids.append(self.special_tokens[chunk])
                continue
            for token in self.PATTERN.findall(chunk):
                byte_token = "".join(self.byte_encoder[value] for value in token.encode("utf-8"))
                for bpe_token in self.bpe(byte_token):
                    try:
                        ids.append(self.vocab[bpe_token])
                    except KeyError as exc:
                        raise ValueError(f"BPE token absent from vocab: {bpe_token!r}") from exc
        return ids

    def decode(self, ids: Iterable[int]) -> str:
        pieces: list[str] = []
        byte_buffer: list[int] = []

        def flush() -> None:
            if byte_buffer:
                pieces.append(bytes(byte_buffer).decode("utf-8", errors="replace"))
                byte_buffer.clear()

        for token_id in ids:
            if token_id in self.special_ids:
                flush()
                pieces.append(self.special_ids[token_id])
                continue
            token = self.decoder[int(token_id)]
            for char in token:
                byte_buffer.append(self.byte_decoder[char])
        flush()
        return "".join(pieces)


class LoRALinear(nn.Module):
    def __init__(self, base: nn.Linear, rank: int, alpha: float, dropout: float) -> None:
        super().__init__()
        if rank < 1:
            raise ValueError("LoRA rank must be positive")
        self.base = base
        for parameter in self.base.parameters():
            parameter.requires_grad = False
        self.lora_A = nn.Parameter(torch.empty(rank, base.in_features, dtype=torch.float32))
        self.lora_B = nn.Parameter(torch.zeros(base.out_features, rank, dtype=torch.float32))
        nn.init.kaiming_uniform_(self.lora_A, a=math.sqrt(5))
        self.scaling = float(alpha) / rank
        self.dropout = nn.Dropout(dropout)

    def forward(self, value: torch.Tensor) -> torch.Tensor:
        base_output = self.base(value)
        update = F.linear(F.linear(self.dropout(value).float(), self.lora_A), self.lora_B) * self.scaling
        return base_output + update.to(base_output.dtype)


def freeze_base_parameters(model: nn.Module) -> None:
    for parameter in model.parameters():
        parameter.requires_grad = False


def inject_lora(model: nn.Module, target_suffixes: tuple[str, ...] = ("q_proj", "v_proj"), rank: int = 8, alpha: float = 16.0, dropout: float = 0.0) -> list[str]:
    replaced: list[str] = []
    for module_name, module in list(model.named_modules()):
        for child_name, child in list(module.named_children()):
            full_name = f"{module_name}.{child_name}" if module_name else child_name
            if child_name in target_suffixes and isinstance(child, nn.Linear):
                setattr(module, child_name, LoRALinear(child, rank, alpha, dropout))
                replaced.append(full_name)
    if not replaced:
        raise ValueError(f"no LoRA target modules found for {target_suffixes}")
    return replaced


def adapter_state_dict(model: nn.Module) -> dict[str, torch.Tensor]:
    return {
        name: parameter.detach().cpu()
        for name, parameter in model.named_parameters()
        if name.endswith("lora_A") or name.endswith("lora_B")
    }


def trainable_parameter_count(model: nn.Module) -> tuple[int, int]:
    total = sum(parameter.numel() for parameter in model.parameters())
    trainable = sum(parameter.numel() for parameter in model.parameters() if parameter.requires_grad)
    return trainable, total


def load_native_pack(root: Path, dtype: torch.dtype | None = None) -> tuple[LlamaForCausalLM, GPT2BPETokenizer]:
    root = root.expanduser().resolve()
    config = LlamaConfig.from_json(root / "config.json")
    model = LlamaForCausalLM(config)
    load_hf_safetensors(model, root / "model.safetensors")
    if dtype is not None:
        model.to(dtype=dtype)
    tokenizer = GPT2BPETokenizer.from_pack(root)
    return model, tokenizer


def main() -> int:
    parser = argparse.ArgumentParser(description="Dependency-light native Llama/SmolLM2 greedy inference.")
    parser.add_argument("--model-path", type=Path, required=True)
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--max-new-tokens", type=int, default=32)
    parser.add_argument("--dtype", choices=["float32", "bfloat16"], default="float32")
    args = parser.parse_args()
    dtype = torch.float32 if args.dtype == "float32" else torch.bfloat16
    model, tokenizer = load_native_pack(args.model_path, dtype=dtype)
    model.eval()
    input_ids = tokenizer.encode(args.prompt)
    tensor = torch.tensor([input_ids], dtype=torch.long)
    generated = model.generate_greedy(tensor, args.max_new_tokens, model.config.eos_token_id)
    print(tokenizer.decode(generated[0, len(input_ids):].tolist()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
