#!/usr/bin/env python3
"""Validate an iGentic untouched-backend baseline run manifest V0."""
from __future__ import annotations

import argparse
from datetime import date
import json
from pathlib import Path, PurePosixPath
import re
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "docs/model-research/baseline-run-manifest-v0.example.json"

SCHEMA_VERSION = "igentic-baseline-run-v0"
ALLOWED_BACKEND_CLASSES = {"apple_system", "custom_model"}
ALLOWED_EVIDENCE_CLASSES = {"host", "simulator", "physical_device"}
ALLOWED_PROFILES = {"Router-small", "Router-normal"}
ALLOWED_LICENSE_GATES = {"approved", "blocked", "unverified"}
ALLOWED_DECISIONS = {"keep", "rework", "reject", "unverified"}
ALLOWED_TERMINATION_REASONS = {"completed", "timeout", "cancelled", "error"}

ROOT_FIELDS = {
    "schema_version",
    "run_id",
    "untouched_baseline",
    "benchmark",
    "evaluator",
    "backend",
    "input",
    "normalizer",
    "profile",
    "decoding",
    "execution",
    "artifacts",
    "observations",
    "specialization",
    "claims",
    "known_limitations",
    "next_decision",
}
BENCHMARK_FIELDS = {"version", "path", "sha256"}
EVALUATOR_FIELDS = {
    "contract_version",
    "contract_path",
    "contract_sha256",
    "benchmark_validator_path",
    "benchmark_validator_sha256",
    "evaluator_path",
    "evaluator_sha256",
}
BACKEND_FIELDS = {
    "class",
    "framework",
    "framework_version",
    "model_id",
    "model_revision",
    "system_model_identifier",
    "license_reference",
    "license_review_date",
    "license_gate_status",
}
INPUT_FIELDS = {
    "tokenizer_id",
    "tokenizer_revision",
    "prompt_template_id",
    "prompt_template_sha256",
    "normalized_input_sha256",
}
NORMALIZER_FIELDS = {"id", "revision"}
PROFILE_FIELDS = {
    "name",
    "context_limit_tokens",
    "input_limit_tokens",
    "output_limit_tokens",
}
DECODING_FIELDS = {
    "temperature",
    "top_p",
    "max_output_tokens",
    "seed_supported",
    "seed",
}
EXECUTION_FIELDS = {
    "environment",
    "os",
    "architecture",
    "evidence_class",
    "physical_device_run",
    "device_model",
    "device_os_build",
}
ARTIFACT_FIELDS = {
    "normalized_proposals_path",
    "normalized_proposals_sha256",
    "evaluator_result_path",
    "evaluator_result_sha256",
}
OBSERVATION_FIELDS = {
    "repetition_observed",
    "truncation_observed",
    "timeout_observed",
    "cancellation_observed",
    "termination_reason",
}
SPECIALIZATION_FIELDS = {
    "training_performed",
    "fine_tuning_performed",
    "model_adapter_applied",
    "model_adapter_id",
    "model_adapter_revision",
}
CLAIM_FIELDS = {"physical_device_readiness_claimed"}

SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
IMMUTABLE_REVISION_RE = re.compile(r"^[0-9a-f]{40}([0-9a-f]{24})?$")
RUN_ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{2,79}$")
FORBIDDEN_KEY_FRAGMENTS = {
    "credential",
    "password",
    "private_prompt",
    "secret",
    "serial_number",
    "user_content",
    "user_data",
    "udid",
}
FORBIDDEN_VALUE_PATTERNS = {
    "private key block": re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    "provider-style secret": re.compile(r"\b(?:sk|pk)_[A-Za-z0-9_-]{16,}\b"),
    "OpenAI-style secret": re.compile(r"\bsk-[A-Za-z0-9_-]{16,}\b"),
}


class ValidationError(ValueError):
    """Raised when a baseline manifest cannot be safely interpreted."""


