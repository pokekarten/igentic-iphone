#!/usr/bin/env python3
"""Validate the immutable iGentic action-routing benchmark V0."""
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BENCHMARK = ROOT / "docs/model-research/igentic-action-benchmark-v0.jsonl"

ALLOWED_LANGUAGES = {"de", "en"}
ALLOWED_PROPOSAL_TYPES = {"tool_call", "clarify", "no_tool", "refuse"}
ALLOWED_INTENTS = {
    "createReminder",
    "summarizeNote",
    "findFile",
    "requestApproval",
    "unknown",
}
ALLOWED_TOOLS = {
    "createReminder",
    "summarizeNote",
    "findFile",
    "requestApproval",
}
ALLOWED_CATEGORIES = {
    "clear",
    "missing_argument",
    "ambiguous",
    "unsupported",
    "no_tool",
    "refusal",
}
REQUIRED_FIELDS = {
    "case_id",
    "language",
    "user_text",
    "expected_proposal_type",
    "expected_intent",
    "expected_tool",
    "expected_arguments",
    "required_arguments",
    "expected_missing_arguments",
    "expected_reason_code",
    "category",
    "immutable_test",
}
CATEGORY_PROPOSAL_TYPES = {
    "clear": "tool_call",
    "missing_argument": "clarify",
    "ambiguous": "clarify",
    "unsupported": "no_tool",
    "no_tool": "no_tool",
    "refusal": "refuse",
}


class ValidationError(ValueError):
    """Raised when JSONL cannot be safely interpreted."""


def load_jsonl(path: Path) -> list[dict[str, Any]]:
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
            value = json.loads(line)
        except json.JSONDecodeError as exc:
            raise ValidationError(
                f"{path}:{line_number}: invalid JSON: {exc.msg}"
            ) from exc
        if not isinstance(value, dict):
            raise ValidationError(f"{path}:{line_number}: each JSONL record must be an object")
        records.append(value)
    return records


def _string_list(value: Any) -> bool:
    return (
        isinstance(value, list)
        and all(isinstance(item, str) and item.strip() for item in value)
        and len(value) == len(set(value))
    )


def _non_empty(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, (list, dict)):
        return bool(value)
    return True


