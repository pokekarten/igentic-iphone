#!/usr/bin/env python3
"""Build and normalize Qwen3 0.6B Benchmark V0 envelopes without model dependencies."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys
from typing import Any

from validate_action_benchmark import DEFAULT_BENCHMARK, ValidationError, validate_benchmark

MODEL_ID = "Qwen/Qwen3-0.6B"
MODEL_REVISION = "c1899de289a04d12100db370d81485cdf75e47ca"
TOKENIZER_ID = MODEL_ID
TOKENIZER_REVISION = MODEL_REVISION
TOOL_NAME = "igentic_propose_action"
TOOL_CALL_OPEN = "<tool_call>"
TOOL_CALL_CLOSE = "</tool_call>"
OBSERVATION_FIELDS = ("repetitionDetected", "truncationDetected")
RESERVED_MODEL_FIELDS = {"case_id", "normalizerError", *OBSERVATION_FIELDS}

# Pinned upstream-recommended hard non-thinking sampling profile. The profile's
# max_new_tokens remains a Router-small/Router-normal run setting (32/64), not
# part of these backend-fixed kwargs.
NON_THINKING_GENERATION_KWARGS: dict[str, bool | float | int] = {
    "do_sample": True,
    "temperature": 0.7,
    "top_p": 0.8,
    "top_k": 20,
    "min_p": 0.0,
}
# Precommitted before any Qwen Benchmark V0 result exists. Each seed/profile
# pair is a separate baseline-run manifest; seed numbers do not imply equivalent
# random streams across different models or backends.
BASELINE_SEEDS = (0, 1, 2, 3, 4)

SYSTEM_INSTRUCTION = (
    "Return exactly one iGentic proposal by calling igentic_propose_action. "
    "A proposal never authorizes or executes an action. Output no prose."
)

ALLOWED_ARGUMENT_KEYS = (
    "title",
    "time",
    "date",
    "note_text",
    "note_reference",
    "query",
    "file_type",
    "date_hint",
    "action_summary",
)
ALLOWED_MISSING_ARGUMENTS = (
    "title",
    "time",
    "note_text",
    "query",
    "action_summary",
)
ALLOWED_REASON_CODES = (
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
)
ARGUMENT_PROPERTIES = {key: {"type": "string"} for key in ALLOWED_ARGUMENT_KEYS}

PROPOSAL_PROPERTIES: dict[str, Any] = {
    "proposalType": {
        "type": "string",
        "enum": ["tool_call", "clarify", "no_tool", "refuse"],
    },
    "intent": {
        "type": "string",
        "enum": [
            "createReminder",
            "summarizeNote",
            "findFile",
            "requestApproval",
            "unknown",
        ],
    },
    "tool": {
        "oneOf": [
            {
                "type": "string",
                "enum": [
                    "createReminder",
                    "summarizeNote",
                    "findFile",
                    "requestApproval",
                ],
            },
            {"type": "null"},
        ]
    },
    "arguments": {
        "type": "object",
        "properties": ARGUMENT_PROPERTIES,
        "additionalProperties": True,
    },
    "missingArguments": {
        "type": "array",
        "items": {"type": "string", "enum": list(ALLOWED_MISSING_ARGUMENTS)},
        "uniqueItems": True,
    },
    "reasonCode": {"type": "string", "enum": list(ALLOWED_REASON_CODES)},
}
PROPOSAL_FIELDS = tuple(PROPOSAL_PROPERTIES)

TOOL_SCHEMA: dict[str, Any] = {
    "type": "function",
    "function": {
        "name": TOOL_NAME,
        "parameters": {
            "type": "object",
            "properties": PROPOSAL_PROPERTIES,
            "required": list(PROPOSAL_FIELDS),
            "additionalProperties": False,
        },
    },
}


class DuplicateJSONKeyError(ValidationError):
    """Raised when a JSON object contains the same key more than once."""


class NonFiniteJSONNumberError(ValidationError):
    """Raised when JSON input cannot be represented as a finite JSON number."""


def _object_without_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJSONKeyError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _reject_non_finite_json_number(value: str) -> None:
    raise NonFiniteJSONNumberError(f"non-finite JSON number: {value}")


def _finite_json_float(value: str) -> float:
    parsed = float(value)
    if not math.isfinite(parsed):
        raise NonFiniteJSONNumberError(f"JSON number exceeds finite range: {value}")
    return parsed


def _strict_json_loads(text: str) -> Any:
    return json.loads(
        text,
        object_pairs_hook=_object_without_duplicate_keys,
        parse_constant=_reject_non_finite_json_number,
        parse_float=_finite_json_float,
    )


def _load_transport_jsonl(path: Path) -> list[dict[str, Any]]:
    try:
        text = path.read_bytes().decode("utf-8")
    except OSError as exc:
        raise ValidationError(f"cannot read {path}: {exc}") from exc
    except UnicodeDecodeError as exc:
        raise ValidationError(f"{path} is not valid UTF-8: {exc}") from exc

    records: list[dict[str, Any]] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        if not line.strip():
            raise ValidationError(f"{path}:{line_number}: blank lines are not allowed")
        try:
            value = _strict_json_loads(line)
        except json.JSONDecodeError as exc:
            raise ValidationError(
                f"{path}:{line_number}: invalid JSON: {exc.msg}"
            ) from exc
        except ValidationError as exc:
            raise ValidationError(f"{path}:{line_number}: {exc}") from exc
        if not isinstance(value, dict):
            raise ValidationError(
                f"{path}:{line_number}: each JSONL record must be an object"
            )
        records.append(value)
    return records


def build_request(record: dict[str, Any]) -> dict[str, Any]:
    return {
        "case_id": record["case_id"],
        "model_id": MODEL_ID,
        "model_revision": MODEL_REVISION,
        "tokenizer_id": TOKENIZER_ID,
        "tokenizer_revision": TOKENIZER_REVISION,
        "messages": [
            {"role": "system", "content": SYSTEM_INSTRUCTION},
            {"role": "user", "content": record["user_text"]},
        ],
        "tools": [TOOL_SCHEMA],
        "chat_template_kwargs": {
            "add_generation_prompt": True,
            "enable_thinking": False,
        },
        "generation_kwargs": dict(NON_THINKING_GENERATION_KWARGS),
        "replicate_seeds": list(BASELINE_SEEDS),
    }


def _copy_observations(record: dict[str, Any], output: dict[str, Any]) -> None:
    for field in OBSERVATION_FIELDS:
        if field in record and isinstance(record[field], bool):
            output[field] = record[field]


def _failure(record: dict[str, Any], reason: str) -> dict[str, Any]:
    output: dict[str, Any] = {
        "case_id": record["case_id"],
        "normalizerError": reason,
    }
    _copy_observations(record, output)
    return output


def normalize_record(record: dict[str, Any]) -> dict[str, Any]:
    allowed_transport_fields = {"case_id", "assistant_text", *OBSERVATION_FIELDS}
    if set(record) - allowed_transport_fields:
        return _failure(record, "unexpected_transport_fields")

    if any(
        field in record and not isinstance(record[field], bool)
        for field in OBSERVATION_FIELDS
    ):
        return _failure(record, "runtime_observations_must_be_boolean")

    assistant_text = record.get("assistant_text")
    if not isinstance(assistant_text, str):
        return _failure(record, "assistant_text_must_be_string")

    text = assistant_text.strip()
    if text.count(TOOL_CALL_OPEN) != 1 or text.count(TOOL_CALL_CLOSE) != 1:
        return _failure(record, "expected_exactly_one_tool_call")
    if not text.startswith(TOOL_CALL_OPEN) or not text.endswith(TOOL_CALL_CLOSE):
        return _failure(record, "text_outside_tool_call")

    inner = text[len(TOOL_CALL_OPEN) : -len(TOOL_CALL_CLOSE)].strip()
    if TOOL_CALL_OPEN in inner or TOOL_CALL_CLOSE in inner:
        return _failure(record, "nested_tool_call")

    try:
        payload = _strict_json_loads(inner)
    except json.JSONDecodeError:
        return _failure(record, "tool_call_payload_invalid_json")
    except DuplicateJSONKeyError:
        return _failure(record, "tool_call_payload_duplicate_keys")
    except NonFiniteJSONNumberError:
        return _failure(record, "tool_call_payload_non_finite_number")

    if not isinstance(payload, dict):
        return _failure(record, "tool_call_payload_must_be_object")
    if set(payload) != {"name", "arguments"}:
        return _failure(record, "tool_call_payload_fields_must_be_name_arguments")
    if payload["name"] != TOOL_NAME:
        return _failure(record, "unexpected_tool_call_name")

    arguments = payload["arguments"]
    if not isinstance(arguments, dict):
        return _failure(record, "tool_call_arguments_must_be_object")
    if RESERVED_MODEL_FIELDS.intersection(arguments):
        return _failure(record, "model_controls_reserved_field")

    output: dict[str, Any] = {"case_id": record["case_id"], **arguments}
    _copy_observations(record, output)
    return output


def _validate_transport_identity(records: list[dict[str, Any]], path: Path) -> None:
    seen: set[str] = set()
    for line_number, record in enumerate(records, start=1):
        case_id = record.get("case_id")
        if not isinstance(case_id, str) or not case_id.strip():
            raise ValidationError(
                f"{path}:{line_number}: case_id must be a non-empty string"
            )
        if case_id in seen:
            raise ValidationError(f"{path}:{line_number}: duplicate case_id '{case_id}'")
        seen.add(case_id)


def _write_jsonl(path: Path, records: list[dict[str, Any]]) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        text = "".join(
            json.dumps(record, ensure_ascii=False, sort_keys=True, allow_nan=False) + "\n"
            for record in records
        )
        path.write_text(text, encoding="utf-8")
    except ValueError as exc:
        raise ValidationError(f"cannot serialize {path} as strict JSON: {exc}") from exc
    except OSError as exc:
        raise ValidationError(f"cannot write {path}: {exc}") from exc


def generate_requests(output_path: Path) -> None:
    benchmark = validate_benchmark(DEFAULT_BENCHMARK)
    _write_jsonl(output_path, [build_request(record) for record in benchmark])


def normalize_file(input_path: Path, output_path: Path) -> None:
    records = _load_transport_jsonl(input_path)
    _validate_transport_identity(records, input_path)
    _write_jsonl(output_path, [normalize_record(record) for record in records])


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    request_parser = subparsers.add_parser(
        "requests", help="Generate pinned Qwen3 requests from canonical Benchmark V0."
    )
    request_parser.add_argument("--output", type=Path, required=True)

    normalize_parser = subparsers.add_parser(
        "normalize", help="Normalize raw Qwen3 assistant text into evaluator JSONL."
    )
    normalize_parser.add_argument("--input", type=Path, required=True)
    normalize_parser.add_argument("--output", type=Path, required=True)

    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.command == "requests":
            generate_requests(args.output)
        else:
            normalize_file(args.input, args.output)
    except ValidationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
