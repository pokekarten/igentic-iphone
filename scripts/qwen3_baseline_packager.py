#!/usr/bin/env python3
"""Package one completed Qwen3 0.6B host baseline run into V0 evidence."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import tempfile
from typing import Any

from evaluate_action_proposals import evaluate
from qwen3_baseline_adapter import (
    BASELINE_SEEDS,
    MODEL_ID,
    MODEL_REVISION,
    NON_THINKING_GENERATION_KWARGS,
    TOKENIZER_ID,
    TOKENIZER_REVISION,
    build_request,
    normalize_file,
)
from qwen3_host_runner import PROMPT_TEMPLATE_ID, PROFILES
from validate_action_benchmark import DEFAULT_BENCHMARK, ValidationError, validate_benchmark
from validate_baseline_run import validate_manifest

ROOT = Path(__file__).resolve().parents[1]
EVALUATOR_CONTRACT = ROOT / "docs/model-research/EVALUATOR_CONTRACT_V0.md"
BENCHMARK_VALIDATOR = ROOT / "scripts/validate_action_benchmark.py"
EVALUATOR_SCRIPT = ROOT / "scripts/evaluate_action_proposals.py"
ADAPTER_SCRIPT = ROOT / "scripts/qwen3_baseline_adapter.py"

RAW_OUTPUTS = "raw-outputs.jsonl"
TOKEN_COUNTS = "token-counts.json"
APPLIED_GENERATION_CONFIG = "applied-generation-config.json"
RUN_METADATA = "run-metadata.json"

NORMALIZED_INPUT = "normalized-input.jsonl"
NORMALIZED_PROPOSALS = "normalized-proposals.jsonl"
EVALUATOR_RESULT = "evaluator-result.json"
BASELINE_MANIFEST = "baseline-run-manifest.json"
OUTPUT_FILENAMES = (
    NORMALIZED_INPUT,
    NORMALIZED_PROPOSALS,
    EVALUATOR_RESULT,
    BASELINE_MANIFEST,
)

LICENSE_REFERENCE = (
    "https://huggingface.co/Qwen/Qwen3-0.6B/blob/"
    f"{MODEL_REVISION}/LICENSE"
)
LICENSE_REVIEW_DATE = "2026-08-15"
NORMALIZER_ID = "qwen3-0.6b-benchmark-v0-normalizer"
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_SAFE_COMPONENT_RE = re.compile(r"^[A-Za-z0-9_.:+-]{1,96}$")

RUN_METADATA_FIELDS = {
    "model_id",
    "model_revision",
    "profile",
    "seed",
    "case_count",
    "device",
    "model_dtype",
    "transformers_version",
    "torch_version",
    "evidence_class",
    "physical_device_run",
    "os",
    "architecture",
    "python_version",
    "prompt_template_id",
    "prompt_template_sha256",
}


def _duplicate_rejecting_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValidationError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _reject_non_finite(value: str) -> None:
    raise ValidationError(f"non-finite JSON number is not allowed: {value}")


def _finite_float(value: str) -> float:
    parsed = float(value)
    if not math.isfinite(parsed):
        raise ValidationError("JSON number exceeds the finite range")
    return parsed


def _load_json(path: Path) -> Any:
    _require_regular_file(path)
    try:
        text = path.read_bytes().decode("utf-8")
    except OSError as exc:
        raise ValidationError(f"cannot read {path.name}: {exc}") from exc
    except UnicodeDecodeError as exc:
        raise ValidationError(f"{path.name} is not valid UTF-8") from exc
    try:
        return json.loads(
            text,
            object_pairs_hook=_duplicate_rejecting_object,
            parse_constant=_reject_non_finite,
            parse_float=_finite_float,
        )
    except json.JSONDecodeError as exc:
        raise ValidationError(f"{path.name} is not valid JSON at line {exc.lineno}") from exc


def _json_bytes(value: Any) -> bytes:
    try:
        return (
            json.dumps(
                value,
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
                allow_nan=False,
            )
            + "\n"
        ).encode("utf-8")
    except (TypeError, ValueError) as exc:
        raise ValidationError("generated evidence is not strict JSON") from exc


def _jsonl_bytes(records: list[dict[str, Any]]) -> bytes:
    try:
        return "".join(
            json.dumps(
                record,
                ensure_ascii=False,
                sort_keys=True,
                allow_nan=False,
            )
            + "\n"
            for record in records
        ).encode("utf-8")
    except (TypeError, ValueError) as exc:
        raise ValidationError("generated normalized input is not strict JSONL") from exc


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_file(path: Path) -> str:
    _require_regular_file(path)
    try:
        digest = hashlib.sha256()
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()
    except OSError as exc:
        raise ValidationError(f"cannot hash {path.name}: {exc}") from exc


def _require_regular_file(path: Path) -> None:
    if path.is_symlink():
        raise ValidationError(f"{path.name} must not be a symlink")
    if not path.is_file():
        raise ValidationError(f"required evidence file is missing: {path.name}")


def _resolve_run_dir(path: Path) -> Path:
    if path.is_symlink():
        raise ValidationError("run directory must not be a symlink")
    try:
        resolved = path.expanduser().resolve(strict=True)
    except OSError as exc:
        raise ValidationError(f"cannot resolve run directory: {exc}") from exc
    if not resolved.is_dir():
        raise ValidationError("run directory must be a directory")
    return resolved


def _safe_text(metadata: dict[str, Any], field: str) -> str:
    value = metadata.get(field)
    if (
        not isinstance(value, str)
        or not value
        or len(value) > 200
        or any(ord(char) < 32 for char in value)
    ):
        raise ValidationError(f"run-metadata.{field} must be non-empty printable text")
    return value


def _safe_component(metadata: dict[str, Any], field: str) -> str:
    value = _safe_text(metadata, field)
    if not _SAFE_COMPONENT_RE.fullmatch(value):
        raise ValidationError(f"run-metadata.{field} contains unsupported characters")
    return value


def _seed_from_dir_name(name: str) -> int:
    if not name.startswith("seed-"):
        raise ValidationError("run directory must be named seed-N")
    suffix = name.removeprefix("seed-")
    if not suffix.isdigit():
        raise ValidationError("run directory must be named seed-N")
    return int(suffix)


def _validate_metadata(
    metadata: Any,
    run_dir: Path,
    expected_case_count: int,
) -> dict[str, Any]:
    if not isinstance(metadata, dict):
        raise ValidationError("run-metadata.json root must be an object")
    missing = sorted(RUN_METADATA_FIELDS - metadata.keys())
    extra = sorted(metadata.keys() - RUN_METADATA_FIELDS)
    if missing:
        raise ValidationError(
            "run-metadata.json missing fields: " + ", ".join(missing)
        )
    if extra:
        raise ValidationError(
            "run-metadata.json has unexpected fields: " + ", ".join(extra)
        )

    if metadata["model_id"] != MODEL_ID:
        raise ValidationError("run metadata model_id does not match the pinned Qwen3 model")
    if metadata["model_revision"] != MODEL_REVISION:
        raise ValidationError(
            "run metadata model_revision does not match the pinned Qwen3 revision"
        )

    profile = metadata["profile"]
    if profile not in PROFILES:
        raise ValidationError("run metadata profile is not a canonical Benchmark V0 profile")
    if run_dir.parent.name != profile:
        raise ValidationError("run directory profile path does not match run metadata")

    seed = metadata["seed"]
    if isinstance(seed, bool) or not isinstance(seed, int) or seed not in BASELINE_SEEDS:
        raise ValidationError("run metadata seed is not in the precommitted seed set")
    if _seed_from_dir_name(run_dir.name) != seed:
        raise ValidationError("run directory seed path does not match run metadata")

    case_count = metadata["case_count"]
    if (
        isinstance(case_count, bool)
        or not isinstance(case_count, int)
        or case_count != expected_case_count
    ):
        raise ValidationError("run metadata case_count does not match Benchmark V0")

    if metadata["evidence_class"] != "host":
        raise ValidationError("Qwen3 V0 evidence packager accepts host evidence only")
    if metadata["physical_device_run"] is not False:
        raise ValidationError("host evidence must not claim a physical-device run")

    if metadata["prompt_template_id"] != PROMPT_TEMPLATE_ID:
        raise ValidationError("run metadata prompt-template identity is not canonical")
    prompt_hash = metadata["prompt_template_sha256"]
    if not isinstance(prompt_hash, str) or not _SHA256_RE.fullmatch(prompt_hash):
        raise ValidationError(
            "run-metadata.prompt_template_sha256 must be a lowercase SHA-256 digest"
        )

    for field in ("device", "model_dtype", "transformers_version", "torch_version", "python_version"):
        _safe_component(metadata, field)
    for field in ("os", "architecture"):
        _safe_text(metadata, field)

    return metadata


def _validate_token_counts(
    value: Any,
    benchmark: list[dict[str, Any]],
    profile: str,
) -> int:
    if not isinstance(value, dict):
        raise ValidationError("token-counts.json root must be an object")
    expected_ids = {record["case_id"] for record in benchmark}
    if set(value) != expected_ids:
        raise ValidationError("token-counts.json case IDs do not match Benchmark V0")
    counts: list[int] = []
    for count in value.values():
        if isinstance(count, bool) or not isinstance(count, int) or count <= 0:
            raise ValidationError("token-counts.json values must be positive integers")
        counts.append(count)
    maximum = max(counts)
    if maximum > PROFILES[profile]["input_limit_tokens"]:
        raise ValidationError("token-counts.json exceeds the canonical profile input limit")
    return maximum


def _validate_generation_config(value: Any, profile: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValidationError("applied-generation-config.json root must be an object")
    for key, expected in NON_THINKING_GENERATION_KWARGS.items():
        actual = value.get(key)
        if type(actual) is not type(expected) or actual != expected:
            raise ValidationError(
                f"applied generation config does not match pinned {key}"
            )
    expected_output = PROFILES[profile]["max_new_tokens"]
    actual_output = value.get("max_new_tokens")
    if (
        isinstance(actual_output, bool)
        or not isinstance(actual_output, int)
        or actual_output != expected_output
    ):
        raise ValidationError(
            "applied generation config max_new_tokens does not match the profile"
        )
    return value


def _canonical_normalized_input(benchmark: list[dict[str, Any]]) -> bytes:
    return _jsonl_bytes([build_request(record) for record in benchmark])


def _source_hash(path: Path) -> str:
    try:
        path.relative_to(ROOT)
    except ValueError as exc:
        raise ValidationError("canonical source path escaped repository root") from exc
    return _sha256_file(path)


def _observations(result: dict[str, Any]) -> tuple[bool, bool]:
    case_results = result.get("case_results")
    if not isinstance(case_results, list):
        raise ValidationError("evaluator result is missing case_results")
    repetition = any(
        isinstance(item, dict) and item.get("repetition_detected") is True
        for item in case_results
    )
    truncation = any(
        isinstance(item, dict) and item.get("truncation_detected") is True
        for item in case_results
    )
    return repetition, truncation


def build_package(run_dir: Path) -> dict[str, bytes]:
    run_dir = _resolve_run_dir(run_dir)
    benchmark = validate_benchmark(DEFAULT_BENCHMARK)

    raw_outputs_path = run_dir / RAW_OUTPUTS
    token_counts_path = run_dir / TOKEN_COUNTS
    generation_config_path = run_dir / APPLIED_GENERATION_CONFIG
    metadata_path = run_dir / RUN_METADATA
    for path in (
        raw_outputs_path,
        token_counts_path,
        generation_config_path,
        metadata_path,
    ):
        _require_regular_file(path)

    metadata = _validate_metadata(
        _load_json(metadata_path),
        run_dir,
        len(benchmark),
    )
    profile = metadata["profile"]
    max_rendered_input_tokens = _validate_token_counts(
        _load_json(token_counts_path),
        benchmark,
        profile,
    )
    generation_config = _validate_generation_config(
        _load_json(generation_config_path),
        profile,
    )
    normalized_input_bytes = _canonical_normalized_input(benchmark)

    with tempfile.TemporaryDirectory(prefix="igentic-qwen-package-") as temp:
        normalized_path = Path(temp) / NORMALIZED_PROPOSALS
        normalize_file(raw_outputs_path, normalized_path)
        normalized_bytes = normalized_path.read_bytes()
        result = evaluate(DEFAULT_BENCHMARK, normalized_path)

    result_bytes = _json_bytes(result)
    repetition_observed, truncation_observed = _observations(result)
    input_limit = PROFILES[profile]["input_limit_tokens"]
    output_limit = PROFILES[profile]["max_new_tokens"]
    adapter_hash = _source_hash(ADAPTER_SCRIPT)

    manifest = {
        "schema_version": "igentic-baseline-run-v0",
        "run_id": (
            f"qwen3-0.6b-v0-{profile.lower()}-seed-{metadata['seed']}"
        ),
        "untouched_baseline": True,
        "benchmark": {
            "version": "V0",
            "path": str(DEFAULT_BENCHMARK.relative_to(ROOT).as_posix()),
            "sha256": _source_hash(DEFAULT_BENCHMARK),
        },
        "evaluator": {
            "contract_version": "V0",
            "contract_path": str(EVALUATOR_CONTRACT.relative_to(ROOT).as_posix()),
            "contract_sha256": _source_hash(EVALUATOR_CONTRACT),
            "benchmark_validator_path": str(
                BENCHMARK_VALIDATOR.relative_to(ROOT).as_posix()
            ),
            "benchmark_validator_sha256": _source_hash(BENCHMARK_VALIDATOR),
            "evaluator_path": str(EVALUATOR_SCRIPT.relative_to(ROOT).as_posix()),
            "evaluator_sha256": _source_hash(EVALUATOR_SCRIPT),
        },
        "backend": {
            "class": "custom_model",
            "framework": "Transformers + PyTorch",
            "framework_version": (
                f"transformers={metadata['transformers_version']};"
                f"torch={metadata['torch_version']}"
            ),
            "model_id": MODEL_ID,
            "model_revision": MODEL_REVISION,
            "system_model_identifier": None,
            "license_reference": LICENSE_REFERENCE,
            "license_review_date": LICENSE_REVIEW_DATE,
            "license_gate_status": "approved",
        },
        "input": {
            "tokenizer_id": TOKENIZER_ID,
            "tokenizer_revision": TOKENIZER_REVISION,
            "prompt_template_id": metadata["prompt_template_id"],
            "prompt_template_sha256": metadata["prompt_template_sha256"],
            "normalized_input_sha256": _sha256_bytes(normalized_input_bytes),
            "max_rendered_input_tokens": max_rendered_input_tokens,
            "token_counts_path": TOKEN_COUNTS,
            "token_counts_sha256": _sha256_file(token_counts_path),
        },
        "normalizer": {
            "id": NORMALIZER_ID,
            "revision": adapter_hash,
        },
        "profile": {
            "name": profile,
            "context_limit_tokens": input_limit + output_limit,
            "input_limit_tokens": input_limit,
            "output_limit_tokens": output_limit,
        },
        "decoding": {
            "sampling_enabled": generation_config["do_sample"],
            "temperature": generation_config["temperature"],
            "top_p": generation_config["top_p"],
            "top_k": generation_config["top_k"],
            "max_output_tokens": generation_config["max_new_tokens"],
            "seed_supported": True,
            "seed": metadata["seed"],
            "applied_config_path": APPLIED_GENERATION_CONFIG,
            "applied_config_sha256": _sha256_file(generation_config_path),
        },
        "execution": {
            "environment": (
                "qwen3-host-runner-v0;"
                f"python={metadata['python_version']};"
                f"device={metadata['device']};"
                f"dtype={metadata['model_dtype']}"
            ),
            "os": metadata["os"],
            "architecture": metadata["architecture"],
            "evidence_class": "host",
            "physical_device_run": False,
            "device_model": None,
            "device_os_build": None,
        },
        "artifacts": {
            "normalized_proposals_path": NORMALIZED_PROPOSALS,
            "normalized_proposals_sha256": _sha256_bytes(normalized_bytes),
            "evaluator_result_path": EVALUATOR_RESULT,
            "evaluator_result_sha256": _sha256_bytes(result_bytes),
        },
        "observations": {
            "repetition_observed": repetition_observed,
            "truncation_observed": truncation_observed,
            "timeout_observed": False,
            "cancellation_observed": False,
            "termination_reason": "completed",
        },
        "specialization": {
            "training_performed": False,
            "fine_tuning_performed": False,
            "model_adapter_applied": False,
            "model_adapter_id": None,
            "model_adapter_revision": None,
        },
        "claims": {
            "physical_device_readiness_claimed": False,
        },
        "known_limitations": [
            "Host evidence only; this package does not establish physical iPhone Air behavior.",
            (
                "The packager does not infer repetition or truncation independently; "
                "those observations aggregate explicit normalized proposal flags only."
            ),
        ],
        "next_decision": "unverified",
    }
    manifest_errors = validate_manifest(manifest)
    if manifest_errors:
        raise ValidationError(
            "generated baseline manifest violates V0: "
            + "; ".join(manifest_errors)
        )

    return {
        NORMALIZED_INPUT: normalized_input_bytes,
        NORMALIZED_PROPOSALS: normalized_bytes,
        EVALUATOR_RESULT: result_bytes,
        BASELINE_MANIFEST: _json_bytes(manifest),
    }


def _ensure_outputs_absent(run_dir: Path) -> None:
    existing = [
        name for name in OUTPUT_FILENAMES if (run_dir / name).exists()
    ]
    if existing:
        raise ValidationError(
            "refusing to package because target evidence files already exist: "
            + ", ".join(existing)
        )


def package_run(run_dir: Path) -> None:
    run_dir = _resolve_run_dir(run_dir)
    _ensure_outputs_absent(run_dir)
    package = build_package(run_dir)
    _ensure_outputs_absent(run_dir)

    created: list[Path] = []
    try:
        for name in OUTPUT_FILENAMES:
            target = run_dir / name
            with target.open("xb") as handle:
                handle.write(package[name])
            created.append(target)
    except OSError as exc:
        for target in created:
            try:
                target.unlink()
            except OSError:
                pass
        raise ValidationError("could not write complete evidence package") from exc


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--run-dir",
        type=Path,
        required=True,
        help="one completed <profile>/seed-N directory from qwen3_host_runner.py",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        package_run(args.run_dir)
    except ValidationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    print(f"Packaged Qwen3 V0 host evidence: {args.run_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
