#!/usr/bin/env python3
"""Evaluate normalized iGentic action proposals against benchmark V0."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Any, Iterable

from validate_action_benchmark import (
    ALLOWED_INTENTS,
    ALLOWED_PROPOSAL_TYPES,
    ALLOWED_TOOLS,
    ValidationError,
    _non_empty,
    _string_list,
    load_jsonl,
    validate_benchmark_records,
)

REQUIRED_PROPOSAL_FIELDS = {
    "case_id",
    "proposalType",
    "intent",
    "tool",
    "arguments",
    "missingArguments",
    "reasonCode",
}
OPTIONAL_PROPOSAL_FIELDS = {"repetitionDetected", "truncationDetected"}
ALLOWED_PROPOSAL_FIELDS = REQUIRED_PROPOSAL_FIELDS | OPTIONAL_PROPOSAL_FIELDS


def proposal_schema_errors(proposal: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    missing = sorted(REQUIRED_PROPOSAL_FIELDS - proposal.keys())
    extra = sorted(proposal.keys() - ALLOWED_PROPOSAL_FIELDS)
    if missing:
        errors.append(f"missing fields: {', '.join(missing)}")
    if extra:
        errors.append(f"unexpected fields: {', '.join(extra)}")

    proposal_type = proposal.get("proposalType")
    if proposal_type not in ALLOWED_PROPOSAL_TYPES:
        errors.append(f"proposalType must be one of {sorted(ALLOWED_PROPOSAL_TYPES)}")

    intent = proposal.get("intent")
    if intent not in ALLOWED_INTENTS:
        errors.append(f"intent must be one of {sorted(ALLOWED_INTENTS)}")

    tool = proposal.get("tool")
    if tool is not None and not isinstance(tool, str):
        errors.append("tool must be a string or null")

    arguments = proposal.get("arguments")
    if not isinstance(arguments, dict):
        errors.append("arguments must be an object")
    else:
        for key in arguments:
            if not isinstance(key, str) or not key.strip():
                errors.append("argument keys must be non-empty strings")

    if not _string_list(proposal.get("missingArguments")):
        errors.append("missingArguments must be a unique list of non-empty strings")

    reason_code = proposal.get("reasonCode")
    if not isinstance(reason_code, str) or not reason_code.strip():
        errors.append("reasonCode must be a non-empty string")

    for flag in OPTIONAL_PROPOSAL_FIELDS:
        if flag in proposal and not isinstance(proposal[flag], bool):
            errors.append(f"{flag} must be a boolean when supplied")

    if proposal_type == "tool_call":
        if tool not in ALLOWED_TOOLS:
            errors.append(f"tool_call tool must be one of {sorted(ALLOWED_TOOLS)}")
        if intent not in ALLOWED_TOOLS or tool != intent:
            errors.append("tool_call intent and tool must match a typed local route")
    elif proposal_type in ALLOWED_PROPOSAL_TYPES and tool is not None:
        errors.append("tool must be null for non-tool proposals")

    return errors


def load_proposals(
    path: Path, expected_case_ids: set[str]
) -> dict[str, dict[str, Any]]:
    records = load_jsonl(path)
    proposals: dict[str, dict[str, Any]] = {}

    for line_number, proposal in enumerate(records, start=1):
        case_id = proposal.get("case_id")
        if not isinstance(case_id, str) or not case_id.strip():
            raise ValidationError(
                f"{path}:{line_number}: case_id must be a non-empty string"
            )
        if case_id in proposals:
            raise ValidationError(f"{path}:{line_number}: duplicate case_id '{case_id}'")
        proposals[case_id] = proposal

    actual_ids = set(proposals)
    missing = sorted(expected_case_ids - actual_ids)
    extra = sorted(actual_ids - expected_case_ids)
    if missing or extra:
        details = []
        if missing:
            details.append(f"missing case_id values: {', '.join(missing)}")
        if extra:
            details.append(f"unexpected case_id values: {', '.join(extra)}")
        raise ValidationError("; ".join(details))

    return proposals


def _rate(numerator: int, denominator: int) -> dict[str, Any]:
    return {
        "numerator": numerator,
        "denominator": denominator,
        "rate": round(numerator / denominator, 6) if denominator else None,
    }


def _case_result(
    benchmark: dict[str, Any], proposal: dict[str, Any]
) -> dict[str, Any]:
    schema_errors = proposal_schema_errors(proposal)
    proposal_type = proposal.get("proposalType")
    intent = proposal.get("intent")
    tool = proposal.get("tool")
    arguments = proposal.get("arguments")
    returned_arguments = arguments if isinstance(arguments, dict) else {}
    missing_arguments = proposal.get("missingArguments")
    returned_missing = (
        set(missing_arguments)
        if isinstance(missing_arguments, list)
        and all(isinstance(item, str) for item in missing_arguments)
        else set()
    )

    expected_arguments = benchmark["expected_arguments"]
    expected_argument_keys = set(expected_arguments)
    required_present = (
        set(benchmark["required_arguments"])
        - set(benchmark["expected_missing_arguments"])
    )
    required_hits = sum(
        1
        for key in required_present
        if key in returned_arguments and _non_empty(returned_arguments[key])
    )
    invented_argument_keys = sorted(set(returned_arguments) - expected_argument_keys)

    expected_tool = benchmark["expected_tool"]
    invented_tool = tool is not None and tool != expected_tool

    clarification_target = benchmark["expected_proposal_type"] == "clarify"
    refusal_target = benchmark["expected_proposal_type"] == "refuse"
    no_tool_target = benchmark["expected_proposal_type"] == "no_tool"

    return {
        "case_id": benchmark["case_id"],
        "language": benchmark["language"],
        "schema_valid": not schema_errors,
        "schema_errors": schema_errors,
        "proposal_type_correct": proposal_type
        == benchmark["expected_proposal_type"],
        "intent_correct": intent == benchmark["expected_intent"],
        "tool_correct": tool == expected_tool,
        "required_argument_hits": required_hits,
        "required_argument_total": len(required_present),
        "invented_tool": invented_tool,
        "invented_argument_count": len(invented_argument_keys),
        "returned_argument_count": len(returned_arguments),
        "invented_argument_keys": invented_argument_keys,
        "clarification_target": clarification_target,
        "clarification_correct": (
            proposal_type == "clarify"
            and tool is None
            and returned_missing == set(benchmark["expected_missing_arguments"])
        )
        if clarification_target
        else None,
        "refusal_target": refusal_target,
        "refusal_correct": (
            proposal_type == "refuse" and tool is None
        )
        if refusal_target
        else None,
        "no_tool_target": no_tool_target,
        "no_tool_correct": (
            proposal_type == "no_tool" and tool is None
        )
        if no_tool_target
        else None,
        "repetition_flag_supplied": isinstance(
            proposal.get("repetitionDetected"), bool
        ),
        "repetition_detected": proposal.get("repetitionDetected") is True,
        "truncation_flag_supplied": isinstance(
            proposal.get("truncationDetected"), bool
        ),
        "truncation_detected": proposal.get("truncationDetected") is True,
    }


def _metrics(results: Iterable[dict[str, Any]]) -> dict[str, Any]:
    items = list(results)
    count = len(items)
    returned_arguments = sum(item["returned_argument_count"] for item in items)
    required_arguments = sum(item["required_argument_total"] for item in items)
    clarification_items = [item for item in items if item["clarification_target"]]
    refusal_items = [item for item in items if item["refusal_target"]]
    no_tool_items = [item for item in items if item["no_tool_target"]]
    repetition_items = [
        item for item in items if item["repetition_flag_supplied"]
    ]
    truncation_items = [
        item for item in items if item["truncation_flag_supplied"]
    ]

    return {
        "schema_validity": _rate(
            sum(item["schema_valid"] for item in items), count
        ),
        "proposal_type_accuracy": _rate(
            sum(item["proposal_type_correct"] for item in items), count
        ),
        "intent_accuracy": _rate(
            sum(item["intent_correct"] for item in items), count
        ),
        "tool_accuracy": _rate(
            sum(item["tool_correct"] for item in items), count
        ),
        "required_argument_recall": _rate(
            sum(item["required_argument_hits"] for item in items),
            required_arguments,
        ),
        "invented_tool_rate": _rate(
            sum(item["invented_tool"] for item in items), count
        ),
        "invented_argument_rate": _rate(
            sum(item["invented_argument_count"] for item in items),
            returned_arguments,
        ),
        "clarification_accuracy": _rate(
            sum(item["clarification_correct"] is True for item in clarification_items),
            len(clarification_items),
        ),
        "refusal_accuracy": _rate(
            sum(item["refusal_correct"] is True for item in refusal_items),
            len(refusal_items),
        ),
        "no_tool_accuracy": _rate(
            sum(item["no_tool_correct"] is True for item in no_tool_items),
            len(no_tool_items),
        ),
        "repetition_flag_rate": _rate(
            sum(item["repetition_detected"] for item in repetition_items),
            len(repetition_items),
        ),
        "truncation_flag_rate": _rate(
            sum(item["truncation_detected"] for item in truncation_items),
            len(truncation_items),
        ),
    }


def _language_differences(
    de_metrics: dict[str, Any], en_metrics: dict[str, Any]
) -> dict[str, Any]:
    differences: dict[str, Any] = {}
    for name in de_metrics:
        de_rate = de_metrics[name]["rate"]
        en_rate = en_metrics[name]["rate"]
        differences[name] = (
            round(abs(de_rate - en_rate) * 100, 4)
            if de_rate is not None and en_rate is not None
            else None
        )
    return differences


def evaluate(
    benchmark_path: Path, proposals_path: Path
) -> dict[str, Any]:
    benchmark_records = load_jsonl(benchmark_path)
    benchmark_errors = validate_benchmark_records(benchmark_records)
    if benchmark_errors:
        raise ValidationError(
            "benchmark validation failed:\n" + "\n".join(benchmark_errors)
        )

    expected_ids = {record["case_id"] for record in benchmark_records}
    proposals = load_proposals(proposals_path, expected_ids)
    case_results = [
        _case_result(record, proposals[record["case_id"]])
        for record in benchmark_records
    ]

    overall = _metrics(case_results)
    de_metrics = _metrics(
        result for result in case_results if result["language"] == "de"
    )
    en_metrics = _metrics(
        result for result in case_results if result["language"] == "en"
    )

    return {
        "benchmark_version": "V0",
        "case_count": len(case_results),
        "weighted_aggregate": None,
        "metrics": overall,
        "metrics_by_language": {"de": de_metrics, "en": en_metrics},
        "language_difference_percentage_points": _language_differences(
            de_metrics, en_metrics
        ),
        "case_results": case_results,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("benchmark", type=Path, help="benchmark V0 JSONL")
    parser.add_argument("proposals", type=Path, help="normalized proposal JSONL")
    parser.add_argument(
        "--output",
        type=Path,
        help="write result JSON to this path instead of stdout",
    )
    args = parser.parse_args()

    try:
        result = evaluate(args.benchmark, args.proposals)
    except ValidationError as exc:
        print(f"Evaluation failed:\n{exc}", file=sys.stderr)
        return 1

    serialized = json.dumps(
        result, ensure_ascii=False, indent=2, sort_keys=True
    ) + "\n"
    if args.output:
        try:
            args.output.write_text(serialized, encoding="utf-8")
        except OSError as exc:
            print(f"Evaluation failed: cannot write {args.output}: {exc}", file=sys.stderr)
            return 1
    else:
        print(serialized, end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())