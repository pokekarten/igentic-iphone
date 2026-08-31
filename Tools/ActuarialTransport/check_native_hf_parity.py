from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import torch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from native_smol_runtime import load_native_pack  # noqa: E402

DEFAULT_PROMPTS = [
    "Actuarial parity: Gross=100, Ceded=30. Net=",
    "Für X ~ Poisson(7): Var(X)=",
    "The quick brown fox checks deterministic model parity.",
]


def valid_sha(value: str) -> bool:
    return len(value) == 64 and all(char in "0123456789abcdef" for char in value)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def package_version(name: str) -> str | None:
    try:
        return importlib.metadata.version(name)
    except importlib.metadata.PackageNotFoundError:
        return None


def run(args: argparse.Namespace) -> dict[str, Any]:
    if not valid_sha(args.model_pack_sha256):
        raise ValueError("--model-pack-sha256 must be a lowercase SHA-256")
    try:
        from transformers import AutoModelForCausalLM, AutoTokenizer
    except ImportError as exc:
        raise RuntimeError(
            "parity requires a one-time local Hugging Face reference runtime; install transformers/tokenizers "
            "or run this gate on another trusted machine against the exact same model pack"
        ) from exc

    model_path = args.model_path.expanduser().resolve()
    prompts = args.prompt or DEFAULT_PROMPTS
    if len(prompts) < 3:
        raise ValueError("native parity requires at least three independent prompts")

    hf_tokenizer = AutoTokenizer.from_pretrained(str(model_path), local_files_only=True, use_fast=True)
    hf_model = AutoModelForCausalLM.from_pretrained(
        str(model_path),
        local_files_only=True,
        dtype=torch.float32,
        low_cpu_mem_usage=True,
        attn_implementation="eager",
    )
    hf_model.to(dtype=torch.float32, device="cpu")
    hf_model.eval()

    native_model, native_tokenizer = load_native_pack(model_path, dtype=torch.float32)
    native_model.eval()

    cases: list[dict[str, Any]] = []
    passed = True
    observed_logit_differences: list[float] = []
    for index, prompt in enumerate(prompts, 1):
        hf_ids = hf_tokenizer.encode(prompt, add_special_tokens=False)
        native_ids = native_tokenizer.encode(prompt)
        token_ids_match = hf_ids == native_ids
        case: dict[str, Any] = {
            "case": index,
            "prompt_sha256": hashlib.sha256(prompt.encode("utf-8")).hexdigest(),
            "token_count_hf": len(hf_ids),
            "token_count_native": len(native_ids),
            "token_ids_match": token_ids_match,
        }
        if not token_ids_match:
            case.update(
                {
                    "passed": False,
                    "first_hf_ids": hf_ids[:64],
                    "first_native_ids": native_ids[:64],
                    "reason": "tokenizer_mismatch",
                }
            )
            cases.append(case)
            passed = False
            continue

        input_ids = torch.tensor([hf_ids], dtype=torch.long)
        with torch.inference_mode():
            hf_logits = hf_model(input_ids=input_ids, use_cache=False).logits[:, -1, :].float()
            native_logits = native_model(input_ids)["logits"][:, -1, :].float()
        if hf_logits.shape != native_logits.shape:
            raise ValueError(f"logit shape mismatch: hf={tuple(hf_logits.shape)}, native={tuple(native_logits.shape)}")
        difference = (hf_logits - native_logits).abs()
        max_abs_diff = float(difference.max())
        mean_abs_diff = float(difference.mean())
        observed_logit_differences.append(max_abs_diff)
        hf_argmax = int(hf_logits.argmax(dim=-1).item())
        native_argmax = int(native_logits.argmax(dim=-1).item())
        argmax_match = hf_argmax == native_argmax
        case_passed = argmax_match and max_abs_diff <= args.max_abs_logit_diff
        case.update(
            {
                "max_abs_logit_diff": max_abs_diff,
                "mean_abs_logit_diff": mean_abs_diff,
                "hf_argmax": hf_argmax,
                "native_argmax": native_argmax,
                "argmax_match": argmax_match,
                "passed": case_passed,
            }
        )
        cases.append(case)
        passed = passed and case_passed

    observed_max = max(observed_logit_differences) if observed_logit_differences else None
    return {
        "schema_version": "0.2",
        "receipt_type": "native_hf_model_parity",
        "status": "parity_passed" if passed else "parity_failed",
        "model_id": args.model_id,
        "model_pack_sha256": args.model_pack_sha256,
        "base_revision": args.base_revision,
        "tokenizer_revision": args.tokenizer_revision,
        "reference_engine": "transformers_eager_float32",
        "native_engine": "native_pytorch_llama_float32",
        "max_abs_logit_diff_threshold": args.max_abs_logit_diff,
        "prompt_count": len(cases),
        "tokenizer_all_match": all(case["token_ids_match"] for case in cases),
        "argmax_all_match": all(bool(case.get("argmax_match")) for case in cases),
        "observed_max_abs_logit_diff": observed_max,
        "cases": cases,
        "runtime_versions": {
            "torch": torch.__version__,
            "transformers": package_version("transformers"),
            "tokenizers": package_version("tokenizers"),
            "safetensors": package_version("safetensors"),
            "regex": package_version("regex"),
        },
        "created_at": utc_now(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify native SmolLM2/Llama parity against Hugging Face on the same local bytes.")
    parser.add_argument("--model-path", type=Path, required=True)
    parser.add_argument("--model-id", required=True)
    parser.add_argument("--model-pack-sha256", required=True)
    parser.add_argument("--base-revision", required=True)
    parser.add_argument("--tokenizer-revision", required=True)
    parser.add_argument("--prompt", action="append", help="Optional repeated prompt override; provide at least three")
    parser.add_argument("--max-abs-logit-diff", type=float, default=5e-4)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.max_abs_logit_diff <= 0:
        raise ValueError("max logit difference threshold must be positive")
    receipt = run(args)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(receipt, ensure_ascii=False, indent=2, sort_keys=True, allow_nan=False) + "\n",
        encoding="utf-8",
    )
    print(f"Parity receipt: {args.output}")
    print(f"SHA-256: {sha256_file(args.output)}")
    print(f"Status: {receipt['status']}")
    return 0 if receipt["status"] == "parity_passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
