#!/usr/bin/env python3
"""Package one completed Apple Foundation Models Benchmark V0 host run."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys
from typing import Any

from evaluate_action_proposals import evaluate
from validate_action_benchmark import (
    ALLOWED_INTENTS,
    ALLOWED_PROPOSAL_TYPES,
    ALLOWED_TOOLS,
    DEFAULT_BENCHMARK,
    ValidationError,
    validate_benchmark,
)
from validate_baseline_run import validate_manifest

ROOT = Path(__file__).resolve().parents[1]
EVALUATOR_CONTRACT = ROOT / "docs/model-research/EVALUATOR_CONTRACT_V0.md"
BENCHMARK_VALIDATOR = ROOT / "scripts/validate_action_benchmark.py"
EVALUATOR_SCRIPT = ROOT / "scripts/evaluate_action_proposals.py"
RUNNER_SOURCE = ROOT / "ios/Sources/ModelResearchSupport/AppleFoundationBaseline.swift"
ENCODING_SOURCE = (
    ROOT / "ios/Sources/ModelResearchSupport/AppleFoundationBaselineEvidenceEncoding.swift"
)

RAW_PROPOSALS = "raw-proposals.jsonl"
NORMALIZED_PROPOSALS = "normalized-proposals.jsonl"
TOKEN_COUNTS = "token-counts.json"
APPLIED_GENERATION_CONFIG = "applied-generation-config.json"
RUN_METADATA = "run-metadata.json"
NORMALIZED_INPUT = "normalized-input.jsonl"
EVALUATOR_RESULT = "evaluator-result.json"
BASELINE_MANIFEST = "baseline-run-manifest.json"

INPUT_FILENAMES = (
    RAW_PROPOSALS,
    NORMALIZED_PROPOSALS,
    TOKEN_COUNTS,
    APPLIED_GENERATION_CONFIG,
    RUN_METADATA,
)
OUTPUT_FILENAMES = (
    NORMALIZED_INPUT,
    EVALUATOR_RESULT,
    BASELINE_MANIFEST,
)
ALLOWED_DIRECTORY_ENTRIES = set(INPUT_FILENAMES) | set(OUTPUT_FILENAMES)

PROFILES = {
    "Router-small": {"input_limit_tokens": 512, "output_limit_tokens": 32},
    "Router-normal": {"input_limit_tokens": 1_024, "output_limit_tokens": 64},
}

RUNNER_INSTRUCTIONS_ID = "igentic-apple-router-v0"
RUNNER_INSTRUCTIONS = (
    "Classify one synthetic request into exactly one structured iGentic routing proposal. "
    "Do not execute anything. Supported intents and local route names are createReminder, "
    "summarizeNote, findFile, requestApproval, and unknown. Use clarify when required input "
    "is missing or ambiguous, noTool when no supported local route matches, and refuse for "
    "an unsupported sensitive action. Preserve only argument values supported by the request; "
    "do not invent missing values. For non-tool proposals, return no tool."
)
MINIMUM_EVIDENCE_OS = "26.4"
TOKEN_EVIDENCE_METHOD = "SystemLanguageModel.tokenCount(for:)"
SYSTEM_MODEL_PREFIX = "SystemLanguageModel.default|"
FRAMEWORK = "Apple Foundation Models"
BACKEND_CLASS = "apple_system"
LICENSE_REFERENCE = "https://developer.apple.com/documentation/foundationmodels"
LICENSE_REVIEW_DATE = "2026-08-28"
NORMALIZER_ID = "apple-foundation-models-v0-runner-normalizer"

RUN_METADATA_FIELDS = {
    "backend_class",
    "framework",
    "profile",
    "benchmark_case_count",
    "system_model_identifier",
    "context_limit_tokens",
    "os",
    "architecture",
    "swift_toolchain",
    "minimum_evidence_os",
    "token_evidence_method",
    "instructions_id",
    "instructions_text",
    "evidence_class",
    "physical_device_run",
    "physical_device_readiness_claimed",
}
TOKEN_RECORD_FIELDS = {
    "case_id",
    "instructions_token_count",
    "schema_token_count",
    "prompt_token_count",
    "model_visible_input_token_count",
}
RAW_RECORD_FIELDS = {"case_id", "proposal", "model_visible_input_token_count"}
RAW_PROPOSAL_REQUIRED_FIELDS = {
    "proposalType",
    "intent",
    "arguments",
    "missingArguments",
    "reasonCode",
}
RAW_PROPOSAL_OPTIONAL_FIELDS = {"tool"}
NORMALIZED_FIELDS = {
    "case_id",
    "proposalType",
    "intent",
    "tool",
    "arguments",
    "missingArguments",
    "reasonCode",
    "repetitionDetected",
    "truncationDetected",
}
GENERATION_CONFIG_FIELDS = {
    "sampling_mode",
    "sampling_enabled",
    "temperature",
    "top_p",
    "top_k",
    "maximum_response_tokens",
    "seed_supported",
    "seed",
    "include_schema_in_prompt",
    "tools_count",
}
RAW_ARGUMENT_TO_NORMALIZED = {
    "title": "title",
    "time": "time",
    "date": "date",
    "noteText": "note_text",
    "noteReference": "note_reference",
    "query": "query",
    "fileType": "file_type",
    "dateHint": "date_hint",
    "actionSummary": "action_summary",
}
ALLOWED_ARGUMENT_NAMES = set(RAW_ARGUMENT_TO_NORMALIZED.values())
ALLOWED_REASON_CODES = {
    "direct_intent",
    "missing_required_argument",
    "ambiguous_required_arguments",
    "unresolved_note_reference",
    "ambiguous_file_reference",
    "ambiguous_action_reference",
    "unclear_intent",
    "unsupported_tool",
    "unsupported_sensitive_action",
    "no_matching_local_tool",
}

_SAFE_COMPONENT_RE = re.compile(r"^[A-Za-z0-9_.:+-]{1,96}$")


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


def _require_regular_file(path: Path) -> None:
    if path.is_symlink():
        raise ValidationError(f"{path.name} must not be a symlink")
    if not path.is_file():
        raise ValidationError(f"required evidence file is missing: {path.name}")


def _validate_directory_entries(run_dir: Path) -> None:
    try:
        entries = {entry.name for entry in run_dir.iterdir()}
    except OSError as exc:
        raise ValidationError(f"cannot list run directory: {exc}") from exc
    unexpected = sorted(entries - ALLOWED_DIRECTORY_ENTRIES)
    missing = sorted(set(INPUT_FILENAMES) - entries)
    if unexpected:
        raise ValidationError(
            "run directory contains unexpected entries: " + ", ".join(unexpected)
        )
    if missing:
        raise ValidationError(
            "run directory is missing required evidence files: " + ", ".join(missing)
        )


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
        raise ValidationError(
            f"{path.name} is not valid JSON at line {exc.lineno}"
        ) from exc


def _load_jsonl(path: Path) -> list[dict[str, Any]]:
    _require_regular_file(path)
    try:
        text = path.read_bytes().decode("utf-8")
    except OSError as exc:
        raise ValidationError(f"cannot read {path.name}: {exc}") from exc
    except UnicodeDecodeError as exc:
        raise ValidationError(f"{path.name} is not valid UTF-8") from exc

    records: list[dict[str, Any]] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        if not line.strip():
            raise ValidationError(f"{path.name}:{line_number}: blank lines are not allowed")
        try:
            value = json.loads(
                line,
                object_pairs_hook=_duplicate_rejecting_object,
                parse_constant=_reject_non_finite,
                parse_float=_finite_float,
            )
        except json.JSONDecodeError as exc:
            raise ValidationError(
                f"{path.name}:{line_number}: invalid JSON: {exc.msg}"
            ) from exc
        if not isinstance(value, dict):
            raise ValidationError(
                f"{path.name}:{line_number}: each JSONL record must be an object"
            )
        records.append(value)
    return records


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
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise ValidationError(f"cannot hash {path.name}: {exc}") from exc
    return digest.hexdigest()


def _source_hash(path: Path) -> str:
    try:
        path.relative_to(ROOT)
    except ValueError as exc:
        raise ValidationError("canonical source path escaped repository root") from exc
    return _sha256_file(path)


def _combined_normalizer_hash() -> str:
    digest = hashlib.sha256()
    for path in (RUNNER_SOURCE, ENCODING_SOURCE):
        try:
            relative = path.relative_to(ROOT).as_posix()
        except ValueError as exc:
            raise ValidationError("normalizer source path escaped repository root") from exc
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        _require_regular_file(path)
        try:
            digest.update(path.read_bytes())
        except OSError as exc:
            raise ValidationError(f"cannot read normalizer source {relative}") from exc
        digest.update(b"\0")
    return digest.hexdigest()


def _positive_integer(value: Any, field: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise ValidationError(f"{field} must be a positive integer")
    return value


def _safe_text(value: Any, field: str, *, allow_newlines: bool = False) -> str:
    if not isinstance(value, str) or not value or len(value) > 2_000:
        raise ValidationError(f"{field} must be non-empty bounded text")
    for char in value:
        if ord(char) < 32 and not (allow_newlines and char == "\n"):
            raise ValidationError(f"{field} contains unsupported control characters")
    return value


def _safe_component(value: Any, field: str) -> str:
    text = _safe_text(value, field)
    if not _SAFE_COMPONENT_RE.fullmatch(text):
        raise ValidationError(f"{field} contains unsupported characters")
    return text


def _exact_fields(value: Any, expected: set[str], field: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValidationError(f"{field} must be an object")
    missing = sorted(expected - value.keys())
    extra = sorted(value.keys() - expected)
    if missing:
        raise ValidationError(f"{field} missing fields: {', '.join(missing)}")
    if extra:
        raise ValidationError(f"{field} unexpected fields: {', '.join(extra)}")
    return value


def _json_value_equal(expected: Any, actual: Any) -> bool:
    if type(expected) is not type(actual):
        return False
    if isinstance(expected, dict):
        return (
            expected.keys() == actual.keys()
            and all(_json_value_equal(expected[key], actual[key]) for key in expected)
        )
    if isinstance(expected, list):
        return len(expected) == len(actual) and all(
            _json_value_equal(left, right) for left, right in zip(expected, actual)
        )
    return expected == actual


def _validate_metadata(value: Any, expected_case_count: int) -> dict[str, Any]:
    metadata = _exact_fields(value, RUN_METADATA_FIELDS, "run-metadata.json")
    if metadata["backend_class"] != BACKEND_CLASS:
        raise ValidationError("run metadata backend_class must be apple_system")
    if metadata["framework"] != FRAMEWORK:
        raise ValidationError("run metadata framework must be Apple Foundation Models")

    profile = metadata["profile"]
    if profile not in PROFILES:
        raise ValidationError("run metadata profile is not a canonical Benchmark V0 profile")

    case_count = metadata["benchmark_case_count"]
    if (
        isinstance(case_count, bool)
        or not isinstance(case_count, int)
        or case_count != expected_case_count
    ):
        raise ValidationError("run metadata benchmark_case_count does not match Benchmark V0")

    context_limit = _positive_integer(
        metadata["context_limit_tokens"], "run-metadata.context_limit_tokens"
    )
    limits = PROFILES[profile]
    if limits["input_limit_tokens"] + limits["output_limit_tokens"] > context_limit:
        raise ValidationError(
            "run metadata context capacity is smaller than the selected V0 profile"
        )

    os_value = _safe_text(metadata["os"], "run-metadata.os")
    system_identifier = _safe_text(
        metadata["system_model_identifier"], "run-metadata.system_model_identifier"
    )
    if system_identifier != SYSTEM_MODEL_PREFIX + os_value:
        raise ValidationError(
            "run metadata system_model_identifier must bind SystemLanguageModel.default "
            "to the exact OS string"
        )

    _safe_component(metadata["architecture"], "run-metadata.architecture")
    _safe_text(
        metadata["swift_toolchain"],
        "run-metadata.swift_toolchain",
        allow_newlines=True,
    )

    if metadata["minimum_evidence_os"] != MINIMUM_EVIDENCE_OS:
        raise ValidationError("run metadata minimum_evidence_os must be 26.4")
    if metadata["token_evidence_method"] != TOKEN_EVIDENCE_METHOD:
        raise ValidationError("run metadata token_evidence_method is not canonical")
    if metadata["instructions_id"] != RUNNER_INSTRUCTIONS_ID:
        raise ValidationError("run metadata instructions_id is not canonical")
    if metadata["instructions_text"] != RUNNER_INSTRUCTIONS:
        raise ValidationError("run metadata instructions_text is not canonical")
    if metadata["evidence_class"] != "host":
        raise ValidationError("Apple V0 evidence packager accepts host evidence only")
    if metadata["physical_device_run"] is not False:
        raise ValidationError("host evidence must not claim a physical-device run")
    if metadata["physical_device_readiness_claimed"] is not False:
        raise ValidationError("host evidence must not claim physical-device readiness")
    return metadata


def _validate_generation_config(value: Any, profile: str) -> dict[str, Any]:
    config = _exact_fields(
        value, GENERATION_CONFIG_FIELDS, "applied-generation-config.json"
    )
    if config["sampling_mode"] != "greedy":
        raise ValidationError("generation config sampling_mode must be greedy")
    if config["sampling_enabled"] is not False:
        raise ValidationError("generation config sampling_enabled must be false")

    temperature = config["temperature"]
    if (
        isinstance(temperature, bool)
        or not isinstance(temperature, (int, float))
        or temperature != 0
    ):
        raise ValidationError("generation config temperature must be 0.0")

    top_p = config["top_p"]
    if (
        isinstance(top_p, bool)
        or not isinstance(top_p, (int, float))
        or top_p != 1
    ):
        raise ValidationError("generation config top_p must be 1.0")

    if config["top_k"] is not None:
        raise ValidationError("generation config top_k must be null")
    if config["seed_supported"] is not False:
        raise ValidationError("generation config seed_supported must be false")
    if config["seed"] is not None:
        raise ValidationError("generation config seed must be null")
    if config["include_schema_in_prompt"] is not True:
        raise ValidationError("generation config include_schema_in_prompt must be true")
    if (
        isinstance(config["tools_count"], bool)
        or not isinstance(config["tools_count"], int)
        or config["tools_count"] != 0
    ):
        raise ValidationError("generation config tools_count must be 0")

    expected_output = PROFILES[profile]["output_limit_tokens"]
    actual_output = config["maximum_response_tokens"]
    if (
        isinstance(actual_output, bool)
        or not isinstance(actual_output, int)
        or actual_output != expected_output
    ):
        raise ValidationError(
            "generation config maximum_response_tokens does not match the profile"
        )
    return config


def _validate_token_counts(
    value: Any,
    benchmark: list[dict[str, Any]],
    profile: str,
) -> tuple[dict[str, int], int]:
    if not isinstance(value, list):
        raise ValidationError("token-counts.json root must be an array")
    if len(value) != len(benchmark):
        raise ValidationError("token-counts.json record count does not match Benchmark V0")

    token_by_case: dict[str, int] = {}
    instructions_values: set[int] = set()
    schema_values: set[int] = set()
    maximum = 0
    input_limit = PROFILES[profile]["input_limit_tokens"]

    for index, (record, benchmark_record) in enumerate(zip(value, benchmark), start=1):
        record = _exact_fields(record, TOKEN_RECORD_FIELDS, f"token-counts.json[{index}]")
        case_id = record["case_id"]
        if case_id != benchmark_record["case_id"]:
            raise ValidationError("token-counts.json case order does not match Benchmark V0")

        instructions = _positive_integer(
            record["instructions_token_count"],
            f"token-counts.json[{index}].instructions_token_count",
        )
        schema = _positive_integer(
            record["schema_token_count"],
            f"token-counts.json[{index}].schema_token_count",
        )
        prompt = _positive_integer(
            record["prompt_token_count"],
            f"token-counts.json[{index}].prompt_token_count",
        )
        total = _positive_integer(
            record["model_visible_input_token_count"],
            f"token-counts.json[{index}].model_visible_input_token_count",
        )
        if instructions + schema + prompt != total:
            raise ValidationError(
                f"token-counts.json token components do not sum for {case_id}"
            )
        if total > input_limit:
            raise ValidationError(
                f"token-counts.json model-visible input exceeds profile for {case_id}"
            )
        instructions_values.add(instructions)
        schema_values.add(schema)
        token_by_case[case_id] = total
        maximum = max(maximum, total)

    if len(instructions_values) != 1:
        raise ValidationError("instructions token count must be constant across the run")
    if len(schema_values) != 1:
        raise ValidationError("schema token count must be constant across the run")
    return token_by_case, maximum


def _validate_raw_proposal(proposal: Any, case_id: str) -> dict[str, Any]:
    if not isinstance(proposal, dict):
        raise ValidationError(f"raw proposal must be an object for {case_id}")
    missing = sorted(RAW_PROPOSAL_REQUIRED_FIELDS - proposal.keys())
    extra = sorted(
        proposal.keys()
        - (RAW_PROPOSAL_REQUIRED_FIELDS | RAW_PROPOSAL_OPTIONAL_FIELDS)
    )
    if missing:
        raise ValidationError(f"raw proposal missing fields for {case_id}: {', '.join(missing)}")
    if extra:
        raise ValidationError(
            f"raw proposal unexpected fields for {case_id}: {', '.join(extra)}"
        )

    proposal_type = proposal["proposalType"]
    if proposal_type not in ALLOWED_PROPOSAL_TYPES:
        raise ValidationError(f"raw proposalType is not canonical for {case_id}")
    intent = proposal["intent"]
    if intent not in ALLOWED_INTENTS:
        raise ValidationError(f"raw intent is not canonical for {case_id}")

    tool: str | None = None
    if "tool" in proposal:
        tool_value = proposal["tool"]
        if tool_value not in ALLOWED_TOOLS:
            raise ValidationError(f"raw tool is not canonical for {case_id}")
        tool = tool_value

    arguments = proposal["arguments"]
    if not isinstance(arguments, dict):
        raise ValidationError(f"raw arguments must be an object for {case_id}")
    normalized_arguments: dict[str, str] = {}
    for key, item in arguments.items():
        if key not in RAW_ARGUMENT_TO_NORMALIZED:
            raise ValidationError(f"raw argument name is not canonical for {case_id}")
        if not isinstance(item, str):
            raise ValidationError(f"raw argument values must be strings for {case_id}")
        normalized_arguments[RAW_ARGUMENT_TO_NORMALIZED[key]] = item

    missing_arguments = proposal["missingArguments"]
    if not isinstance(missing_arguments, list) or not all(
        isinstance(item, str) and item in ALLOWED_ARGUMENT_NAMES
        for item in missing_arguments
    ):
        raise ValidationError(f"raw missingArguments is not canonical for {case_id}")

    reason_code = proposal["reasonCode"]
    if reason_code not in ALLOWED_REASON_CODES:
        raise ValidationError(f"raw reasonCode is not canonical for {case_id}")

    return {
        "case_id": case_id,
        "proposalType": proposal_type,
        "intent": intent,
        "tool": tool,
        "arguments": normalized_arguments,
        "missingArguments": list(missing_arguments),
        "reasonCode": reason_code,
        "repetitionDetected": False,
        "truncationDetected": False,
    }


def _validate_raw_records(
    records: list[dict[str, Any]],
    benchmark: list[dict[str, Any]],
    token_by_case: dict[str, int],
) -> list[dict[str, Any]]:
    if len(records) != len(benchmark):
        raise ValidationError("raw-proposals.jsonl record count does not match Benchmark V0")

    projections: list[dict[str, Any]] = []
    for index, (record, benchmark_record) in enumerate(zip(records, benchmark), start=1):
        record = _exact_fields(record, RAW_RECORD_FIELDS, f"raw-proposals.jsonl[{index}]")
        case_id = record["case_id"]
        if case_id != benchmark_record["case_id"]:
            raise ValidationError("raw-proposals.jsonl case order does not match Benchmark V0")
        total = _positive_integer(
            record["model_visible_input_token_count"],
            f"raw-proposals.jsonl[{index}].model_visible_input_token_count",
        )
        if total != token_by_case[case_id]:
            raise ValidationError(
                f"raw model-visible input token count disagrees with token-counts.json for {case_id}"
            )
        projections.append(_validate_raw_proposal(record["proposal"], case_id))
    return projections


def _validate_normalized_records(
    records: list[dict[str, Any]],
    benchmark: list[dict[str, Any]],
    projections: list[dict[str, Any]],
) -> tuple[bool, bool]:
    if len(records) != len(benchmark):
        raise ValidationError(
            "normalized-proposals.jsonl record count does not match Benchmark V0"
        )

    repetition = False
    truncation = False
    for index, (record, benchmark_record, expected) in enumerate(
        zip(records, benchmark, projections), start=1
    ):
        record = _exact_fields(
            record, NORMALIZED_FIELDS, f"normalized-proposals.jsonl[{index}]"
        )
        if record["case_id"] != benchmark_record["case_id"]:
            raise ValidationError(
                "normalized-proposals.jsonl case order does not match Benchmark V0"
            )
        if not isinstance(record["repetitionDetected"], bool):
            raise ValidationError(
                f"normalized repetitionDetected must be a boolean for {record['case_id']}"
            )
        if not isinstance(record["truncationDetected"], bool):
            raise ValidationError(
                f"normalized truncationDetected must be a boolean for {record['case_id']}"
            )
        if not _json_value_equal(expected, record):
            raise ValidationError(
                f"normalized proposal is not the exact raw projection for {record['case_id']}"
            )
        repetition = repetition or record["repetitionDetected"]
        truncation = truncation or record["truncationDetected"]
    return repetition, truncation


def _canonical_normalized_input(
    benchmark: list[dict[str, Any]],
    runner_source_hash: str,
) -> bytes:
    records = [
        {
            "case_id": record["case_id"],
            "language": record["language"],
            "user_text": record["user_text"],
            "instructions_id": RUNNER_INSTRUCTIONS_ID,
            "instructions_text": RUNNER_INSTRUCTIONS,
            "include_schema_in_prompt": True,
            "tools": [],
            "guided_generation_schema_source_path": str(
                RUNNER_SOURCE.relative_to(ROOT).as_posix()
            ),
            "guided_generation_schema_source_sha256": runner_source_hash,
        }
        for record in benchmark
    ]
    return _jsonl_bytes(records)


def build_package(run_dir: Path) -> dict[str, bytes]:
    run_dir = _resolve_run_dir(run_dir)
    _validate_directory_entries(run_dir)
    _ensure_outputs_absent(run_dir)

    benchmark = validate_benchmark(DEFAULT_BENCHMARK)
    if len(benchmark) != 40:
        raise ValidationError("canonical Benchmark V0 must contain exactly 40 records")

    paths = {name: run_dir / name for name in INPUT_FILENAMES}
    for path in paths.values():
        _require_regular_file(path)

    metadata = _validate_metadata(
        _load_json(paths[RUN_METADATA]),
        len(benchmark),
    )
    profile = metadata["profile"]
    generation_config = _validate_generation_config(
        _load_json(paths[APPLIED_GENERATION_CONFIG]),
        profile,
    )
    token_by_case, max_rendered_input_tokens = _validate_token_counts(
        _load_json(paths[TOKEN_COUNTS]),
        benchmark,
        profile,
    )
    raw_records = _load_jsonl(paths[RAW_PROPOSALS])
    normalized_records = _load_jsonl(paths[NORMALIZED_PROPOSALS])
    projections = _validate_raw_records(raw_records, benchmark, token_by_case)
    repetition_observed, truncation_observed = _validate_normalized_records(
        normalized_records,
        benchmark,
        projections,
    )

    runner_hash = _source_hash(RUNNER_SOURCE)
    normalized_input_bytes = _canonical_normalized_input(benchmark, runner_hash)
    result = evaluate(DEFAULT_BENCHMARK, paths[NORMALIZED_PROPOSALS])
    result_bytes = _json_bytes(result)

    system_identifier = metadata["system_model_identifier"]
    system_hash = _sha256_bytes(system_identifier.encode("utf-8"))[:12]
    normalizer_hash = _combined_normalizer_hash()
    prompt_hash = _sha256_bytes(metadata["instructions_text"].encode("utf-8"))
    input_limit = PROFILES[profile]["input_limit_tokens"]
    output_limit = PROFILES[profile]["output_limit_tokens"]

    manifest = {
        "schema_version": "igentic-baseline-run-v0",
        "run_id": f"apple-foundation-v0-{profile.lower()}-{system_hash}",
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
            "class": "apple_system",
            "framework": FRAMEWORK,
            "framework_version": f"system:{metadata['os']}",
            "model_id": None,
            "model_revision": None,
            "system_model_identifier": system_identifier,
            "license_reference": LICENSE_REFERENCE,
            "license_review_date": LICENSE_REVIEW_DATE,
            "license_gate_status": "unverified",
        },
        "input": {
            "tokenizer_id": "system-managed",
            "tokenizer_revision": f"system:{system_identifier}",
            "prompt_template_id": metadata["instructions_id"],
            "prompt_template_sha256": prompt_hash,
            "normalized_input_sha256": _sha256_bytes(normalized_input_bytes),
            "max_rendered_input_tokens": max_rendered_input_tokens,
            "token_counts_path": TOKEN_COUNTS,
            "token_counts_sha256": _sha256_file(paths[TOKEN_COUNTS]),
        },
        "normalizer": {
            "id": NORMALIZER_ID,
            "revision": normalizer_hash,
        },
        "profile": {
            "name": profile,
            "context_limit_tokens": metadata["context_limit_tokens"],
            "input_limit_tokens": input_limit,
            "output_limit_tokens": output_limit,
        },
        "decoding": {
            "sampling_enabled": generation_config["sampling_enabled"],
            "temperature": generation_config["temperature"],
            "top_p": generation_config["top_p"],
            "top_k": generation_config["top_k"],
            "max_output_tokens": generation_config["maximum_response_tokens"],
            "seed_supported": generation_config["seed_supported"],
            "seed": generation_config["seed"],
            "applied_config_path": APPLIED_GENERATION_CONFIG,
            "applied_config_sha256": _sha256_file(paths[APPLIED_GENERATION_CONFIG]),
        },
        "execution": {
            "environment": (
                "apple-foundation-models-host-v0;"
                f"minimum_evidence_os={metadata['minimum_evidence_os']};"
                f"token_method={metadata['token_evidence_method']};"
                f"swift={metadata['swift_toolchain']}"
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
            "normalized_proposals_sha256": _sha256_file(paths[NORMALIZED_PROPOSALS]),
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
                "Stable Xcode 26.6 Foundation Models does not expose response usage in this "
                "runner contract, so no output-token usage is claimed."
            ),
            (
                "The Apple system model revision is not exposed by this stable API surface; "
                "system identity is bound to SystemLanguageModel.default and the exact OS string."
            ),
            (
                "The V0 Apple runner records repetitionDetected=false and "
                "truncationDetected=false as fixed normalized fields; it does not implement "
                "a general repetition or truncation detector."
            ),
            (
                "Apple platform and product/license eligibility remains unverified by this "
                "host evidence package."
            ),
        ],
        "next_decision": "unverified",
    }
    manifest_errors = validate_manifest(manifest)
    if manifest_errors:
        raise ValidationError(
            "generated baseline manifest violates V0: " + "; ".join(manifest_errors)
        )

    return {
        NORMALIZED_INPUT: normalized_input_bytes,
        EVALUATOR_RESULT: result_bytes,
        BASELINE_MANIFEST: _json_bytes(manifest),
    }


def _ensure_outputs_absent(run_dir: Path) -> None:
    existing = [
        name
        for name in OUTPUT_FILENAMES
        if (run_dir / name).exists() or (run_dir / name).is_symlink()
    ]
    if existing:
        raise ValidationError(
            "refusing to package because target evidence files already exist: "
            + ", ".join(existing)
        )


def package_run(run_dir: Path) -> None:
    run_dir = _resolve_run_dir(run_dir)
    _validate_directory_entries(run_dir)
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
        raise ValidationError("could not write complete Apple evidence package") from exc


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--run-dir",
        type=Path,
        required=True,
        help="one completed Apple Foundation Models Benchmark V0 host profile directory",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        package_run(args.run_dir)
    except ValidationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    print(f"Packaged Apple Foundation Models V0 host evidence: {args.run_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
