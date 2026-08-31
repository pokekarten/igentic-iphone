#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import random
import socket
import time
from pathlib import Path


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def block_network() -> None:
    def blocked(*_args, **_kwargs):
        raise RuntimeError("offline production training network guard")
    original = socket.socket
    class GuardedSocket(original):
        def connect(self, *_args, **_kwargs):
            return blocked()
        def connect_ex(self, *_args, **_kwargs):
            return blocked()
    socket.socket = GuardedSocket
    socket.create_connection = blocked
    os.environ["HF_HUB_OFFLINE"] = "1"
    os.environ["TRANSFORMERS_OFFLINE"] = "1"
    os.environ["HF_DATASETS_OFFLINE"] = "1"
    os.environ["WANDB_DISABLED"] = "true"
    os.environ["TOKENIZERS_PARALLELISM"] = "false"


def render_completion(row: dict) -> str:
    expected = row["expected"]
    value = expected["value"]
    if expected["kind"] == "numeric" and isinstance(value, float) and value.is_integer():
        return str(int(value))
    if expected["kind"] in {"numeric", "exact_text", "choice", "tool_required"}:
        return str(value)
    raise RuntimeError(f"unsupported target kind: {expected['kind']}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model-dir", required=True)
    ap.add_argument("--train-jsonl", required=True)
    ap.add_argument("--output-dir", required=True)
    args = ap.parse_args()

    model_dir = Path(args.model_dir).resolve()
    train_path = Path(args.train_jsonl).resolve()
    out = Path(args.output_dir).resolve()
    expected_seed_sha = os.environ["TRAIN_SEED_SHA256"]
    expected_weight_sha = os.environ["BASE_WEIGHT_SHA256"]
    baseline_receipt_sha = os.environ["BASELINE_RECEIPT_SHA256"]
    activation_receipt_sha = os.environ["ACTIVATION_RECEIPT_SHA256"]
    model_pack_sha = os.environ["MODEL_PACK_SHA256"]
    base_revision = os.environ["BASE_REVISION"]
    slm_commit = os.environ["SLM_LAB_COMMIT"]

    if sha256_file(train_path) != expected_seed_sha:
        raise RuntimeError("TRAIN seed SHA mismatch")
    if sha256_file(model_dir / "model.safetensors") != expected_weight_sha:
        raise RuntimeError("base weight SHA mismatch")
    rows = [json.loads(line) for line in train_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(rows) != 120:
        raise RuntimeError("production seed must contain exactly 120 records")
    for row in rows:
        if row.get("data_class") != "TRAIN_ELIGIBLE" or row.get("training_eligible") is not True:
            raise RuntimeError("non-TRAIN_ELIGIBLE row selected")
        if row.get("immutable_eval") is not False:
            raise RuntimeError("immutable EVAL row leaked into training")
        if "EVAL_ONLY" in json.dumps(row, sort_keys=True):
            raise RuntimeError("EVAL marker leaked into training bytes")

    block_network()
    import torch
    import transformers
    import peft
    import accelerate
    import safetensors
    from peft import LoraConfig, TaskType, get_peft_model
    from safetensors.torch import load_file
    from transformers import AutoModelForCausalLM, AutoTokenizer

    seed = 20260831
    random.seed(seed)
    torch.manual_seed(seed)
    tokenizer = AutoTokenizer.from_pretrained(str(model_dir), local_files_only=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    base = AutoModelForCausalLM.from_pretrained(
        str(model_dir), local_files_only=True, dtype=torch.float32, low_cpu_mem_usage=True
    )
    base.config.use_cache = False
    model = get_peft_model(
        base,
        LoraConfig(
            r=8,
            lora_alpha=16,
            lora_dropout=0.0,
            bias="none",
            task_type=TaskType.CAUSAL_LM,
            target_modules=["q_proj", "v_proj"],
        ),
    )
    model.train()
    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total = sum(p.numel() for p in model.parameters())
    optimizer = torch.optim.AdamW([p for p in model.parameters() if p.requires_grad], lr=1e-4)

    def encoded(row: dict):
        prompt_ids = tokenizer.encode(row["prompt"].rstrip() + "\n", add_special_tokens=False)
        completion_ids = tokenizer.encode(render_completion(row), add_special_tokens=False)
        completion_ids.append(int(tokenizer.eos_token_id))
        max_length = 256
        prompt_ids = prompt_ids[-(max_length - len(completion_ids)):]
        ids = torch.tensor([prompt_ids + completion_ids], dtype=torch.long)
        labels = torch.tensor([[-100] * len(prompt_ids) + completion_ids], dtype=torch.long)
        return ids, labels

    with torch.no_grad():
        ids0, labels0 = encoded(rows[0])
        first_loss_before = float(model(input_ids=ids0, labels=labels0).loss)

    micro_losses = []
    optimizer_steps = 0
    started = time.time()
    optimizer.zero_grad(set_to_none=True)
    for index, row in enumerate(rows):
        ids, labels = encoded(row)
        loss = model(input_ids=ids, labels=labels).loss
        if not torch.isfinite(loss):
            raise RuntimeError("non-finite training loss")
        micro_losses.append(float(loss.detach()))
        (loss / 8.0).backward()
        if (index + 1) % 8 == 0 or index + 1 == len(rows):
            torch.nn.utils.clip_grad_norm_([p for p in model.parameters() if p.requires_grad], 1.0)
            optimizer.step()
            optimizer.zero_grad(set_to_none=True)
            optimizer_steps += 1
    elapsed = time.time() - started

    model.eval()
    with torch.no_grad():
        first_loss_after = float(model(input_ids=ids0, labels=labels0).loss)

    out.mkdir(parents=True, exist_ok=False)
    adapter_dir = out / "adapter"
    model.save_pretrained(str(adapter_dir), safe_serialization=True)
    tokenizer.save_pretrained(str(adapter_dir))
    adapter_weight = adapter_dir / "adapter_model.safetensors"
    tensors = load_file(str(adapter_weight), device="cpu")
    nonzero = sum(int(torch.count_nonzero(t).item()) for t in tensors.values())
    elements = sum(t.numel() for t in tensors.values())
    max_abs = max(float(t.abs().max()) for t in tensors.values())
    if nonzero <= 0 or max_abs <= 0:
        raise RuntimeError("adapter remained all-zero")

    receipt = {
        "schema_version": "1.0",
        "receipt_type": "actuarial_production_lora_training",
        "status": "trained_not_yet_promoted",
        "classification": "PRODUCTION_TRAINING",
        "run_id": "TRAIN-20260901-tiny-smollm2-135m-lora-r3",
        "slm_lab_commit": slm_commit,
        "igentic_workflow_commit": os.environ.get("GITHUB_SHA"),
        "model_id": "tiny-actuarial-pipeline",
        "model_pack_sha256": model_pack_sha,
        "base_revision": base_revision,
        "tokenizer_revision": base_revision,
        "base_weight_sha256": expected_weight_sha,
        "authorization": {
            "baseline_receipt_sha256": baseline_receipt_sha,
            "activation_receipt_sha256": activation_receipt_sha,
            "seed_jsonl_sha256": expected_seed_sha,
        },
        "data_boundary": {
            "train_record_count": len(rows),
            "train_data_class": "TRAIN_ELIGIBLE",
            "dev_access_during_training": False,
            "eval_access_during_training": False,
            "source_acceptance_targets_used": False,
        },
        "hyperparameters": {
            "epochs": 1,
            "learning_rate": 1e-4,
            "batch_size": 1,
            "gradient_accumulation_steps": 8,
            "effective_batch_size": 8,
            "max_length": 256,
            "lora_r": 8,
            "lora_alpha": 16,
            "lora_dropout": 0.0,
            "target_modules": ["q_proj", "v_proj"],
            "base_dtype": "float32",
            "completion_only_loss": True,
            "seed": seed,
            "max_grad_norm": 1.0,
        },
        "metrics": {
            "micro_steps": len(micro_losses),
            "optimizer_steps": optimizer_steps,
            "mean_micro_loss": sum(micro_losses) / len(micro_losses),
            "first_8_mean_loss": sum(micro_losses[:8]) / 8,
            "last_8_mean_loss": sum(micro_losses[-8:]) / 8,
            "first_example_loss_before": first_loss_before,
            "first_example_loss_after": first_loss_after,
            "elapsed_seconds": elapsed,
            "all_micro_losses": micro_losses,
        },
        "adapter": {
            "safetensors": adapter_weight.name,
            "sha256": sha256_file(adapter_weight),
            "bytes": adapter_weight.stat().st_size,
            "elements": elements,
            "nonzero_elements": nonzero,
            "max_abs": max_abs,
            "trainable_parameters": trainable,
            "total_parameters_in_peft_model": total,
        },
        "runtime": {
            "python": platform.python_version(),
            "torch": torch.__version__,
            "transformers": transformers.__version__,
            "peft": peft.__version__,
            "accelerate": accelerate.__version__,
            "safetensors": safetensors.__version__,
            "network_guard_enabled_during_compute": True,
        },
    }
    receipt_path = out / "training-receipt.json"
    receipt_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (out / "training-receipt.sha256").write_text(
        sha256_file(receipt_path) + "  training-receipt.json\n", encoding="utf-8"
    )
    print(json.dumps(receipt, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