def _object_without_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValidationError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        text = path.read_bytes().decode("utf-8")
    except OSError as exc:
        raise ValidationError(f"cannot read {path}: {exc}") from exc
    except UnicodeDecodeError as exc:
        raise ValidationError(f"{path} is not valid UTF-8: {exc}") from exc

    try:
        value = json.loads(text, object_pairs_hook=_object_without_duplicate_keys)
    except json.JSONDecodeError as exc:
        raise ValidationError(f"{path}: invalid JSON: {exc.msg}") from exc

    if not isinstance(value, dict):
        raise ValidationError(f"{path}: manifest root must be an object")
    return value


def _exact_fields(
    value: Any,
    expected: set[str],
    path: str,
    errors: list[str],
) -> dict[str, Any]:
    if not isinstance(value, dict):
        errors.append(f"{path} must be an object")
        return {}
    missing = sorted(expected - value.keys())
    extra = sorted(value.keys() - expected)
    if missing:
        errors.append(f"{path} missing fields: {', '.join(missing)}")
    if extra:
        errors.append(f"{path} unexpected fields: {', '.join(extra)}")
    return value


def _non_empty_string(value: Any, path: str, errors: list[str]) -> str | None:
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{path} must be a non-empty string")
        return None
    return value


def _nullable_string(value: Any, path: str, errors: list[str]) -> str | None:
    if value is None:
        return None
    return _non_empty_string(value, path, errors)


def _sha256(value: Any, path: str, errors: list[str]) -> None:
    if not isinstance(value, str) or not SHA256_RE.fullmatch(value):
        errors.append(f"{path} must be a lowercase 64-character SHA-256 hex digest")


def _immutable_revision(value: Any, path: str, errors: list[str]) -> None:
    if not isinstance(value, str) or not IMMUTABLE_REVISION_RE.fullmatch(value):
        errors.append(
            f"{path} must be a full lowercase 40- or 64-character immutable hex revision"
        )


def _relative_path(value: Any, path: str, errors: list[str]) -> None:
    text = _non_empty_string(value, path, errors)
    if text is None:
        return
    candidate = PurePosixPath(text)
    if candidate.is_absolute() or ".." in candidate.parts or "\\" in text:
        errors.append(f"{path} must be a repository-relative POSIX path without '..'")


def _positive_integer(value: Any, path: str, errors: list[str]) -> int | None:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        errors.append(f"{path} must be a positive integer")
        return None
    return value


def _boolean(value: Any, path: str, errors: list[str]) -> bool | None:
    if not isinstance(value, bool):
        errors.append(f"{path} must be a boolean")
        return None
    return value


def _iso_date(value: Any, path: str, errors: list[str]) -> None:
    text = _non_empty_string(value, path, errors)
    if text is None:
        return
    try:
        date.fromisoformat(text)
    except ValueError:
        errors.append(f"{path} must use YYYY-MM-DD")


def _string_list(value: Any, path: str, errors: list[str]) -> list[str]:
    if (
        not isinstance(value, list)
        or not value
        or not all(isinstance(item, str) and item.strip() for item in value)
    ):
        errors.append(f"{path} must be a non-empty list of non-empty strings")
        return []
    if len(value) != len(set(value)):
        errors.append(f"{path} must not contain duplicate strings")
    return value


def _scan_sensitive(value: Any, path: str, errors: list[str]) -> None:
    if isinstance(value, dict):
        for key, nested in value.items():
            normalized = key.lower()
            if any(fragment in normalized for fragment in FORBIDDEN_KEY_FRAGMENTS):
                errors.append(f"{path}.{key} uses a forbidden sensitive field name")
            _scan_sensitive(nested, f"{path}.{key}", errors)
    elif isinstance(value, list):
        for index, nested in enumerate(value):
            _scan_sensitive(nested, f"{path}[{index}]", errors)
    elif isinstance(value, str):
        for label, pattern in FORBIDDEN_VALUE_PATTERNS.items():
            if pattern.search(value):
                errors.append(f"{path} contains a forbidden {label}")