def validate_benchmark_records(records: list[dict[str, Any]]) -> list[str]:
    errors: list[str] = []
    ids: list[str] = []
    languages: Counter[str] = Counter()
    intents: Counter[str] = Counter()

    if len(records) != 40:
        errors.append(f"expected exactly 40 records, found {len(records)}")

    for index, record in enumerate(records, start=1):
        prefix = f"record {index}"
        missing = sorted(REQUIRED_FIELDS - record.keys())
        extra = sorted(record.keys() - REQUIRED_FIELDS)
        if missing:
            errors.append(f"{prefix}: missing fields: {', '.join(missing)}")
        if extra:
            errors.append(f"{prefix}: unexpected fields: {', '.join(extra)}")

        case_id = record.get("case_id")
        if not isinstance(case_id, str) or not case_id.strip():
            errors.append(f"{prefix}: case_id must be a non-empty string")
        else:
            ids.append(case_id)
            prefix = case_id

        language = record.get("language")
        if language not in ALLOWED_LANGUAGES:
            errors.append(f"{prefix}: language must be one of {sorted(ALLOWED_LANGUAGES)}")
        else:
            languages[language] += 1
            if isinstance(case_id, str) and not case_id.startswith(f"{language}-"):
                errors.append(f"{prefix}: case_id must start with '{language}-'")

        user_text = record.get("user_text")
        if not isinstance(user_text, str) or not user_text.strip():
            errors.append(f"{prefix}: user_text must be a non-empty string")

        proposal_type = record.get("expected_proposal_type")
        if proposal_type not in ALLOWED_PROPOSAL_TYPES:
            errors.append(
                f"{prefix}: expected_proposal_type must be one of "
                f"{sorted(ALLOWED_PROPOSAL_TYPES)}"
            )

        intent = record.get("expected_intent")
        if intent not in ALLOWED_INTENTS:
            errors.append(f"{prefix}: expected_intent must be one of {sorted(ALLOWED_INTENTS)}")
        else:
            intents[intent] += 1

        tool = record.get("expected_tool")
        if tool is not None and not isinstance(tool, str):
            errors.append(f"{prefix}: expected_tool must be a string or null")

        arguments = record.get("expected_arguments")
        if not isinstance(arguments, dict):
            errors.append(f"{prefix}: expected_arguments must be an object")
            arguments = {}
        else:
            for key, value in arguments.items():
                if not isinstance(key, str) or not key.strip():
                    errors.append(f"{prefix}: expected_arguments keys must be non-empty strings")
                if not _non_empty(value):
                    errors.append(f"{prefix}: expected argument '{key}' must not be empty")

        required_arguments = record.get("required_arguments")
        if not _string_list(required_arguments):
            errors.append(
                f"{prefix}: required_arguments must be a unique list of non-empty strings"
            )
            required_arguments = []

        missing_arguments = record.get("expected_missing_arguments")
        if not _string_list(missing_arguments):
            errors.append(
                f"{prefix}: expected_missing_arguments must be a unique list "
                "of non-empty strings"
            )
            missing_arguments = []

        if not set(missing_arguments).issubset(set(required_arguments)):
            errors.append(
                f"{prefix}: expected_missing_arguments must be a subset of required_arguments"
            )
        for key in required_arguments:
            has_expected_value = key in arguments and _non_empty(arguments[key])
            is_expected_missing = key in missing_arguments
            if has_expected_value == is_expected_missing:
                errors.append(
                    f"{prefix}: required argument '{key}' must have exactly one "
                    "expected state: a non-empty value or expected missing"
                )
        for key in missing_arguments:
            if key in arguments and _non_empty(arguments[key]):
                errors.append(f"{prefix}: missing argument '{key}' must not have a value")

        reason_code = record.get("expected_reason_code")
        if not isinstance(reason_code, str) or not reason_code.strip():
            errors.append(f"{prefix}: expected_reason_code must be a non-empty string")

        category = record.get("category")
        if category not in ALLOWED_CATEGORIES:
            errors.append(f"{prefix}: category must be one of {sorted(ALLOWED_CATEGORIES)}")
        elif proposal_type in ALLOWED_PROPOSAL_TYPES:
            expected_type = CATEGORY_PROPOSAL_TYPES[category]
            if proposal_type != expected_type:
                errors.append(
                    f"{prefix}: category '{category}' requires proposal type '{expected_type}'"
                )

        if record.get("immutable_test") is not True:
            errors.append(f"{prefix}: immutable_test must be true")

        if proposal_type == "tool_call":
            if intent not in ALLOWED_TOOLS:
                errors.append(f"{prefix}: tool_call requires a typed local intent")
            if tool != intent:
                errors.append(f"{prefix}: expected_tool must exactly match expected_intent")
            if missing_arguments:
                errors.append(f"{prefix}: tool_call cannot declare missing arguments")
            for key in required_arguments:
                if key not in arguments or not _non_empty(arguments[key]):
                    errors.append(
                        f"{prefix}: tool_call is missing required expected argument '{key}'"
                    )
        elif proposal_type in ALLOWED_PROPOSAL_TYPES and tool is not None:
            errors.append(f"{prefix}: expected_tool must be null for non-tool proposals")

    duplicates = sorted(case_id for case_id, count in Counter(ids).items() if count > 1)
    if duplicates:
        errors.append(f"duplicate case_id values: {', '.join(duplicates)}")

    if languages != Counter({"de": 20, "en": 20}):
        errors.append(
            "language distribution must be exactly de=20 and en=20; "
            f"found {dict(sorted(languages.items()))}"
        )

    expected_intents = Counter({intent: 8 for intent in ALLOWED_INTENTS})
    if intents != expected_intents:
        errors.append(
            "intent distribution must be exactly 8 per current intent; "
            f"found {dict(sorted(intents.items()))}"
        )

    return errors


def validate_benchmark(path: Path) -> list[dict[str, Any]]:
    records = load_jsonl(path)
    errors = validate_benchmark_records(records)
    if errors:
        raise ValidationError("\n".join(errors))
    return records


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "benchmark",
        nargs="?",
        type=Path,
        default=DEFAULT_BENCHMARK,
        help=f"benchmark JSONL (default: {DEFAULT_BENCHMARK.relative_to(ROOT)})",
    )
    args = parser.parse_args()

    try:
        records = validate_benchmark(args.benchmark)
    except ValidationError as exc:
        print(f"Benchmark validation failed:\n{exc}", file=sys.stderr)
        return 1

    languages = Counter(record["language"] for record in records)
    intents = Counter(record["expected_intent"] for record in records)
    print(
        "Benchmark valid: "
        f"{len(records)} records; "
        f"languages={dict(sorted(languages.items()))}; "
        f"intents={dict(sorted(intents.items()))}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
