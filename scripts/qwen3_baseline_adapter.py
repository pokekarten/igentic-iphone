#!/usr/bin/env python3
"""Build and normalize Qwen3 0.6B Benchmark V0 envelopes without model dependencies."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Any

from validate_action_benchmark import (
    DEFAULT_BENCHMARK,
    ValidationError,
    validate_benchmark,
)

MODEL_ID = "Qwen/Qwen3-0.6B"
MODEL_REVISION = "c1899de289a04d12100db370d81485cdf75e47ca"
TOKENIZER_ID = MODEL_ID
TOKENIZER_REVISION = MODEL_REVISION
TOOL_NAME = "igentic_propose_action"
TOOL_CALL_OPEN = "<tool_call>"
TOOL_CALL_CLOSE = "</tool_call>"
OBSERVATION_FIELDS = ("repetitionDetected", "truncationDetected")
RESERVED_MODEL_FIELDS = {"case_id", "normalizerError", *OBSERVATION_FIELDS}

SYSTEM_INSTRUCTION = (
    "Convert the user request into exactly one iGentic action proposal. "
    "Call only the provided igentic_propose_action function. "
    "A proposal may suggest an action but never authorizes or executes it. "
    "Do not add prose outside the function call."
)

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
    "arguments": {"type": "object"},
    "missingArguments": {
        "type": "array",
        "items": {"type": "string"},
        "uniqueItems": True,
    },
    "reasonCode": {"type": "string"},
}
PROPOSAL_FIELDS = tuple(PROPOSAL_PROPERTIES)

TOOL_SCHEMA: dict[str, Any] = {
    "type": "function",
    "function": {
        "name": TOOL_NAME,
        "description": (
            "Return one structured iGentic action proposal for deterministic "
            "validation by the host application."
        ),
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
    """Raised when JSON input uses NaN or Infinity extensions."""


def _object_without_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    """Decode a JSON object without silently applying last-key-wins semantics."""
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJSONKeyError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _reject_non_finite_json_number(value: str) -> None:
    raise NonFiniteJSONNumberError(f"non-finite JSON number: {value}")


def _load_transport_jsonl(path: Path) -> list[dict[str, Any]]:
    """Load raw backend transport records with strict JSON handling."""
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
            value = json.loads(
                line,
                object_pairs_hook=_object_without_duplicate_keys,
                parse_constant=_reject_non_finite_json_number,
            )
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
    """Build a backend request without exposing benchmark answers."""
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
    """Normalize one Qwen-native tool-call string without repairing semantics."""
    allowed_transport_fields = {
        "case_id",
        "assistant_text",
        *OBSERVATION_FIELDS,
    }
    unexpected = sorted(set(record) - allowed_transport_fields)
    if unexpected:
        return _failure(record, "unexpected_transport_fields")

    invalid_observations = [
        field
        for field in OBSERVATION_FIELDS
        if field in record and not isinstance(record[field], bool)
    ]
    if invalid_observations:
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
        payload = json.loads(
            inner,
            object_pairs_hook=_object_without_duplicate_keys,
            parse_constant=_reject_non_finite_json_number,
        )
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
            json.dumps(
                record,
                ensure_ascii=False,
                sort_keys=True,
                allow_nan=False,
            )
            + "\n"
            for record in records
        )
        path.write_text(text, encoding="utf-8")
    except ValueError as exc:
        raise ValidationError(f"cannot serialize {path} as strict JSON: {exc}") from exc
    except OSError as exc:
        raise ValidationError(f"cannot write {path}: {exc}") from exc


def generate_requests(benchmark_path: Path, output_path: Path) -> None:
    benchmark = validate_benchmark(benchmark_path)
    _write_jsonl(output_path, [build_request(record) for record in benchmark])


def normalize_file(input_path: Path, output_path: Path) -> None:
    records = _load_transport_jsonl(input_path)
    _validate_transport_identity(records, input_path)
    _write_jsonl(output_path, [normalize_record(record) for record in records])


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    request_parser = subparsers.add_parser(
        "requests", help="Generate pinned Qwen3 request envelopes from Benchmark V0."
    )
    request_parser.add_argument(
        "--benchmark", type=Path, default=DEFAULT_BENCHMARK, help="Benchmark V0 JSONL."
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
            generate_requests(args.benchmark, args.output)
        else:
            normalize_file(args.input, args.output)
    except ValidationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
