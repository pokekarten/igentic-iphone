from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import platform
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import torch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from native_parity_gate import valid_sha, validate_parity_file  # noqa: E402
from native_smol_runtime import inject_lora, load_native_pack  # noqa: E402

DEFAULT_BENCHMARK = ROOT / "evals" / "actuarial" / "actuarialbench-v0.jsonl"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def package_versions(names: list[str]) -> dict[str, str | None]:
    result: dict[str, str | None] = {}
    for name in names:
        try:
            result[name] = importlib.metadata.version(name)
        except importlib.metadata.PackageNotFoundError:
            result[name] = None
    return result


def load_cases(path: Path, expected_data_class: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    seen: set[str] = set()
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        value = json.loads(line)
        if not isinstance(value, dict):
            raise ValueError(f"{path}:{line_number}: record must be an object")
        case_id = value.get("case_id")
        if not isinstance(case_id, str) or not case_id or case_id in seen:
            raise ValueError(f"{path}:{line_number}: invalid/duplicate case_id")
        if value.get("data_class") != expected_data_class or value.get("training_eligible") is not False:
            raise ValueError(f"{case_id}: expected {expected_data_class} and training_eligible=false")
        seen.add(case_id)
        rows.append(value)
    if not rows:
        raise ValueError("benchmark/dev surface is empty")
    return rows


def load_adapter(model: torch.nn.Module, adapter_path: Path) -> dict[str, Any]:
    config = json.loads((adapter_path / "adapter-config.json").read_text(encoding="utf-8"))
    if config.get("adapter_type") != "native_lora":
        raise ValueError("unsupported native adapter type")
    targets = tuple(str(x) for x in config["target_modules"])
    inject_lora(
        model,
        target_suffixes=targets,
        rank=int(config["rank"]),
        alpha=float(config["alpha"]),
        dropout=0.0,
    )
    try:
        from safetensors.torch import load_file
    except ImportError as exc:
        raise RuntimeError("safetensors is required to load native adapter") from exc
    weights = load_file(str(adapter_path / "adapter.safetensors"), device="cpu")
    parameters = dict(model.named_parameters())
    unknown = sorted(set(weights) - set(parameters))
    if unknown:
        raise ValueError(f"adapter contains unknown parameters: {unknown}")
    missing: list[str] = []
    for name, parameter in parameters.items():
        if name.endswith("lora_A") or name.endswith("lora_B"):
            tensor = weights.get(name)
            if tensor is None:
                missing.append(name)
            else:
                parameter.data.copy_(tensor.to(parameter.dtype))
    if missing:
        raise ValueError(f"adapter is missing parameters: {missing}")
    return config


def model_memory_mb(model: torch.nn.Module) -> float:
    total = 0
    seen: set[int] = set()
    for parameter in model.parameters():
        pointer = parameter.data_ptr()
        if pointer in seen:
            continue
        seen.add(pointer)
        total += parameter.numel() * parameter.element_size()
    return total / (1024 * 1024)


def run(args: argparse.Namespace) -> None:
    if not valid_sha(args.model_pack_sha256):
        raise ValueError("--model-pack-sha256 must be a lowercase SHA-256")
    parity_sha = validate_parity_file(
        args.parity_receipt,
        model_id=args.model_id,
        model_pack_sha256=args.model_pack_sha256,
        base_revision=args.base_revision,
        tokenizer_revision=args.tokenizer_revision,
    )

    benchmark = args.benchmark.expanduser().resolve()
    cases = load_cases(benchmark, args.data_class)
    output_dir = args.output_dir.expanduser().resolve()
    if output_dir.exists():
        raise ValueError("output directory must not already exist")
    output_dir.mkdir(parents=True)
    raw_dir = output_dir / "raw"
    raw_dir.mkdir()

    dtype = torch.bfloat16 if args.base_dtype == "bfloat16" else torch.float32
    model, tokenizer = load_native_pack(args.model_path, dtype=dtype)
    adapter_config = None
    if args.adapter_path is not None:
        adapter_config = load_adapter(model, args.adapter_path.expanduser().resolve())
    model.eval()
    footprint = model_memory_mb(model)
    started_at = utc_now()
    predictions: list[str] = []

    for case in cases:
        prompt_ids = tokenizer.encode(str(case["prompt"]))
        if not prompt_ids:
            raise ValueError(f"{case['case_id']}: tokenizer produced an empty prompt")
        input_tensor = torch.tensor([prompt_ids], dtype=torch.long)
        started = time.perf_counter()
        generated = model.generate_greedy(input_tensor, args.max_new_tokens, model.config.eos_token_id)
        latency_ms = (time.perf_counter() - started) * 1000.0
        completion_ids = generated[0, len(prompt_ids):].tolist()
        raw_output = tokenizer.decode(completion_ids).replace("<|endoftext|>", "")
        answer = raw_output.strip()
        raw_path = raw_dir / f"{case['case_id']}.txt"
        raw_path.write_text(raw_output, encoding="utf-8")
        prediction = {
            "case_id": case["case_id"],
            "answer": answer,
            "latency_ms": latency_ms,
            "peak_memory_mb": footprint,
            "raw_output_sha256": sha256_file(raw_path),
        }
        predictions.append(json.dumps(prediction, ensure_ascii=False, sort_keys=True) + "\n")
        print(f"{case['case_id']}: {answer!r} ({latency_ms:.1f} ms)")

    predictions_path = output_dir / "predictions.jsonl"
    predictions_path.write_text("".join(predictions), encoding="utf-8")
    finished_at = utc_now()
    metadata = {
        "schema_version": "0.2",
        "engine": "native_pytorch_llama",
        "model_id": args.model_id,
        "model_pack_sha256": args.model_pack_sha256,
        "base_model_path": str(args.model_path.expanduser().resolve()),
        "base_revision": args.base_revision,
        "tokenizer_revision": args.tokenizer_revision,
        "native_parity_receipt_sha256": parity_sha,
        "adapter_path": str(args.adapter_path.expanduser().resolve()) if args.adapter_path else None,
        "adapter_config": adapter_config,
        "benchmark_path": str(benchmark),
        "benchmark_sha256": sha256_file(benchmark),
        "benchmark_case_count": len(cases),
        "data_class": args.data_class,
        "prompt_mode": "plain",
        "generation": {"do_sample": False, "num_beams": 1, "max_new_tokens": args.max_new_tokens},
        "device": "cpu",
        "base_dtype": args.base_dtype,
        "runtime_versions": package_versions(["torch", "safetensors", "regex"]),
        "hardware": {
            "platform": platform.platform(),
            "machine": platform.machine(),
            "python": platform.python_version(),
            "model_memory_footprint_mb": footprint,
        },
        "started_at": started_at,
        "finished_at": finished_at,
        "predictions_sha256": sha256_file(predictions_path),
    }
    (output_dir / "run-metadata.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(f"Predictions: {predictions_path}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run ActuarialBench with the parity-verified native SmolLM2/Llama runtime.")
    parser.add_argument("--model-path", type=Path, required=True)
    parser.add_argument("--adapter-path", type=Path)
    parser.add_argument("--model-id", required=True)
    parser.add_argument("--model-pack-sha256", required=True)
    parser.add_argument("--base-revision", required=True)
    parser.add_argument("--tokenizer-revision", required=True)
    parser.add_argument("--parity-receipt", type=Path, required=True)
    parser.add_argument("--benchmark", type=Path, default=DEFAULT_BENCHMARK)
    parser.add_argument("--data-class", choices=["EVAL_ONLY", "DEV_ONLY"], default="EVAL_ONLY")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--max-new-tokens", type=int, default=16)
    parser.add_argument("--base-dtype", choices=["float32", "bfloat16"], default="float32")
    args = parser.parse_args()
    if args.max_new_tokens < 1:
        raise ValueError("max_new_tokens must be positive")
    run(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