def validate_manifest(manifest: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    _scan_sensitive(manifest, "manifest", errors)
    root = _exact_fields(manifest, ROOT_FIELDS, "manifest", errors)

    if root.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be '{SCHEMA_VERSION}'")
    run_id = root.get("run_id")
    if not isinstance(run_id, str) or not RUN_ID_RE.fullmatch(run_id):
        errors.append("run_id must be a 3-80 character lowercase slug")
    if root.get("untouched_baseline") is not True:
        errors.append("untouched_baseline must be true")

    benchmark = _exact_fields(root.get("benchmark"), BENCHMARK_FIELDS, "benchmark", errors)
    _non_empty_string(benchmark.get("version"), "benchmark.version", errors)
    _relative_path(benchmark.get("path"), "benchmark.path", errors)
    _sha256(benchmark.get("sha256"), "benchmark.sha256", errors)

    evaluator = _exact_fields(root.get("evaluator"), EVALUATOR_FIELDS, "evaluator", errors)
    _non_empty_string(evaluator.get("contract_version"), "evaluator.contract_version", errors)
    for key in ("contract_path", "benchmark_validator_path", "evaluator_path"):
        _relative_path(evaluator.get(key), f"evaluator.{key}", errors)
    for key in ("contract_sha256", "benchmark_validator_sha256", "evaluator_sha256"):
        _sha256(evaluator.get(key), f"evaluator.{key}", errors)

    backend = _exact_fields(root.get("backend"), BACKEND_FIELDS, "backend", errors)
    backend_class = backend.get("class")
    if backend_class not in ALLOWED_BACKEND_CLASSES:
        errors.append(f"backend.class must be one of {sorted(ALLOWED_BACKEND_CLASSES)}")
    _non_empty_string(backend.get("framework"), "backend.framework", errors)
    _non_empty_string(backend.get("framework_version"), "backend.framework_version", errors)
    model_id = _nullable_string(backend.get("model_id"), "backend.model_id", errors)
    model_revision = backend.get("model_revision")
    system_model_identifier = _nullable_string(
        backend.get("system_model_identifier"),
        "backend.system_model_identifier",
        errors,
    )
    _non_empty_string(backend.get("license_reference"), "backend.license_reference", errors)
    _iso_date(backend.get("license_review_date"), "backend.license_review_date", errors)
    license_gate = backend.get("license_gate_status")
    if license_gate not in ALLOWED_LICENSE_GATES:
        errors.append(
            f"backend.license_gate_status must be one of {sorted(ALLOWED_LICENSE_GATES)}"
        )

    if backend_class == "apple_system":
        if model_id is not None or model_revision is not None:
            errors.append(
                "apple_system must use null model_id and model_revision; "
                "iGentic does not ship or own system-model weights"
            )
        if system_model_identifier is None:
            errors.append("apple_system requires system_model_identifier")
    elif backend_class == "custom_model":
        if model_id is None:
            errors.append("custom_model requires model_id")
        _immutable_revision(model_revision, "backend.model_revision", errors)
        if system_model_identifier is not None:
            errors.append("custom_model must use null system_model_identifier")

    input_identity = _exact_fields(root.get("input"), INPUT_FIELDS, "input", errors)
    tokenizer_id = _non_empty_string(
        input_identity.get("tokenizer_id"), "input.tokenizer_id", errors
    )
    tokenizer_revision = _non_empty_string(
        input_identity.get("tokenizer_revision"), "input.tokenizer_revision", errors
    )
    _non_empty_string(
        input_identity.get("prompt_template_id"), "input.prompt_template_id", errors
    )
    _sha256(
        input_identity.get("prompt_template_sha256"),
        "input.prompt_template_sha256",
        errors,
    )
    _sha256(
        input_identity.get("normalized_input_sha256"),
        "input.normalized_input_sha256",
        errors,
    )
    if backend_class == "custom_model" and tokenizer_revision is not None:
        _immutable_revision(tokenizer_revision, "input.tokenizer_revision", errors)
    if backend_class == "apple_system" and tokenizer_id == "system-managed":
        if tokenizer_revision is None or not tokenizer_revision.startswith("system:"):
            errors.append(
                "system-managed tokenizer_revision must start with 'system:' "
                "and bind the exact system/framework version"
            )

    normalizer = _exact_fields(root.get("normalizer"), NORMALIZER_FIELDS, "normalizer", errors)
    _non_empty_string(normalizer.get("id"), "normalizer.id", errors)
    _immutable_revision(normalizer.get("revision"), "normalizer.revision", errors)

    profile = _exact_fields(root.get("profile"), PROFILE_FIELDS, "profile", errors)
    if profile.get("name") not in ALLOWED_PROFILES:
        errors.append(f"profile.name must be one of {sorted(ALLOWED_PROFILES)}")
    context_limit = _positive_integer(
        profile.get("context_limit_tokens"), "profile.context_limit_tokens", errors
    )
    input_limit = _positive_integer(
        profile.get("input_limit_tokens"), "profile.input_limit_tokens", errors
    )
    output_limit = _positive_integer(
        profile.get("output_limit_tokens"), "profile.output_limit_tokens", errors
    )
    if (
        context_limit is not None
        and input_limit is not None
        and output_limit is not None
        and input_limit + output_limit > context_limit
    ):
        errors.append(
            "profile input_limit_tokens + output_limit_tokens must not exceed "
            "context_limit_tokens"
        )

    decoding = _exact_fields(root.get("decoding"), DECODING_FIELDS, "decoding", errors)
    temperature = decoding.get("temperature")
    if (
        isinstance(temperature, bool)
        or not isinstance(temperature, (int, float))
        or not 0 <= temperature <= 2
    ):
        errors.append("decoding.temperature must be a number from 0 through 2")
    top_p = decoding.get("top_p")
    if (
        isinstance(top_p, bool)
        or not isinstance(top_p, (int, float))
        or not 0 < top_p <= 1
    ):
        errors.append("decoding.top_p must be greater than 0 and at most 1")
    max_output = _positive_integer(
        decoding.get("max_output_tokens"), "decoding.max_output_tokens", errors
    )
    if max_output is not None and output_limit is not None and max_output > output_limit:
        errors.append(
            "decoding.max_output_tokens must not exceed profile.output_limit_tokens"
        )
    seed_supported = _boolean(
        decoding.get("seed_supported"), "decoding.seed_supported", errors
    )
    seed = decoding.get("seed")
    if seed_supported is True:
        if isinstance(seed, bool) or not isinstance(seed, int) or seed < 0:
            errors.append(
                "decoding.seed must be a non-negative integer when seed_supported is true"
            )
    elif seed_supported is False and seed is not None:
        errors.append("decoding.seed must be null when seed_supported is false")

    execution = _exact_fields(root.get("execution"), EXECUTION_FIELDS, "execution", errors)
    _non_empty_string(execution.get("environment"), "execution.environment", errors)
    _non_empty_string(execution.get("os"), "execution.os", errors)
    _non_empty_string(execution.get("architecture"), "execution.architecture", errors)
    evidence_class = execution.get("evidence_class")
    if evidence_class not in ALLOWED_EVIDENCE_CLASSES:
        errors.append(
            f"execution.evidence_class must be one of {sorted(ALLOWED_EVIDENCE_CLASSES)}"
        )
    physical_device_run = _boolean(
        execution.get("physical_device_run"), "execution.physical_device_run", errors
    )
    device_model = _nullable_string(
        execution.get("device_model"), "execution.device_model", errors
    )
    device_os_build = _nullable_string(
        execution.get("device_os_build"), "execution.device_os_build", errors
    )
    if evidence_class == "physical_device":
        if physical_device_run is not True or device_model is None or device_os_build is None:
            errors.append(
                "physical_device evidence requires physical_device_run=true, "
                "device_model and device_os_build"
            )
    else:
        if physical_device_run is not False:
            errors.append("host or simulator evidence requires physical_device_run=false")
        if device_model is not None or device_os_build is not None:
            errors.append(
                "host or simulator evidence must use null device_model and device_os_build"
            )

    artifacts = _exact_fields(root.get("artifacts"), ARTIFACT_FIELDS, "artifacts", errors)
    for key in ("normalized_proposals_path", "evaluator_result_path"):
        _relative_path(artifacts.get(key), f"artifacts.{key}", errors)
    for key in ("normalized_proposals_sha256", "evaluator_result_sha256"):
        _sha256(artifacts.get(key), f"artifacts.{key}", errors)
    if artifacts.get("normalized_proposals_path") == artifacts.get("evaluator_result_path"):
        errors.append("proposal and evaluator result paths must be different")
    if artifacts.get("normalized_proposals_sha256") == artifacts.get("evaluator_result_sha256"):
        errors.append("proposal and evaluator result hashes must be different")

    observations = _exact_fields(
        root.get("observations"), OBSERVATION_FIELDS, "observations", errors
    )
    for key in (
        "repetition_observed",
        "truncation_observed",
        "timeout_observed",
        "cancellation_observed",
    ):
        _boolean(observations.get(key), f"observations.{key}", errors)
    termination_reason = observations.get("termination_reason")
    if termination_reason not in ALLOWED_TERMINATION_REASONS:
        errors.append(
            "observations.termination_reason must be one of "
            f"{sorted(ALLOWED_TERMINATION_REASONS)}"
        )
    timeout = observations.get("timeout_observed")
    cancelled = observations.get("cancellation_observed")
    if timeout is True and cancelled is True:
        errors.append("timeout_observed and cancellation_observed cannot both be true")
    if timeout is True and termination_reason != "timeout":
        errors.append("timeout_observed=true requires termination_reason='timeout'")
    if cancelled is True and termination_reason != "cancelled":
        errors.append(
            "cancellation_observed=true requires termination_reason='cancelled'"
        )
    if termination_reason == "timeout" and timeout is not True:
        errors.append("termination_reason='timeout' requires timeout_observed=true")
    if termination_reason == "cancelled" and cancelled is not True:
        errors.append(
            "termination_reason='cancelled' requires cancellation_observed=true"
        )
    if termination_reason == "completed" and (timeout is True or cancelled is True):
        errors.append("completed termination cannot report timeout or cancellation")

    specialization = _exact_fields(
        root.get("specialization"), SPECIALIZATION_FIELDS, "specialization", errors
    )
    for key in ("training_performed", "fine_tuning_performed", "model_adapter_applied"):
        if specialization.get(key) is not False:
            errors.append(f"specialization.{key} must be false for an untouched baseline")
    for key in ("model_adapter_id", "model_adapter_revision"):
        if specialization.get(key) is not None:
            errors.append(f"specialization.{key} must be null for an untouched baseline")

    claims = _exact_fields(root.get("claims"), CLAIM_FIELDS, "claims", errors)
    physical_claim = _boolean(
        claims.get("physical_device_readiness_claimed"),
        "claims.physical_device_readiness_claimed",
        errors,
    )
    if physical_claim is True and evidence_class != "physical_device":
        errors.append(
            "physical-device readiness cannot be claimed from host or simulator evidence"
        )

    _string_list(root.get("known_limitations"), "known_limitations", errors)
    decision = root.get("next_decision")
    if decision not in ALLOWED_DECISIONS:
        errors.append(f"next_decision must be one of {sorted(ALLOWED_DECISIONS)}")
    if license_gate in {"blocked", "unverified"} and decision in {"keep", "rework"}:
        errors.append("a blocked or unverified license gate cannot produce keep or rework")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "manifest",
        nargs="?",
        type=Path,
        default=DEFAULT_MANIFEST,
        help=f"manifest JSON (default: {DEFAULT_MANIFEST.relative_to(ROOT)})",
    )
    args = parser.parse_args()

    try:
        manifest = load_manifest(args.manifest)
        errors = validate_manifest(manifest)
    except ValidationError as exc:
        print(f"Baseline manifest validation failed:\n{exc}", file=sys.stderr)
        return 1

    if errors:
        print(
            "Baseline manifest validation failed:\n" + "\n".join(errors),
            file=sys.stderr,
        )
        return 1

    print(
        "Baseline manifest valid: "
        f"run_id={manifest['run_id']}; "
        f"backend={manifest['backend']['class']}; "
        f"evidence={manifest['execution']['evidence_class']}; "
        f"decision={manifest['next_decision']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
