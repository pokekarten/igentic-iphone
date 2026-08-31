from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def valid_sha(value: Any) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(char in "0123456789abcdef" for char in value)


def validate_acquisition(acquisition: dict[str, Any], pack: dict[str, Any], run: dict[str, Any]) -> None:
    if acquisition.get("receipt_type") != "model_acquisition_verification":
        raise ValueError("baseline requires a model acquisition verification receipt")
    if acquisition.get("status") != "verified":
        raise ValueError("model acquisition is not verified for the training lane")
    if acquisition.get("model_id") != run.get("model_id"):
        raise ValueError("acquisition model_id does not match benchmark run")
    if acquisition.get("upstream_revision") != run.get("base_revision"):
        raise ValueError("acquisition base revision does not match benchmark run")
    if acquisition.get("tokenizer_revision") != run.get("tokenizer_revision"):
        raise ValueError("acquisition tokenizer revision does not match benchmark run")
    if acquisition.get("pack_sha256") != pack.get("pack_sha256"):
        raise ValueError("acquisition pack SHA does not match inspected pack")
    if acquisition.get("pack_kind") != pack.get("pack_kind"):
        raise ValueError("acquisition pack kind does not match inspected pack")
    allowlist = acquisition.get("acquisition_allowlist_validation")
    if not isinstance(allowlist, dict) or allowlist.get("status") != "pack_matches_pinned_acquisition_manifest":
        raise ValueError("acquisition receipt is missing successful pinned allowlist validation")
    if allowlist.get("pack_sha256") != pack.get("pack_sha256"):
        raise ValueError("acquisition allowlist validation pack SHA mismatch")


def build_receipt(
    pack: dict[str, Any],
    run: dict[str, Any],
    score: dict[str, Any],
    acquisition: dict[str, Any],
    acquisition_receipt_sha256: str,
) -> dict[str, Any]:
    if pack.get("pack_kind") != "huggingface_trainable":
        raise ValueError("baseline receipt for training activation requires a huggingface_trainable pack")
    if not valid_sha(pack.get("pack_sha256")):
        raise ValueError("model-pack manifest is missing a valid pack_sha256")
    if run.get("model_pack_sha256") != pack["pack_sha256"]:
        raise ValueError("benchmark run is not bound to the inspected model-pack SHA")
    if not valid_sha(acquisition_receipt_sha256):
        raise ValueError("acquisition verification file is missing a valid SHA-256")
    validate_acquisition(acquisition, pack, run)

    engine = run.get("engine")
    if engine not in {"huggingface_transformers", "native_pytorch_llama"}:
        raise ValueError("baseline run requires an explicitly supported engine")
    native_parity_sha = run.get("native_parity_receipt_sha256")
    if engine == "native_pytorch_llama" and not valid_sha(native_parity_sha):
        raise ValueError("native baseline requires a passed native/Hugging-Face parity receipt")
    if engine == "huggingface_transformers" and native_parity_sha is not None:
        raise ValueError("Hugging Face baseline must not claim a native parity receipt")

    if run.get("adapter_path") is not None:
        raise ValueError("baseline must use unchanged base weights; adapter_path must be null")
    if run.get("data_class", "EVAL_ONLY") != "EVAL_ONLY":
        raise ValueError("baseline receipt requires an EVAL_ONLY run")
    if run.get("benchmark_case_count") != 10:
        raise ValueError("ActuarialBench v0 baseline must contain exactly 10 cases")
    if not valid_sha(run.get("benchmark_sha256")):
        raise ValueError("run metadata is missing benchmark_sha256")
    if not valid_sha(run.get("predictions_sha256")):
        raise ValueError("run metadata is missing predictions_sha256")

    if score.get("benchmark_cases") != 10 or score.get("prediction_cases") != 10:
        raise ValueError("score must contain exactly 10 benchmark and prediction cases")
    if score.get("missing_case_ids") != []:
        raise ValueError("baseline score contains missing benchmark cases")
    if not isinstance(score.get("accuracy"), (int, float)):
        raise ValueError("baseline score is missing numeric accuracy")
    if not valid_sha(score.get("benchmark_sha256")) or not valid_sha(score.get("predictions_sha256")):
        raise ValueError("score is missing benchmark/predictions SHA-256 binding")
    if score["benchmark_sha256"] != run["benchmark_sha256"]:
        raise ValueError("score benchmark SHA does not match run metadata")
    if score["predictions_sha256"] != run["predictions_sha256"]:
        raise ValueError("score predictions SHA does not match run metadata")

    if not isinstance(run.get("model_id"), str) or not run["model_id"]:
        raise ValueError("run metadata is missing model_id")
    if not isinstance(run.get("base_revision"), str) or not run["base_revision"]:
        raise ValueError("run metadata is missing base_revision")
    if not isinstance(run.get("tokenizer_revision"), str) or not run["tokenizer_revision"]:
        raise ValueError("run metadata is missing tokenizer_revision")

    return {
        "schema_version": "0.4",
        "receipt_type": "actuarial_base_model_baseline",
        "status": "baseline_complete",
        "engine": engine,
        "model_id": run["model_id"],
        "base_revision": run["base_revision"],
        "tokenizer_revision": run["tokenizer_revision"],
        "model_pack_sha256": pack["pack_sha256"],
        "acquisition_verification_sha256": acquisition_receipt_sha256,
        "native_parity_receipt_sha256": native_parity_sha,
        "benchmark_sha256": run["benchmark_sha256"],
        "benchmark_case_count": 10,
        "predictions_sha256": run["predictions_sha256"],
        "accuracy": float(score["accuracy"]),
        "passed": int(score.get("passed", 0)),
        "failed": int(score.get("failed", 10)),
        "by_domain": score.get("by_domain", {}),
        "prompt_mode": run.get("prompt_mode"),
        "generation": run.get("generation"),
        "device": run.get("device"),
        "runtime_versions": run.get("runtime_versions", {}),
        "hardware": run.get("hardware", {}),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Create a fail-closed receipt for an unchanged ActuarialBench base-model run.")
    parser.add_argument("--pack-manifest", type=Path, required=True)
    parser.add_argument("--acquisition-verification", type=Path, required=True)
    parser.add_argument("--run-metadata", type=Path, required=True)
    parser.add_argument("--score", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    acquisition_path = args.acquisition_verification.expanduser().resolve()
    receipt = build_receipt(
        load_json(args.pack_manifest),
        load_json(args.run_metadata),
        load_json(args.score),
        load_json(acquisition_path),
        sha256_file(acquisition_path),
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Baseline receipt: {args.output}")
    print(f"SHA-256: {sha256_file(args.output)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
