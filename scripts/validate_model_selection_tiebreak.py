#!/usr/bin/env python3
"""Validate deterministic model-selection tie-break fixtures.

This script is intentionally selection-only: it reads the policy and fixture
files, computes a reference score for verification, and checks that the fixture
expectations stay reproducible. It does not import AgentCore or perform any
runtime selection.
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from decimal import Decimal
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
POLICY_PATH = ROOT / "docs" / "model-selection" / "SELECTION_POLICY_v1.yaml"
FIXTURE_PATH = ROOT / "docs" / "model-selection" / "tie-break-fixtures-v0.json"
LATENCY_ORDER = {"low": 0, "medium": 1, "high": 2}


@dataclass(frozen=True)
class Policy:
    evaluation_weight: Decimal
    latency_weight: Decimal
    capability_weight: Decimal
    primary_fallback: str
    secondary_fallback: str


@dataclass(frozen=True)
class Candidate:
    model_id: str
    evaluation_score: Decimal
    latency_score: Decimal
    capability_match: Decimal
    latency_ms: int
    context_size: int
    max_context_tokens: int
    latency_budget_class: str
    tool_usage_supported: bool


@dataclass(frozen=True)
class Request:
    latency_budget: str
    context_size: int
    tool_usage_required: bool


@dataclass(frozen=True)
class Fixture:
    name: str
    expected_selected_model_id: str
    expected_selection_reason: str | None
    request: Request
    candidates: tuple[Candidate, ...]


@dataclass(frozen=True)
class SelectionResult:
    selected_model_id: str
    reason: str
    score: Decimal | None


def load_policy(path: Path = POLICY_PATH) -> Policy:
    weights: dict[str, Decimal] = {}
    primary: str | None = None
    secondary: str | None = None
    section: str | None = None
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.endswith(":") and not line.startswith("-"):
            section = line[:-1]
            continue
        if section == "ranking_weights" and ":" in line:
            key, value = line.split(":", 1)
            weights[key.strip()] = Decimal(value.strip())
        elif section == "fallback_policy" and ":" in line:
            key, value = line.split(":", 1)
            key = key.strip()
            value = value.strip()
            if key == "primary":
                primary = value
            elif key == "secondary":
                secondary = value
    missing = [key for key in ("evaluation_score", "latency_score", "capability_match") if key not in weights]
    if missing:
        raise ValueError(f"Missing ranking weights in {path}: {', '.join(missing)}")
    if primary is None or secondary is None:
        raise ValueError(f"Missing fallback policy entries in {path}")
    return Policy(
        evaluation_weight=weights["evaluation_score"],
        latency_weight=weights["latency_score"],
        capability_weight=weights["capability_match"],
        primary_fallback=primary,
        secondary_fallback=secondary,
    )


def load_fixtures(path: Path = FIXTURE_PATH) -> tuple[str, tuple[Fixture, ...], str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    fallbacks = data.get("fallbacks", {})
    safe_refusal_model_id = fallbacks.get("safe_refusal_model_id")
    if not isinstance(safe_refusal_model_id, str) or not safe_refusal_model_id:
        raise ValueError(f"{path} must define fallbacks.safe_refusal_model_id")

    fixtures: list[Fixture] = []
    for raw_fixture in data.get("fixtures", []):
        request = raw_fixture.get("request", {})
        candidates = tuple(
            Candidate(
                model_id=item["model_id"],
                evaluation_score=Decimal(str(item["evaluation_score"])),
                latency_score=Decimal(str(item["latency_score"])),
                capability_match=Decimal(str(item["capability_match"])),
                latency_ms=int(item["latency_ms"]),
                context_size=int(item["context_size"]),
                max_context_tokens=int(item["max_context_tokens"]),
                latency_budget_class=str(item["latency_budget_class"]),
                tool_usage_supported=bool(item["tool_usage_supported"]),
            )
            for item in raw_fixture.get("candidates", [])
        )
        fixtures.append(
            Fixture(
                name=raw_fixture["name"],
                expected_selected_model_id=raw_fixture["expected_selected_model_id"],
                expected_selection_reason=raw_fixture.get("expected_selection_reason"),
                request=Request(
                    latency_budget=str(request["latency_budget"]),
                    context_size=int(request["context_size"]),
                    tool_usage_required=bool(request["tool_usage_required"]),
                ),
                candidates=candidates,
            )
        )
    return safe_refusal_model_id, tuple(fixtures), data.get("policy_ref", "")


def is_hard_constraint_valid(candidate: Candidate, request: Request, policy: Policy) -> bool:
    budget_rank = LATENCY_ORDER.get(request.latency_budget)
    model_rank = LATENCY_ORDER.get(candidate.latency_budget_class)
    if budget_rank is None or model_rank is None:
        return False
    if request.context_size > candidate.max_context_tokens:
        return False
    if budget_rank > model_rank:
        return False
    if request.tool_usage_required and not candidate.tool_usage_supported:
        return False
    return True


def score_candidate(candidate: Candidate, policy: Policy) -> Decimal:
    return (
        candidate.evaluation_score * policy.evaluation_weight
        + candidate.latency_score * policy.latency_weight
        + candidate.capability_match * policy.capability_weight
    )


def select_candidate(policy: Policy, fixture: Fixture, safe_refusal_model_id: str) -> SelectionResult:
    eligible = [candidate for candidate in fixture.candidates if is_hard_constraint_valid(candidate, fixture.request, policy)]
    if not eligible:
        return SelectionResult(safe_refusal_model_id, "safe_refusal_model", None)

    scored = [(candidate, score_candidate(candidate, policy)) for candidate in eligible]
    best_score = max(score for _, score in scored)
    top_scored = [item for item in scored if item[1] == best_score]
    if len(top_scored) == 1:
        return SelectionResult(top_scored[0][0].model_id, "highest_weighted_score", best_score)

    min_latency = min(candidate.latency_ms for candidate, _ in top_scored)
    lowest_latency = [item for item in top_scored if item[0].latency_ms == min_latency]
    if len(lowest_latency) == 1:
        return SelectionResult(lowest_latency[0][0].model_id, "lowest_latency_valid_model", best_score)

    return SelectionResult(safe_refusal_model_id, "safe_refusal_model", best_score)


def validate_fixture(policy: Policy, fixture: Fixture, safe_refusal_model_id: str) -> list[str]:
    errors: list[str] = []
    result = select_candidate(policy, fixture, safe_refusal_model_id)
    if result.selected_model_id != fixture.expected_selected_model_id:
        errors.append(
            f"{fixture.name}: expected {fixture.expected_selected_model_id}, got {result.selected_model_id}"
        )
    if fixture.expected_selection_reason and result.reason != fixture.expected_selection_reason:
        errors.append(
            f"{fixture.name}: expected reason {fixture.expected_selection_reason}, got {result.reason}"
        )
    if fixture.name == "hard_constraint_excludes_best_score":
        over_limit = next(c for c in fixture.candidates if c.model_id == "model-over-limit")
        if is_hard_constraint_valid(over_limit, fixture.request, policy):
            errors.append(f"{fixture.name}: hard-constraint candidate was not filtered out")
    return errors


def validate_fixture_file(policy_path: Path = POLICY_PATH, fixture_path: Path = FIXTURE_PATH) -> list[str]:
    policy = load_policy(policy_path)
    safe_refusal_model_id, fixtures, _policy_ref = load_fixtures(fixture_path)
    errors: list[str] = []
    for fixture in fixtures:
        errors.extend(validate_fixture(policy, fixture, safe_refusal_model_id))
    return errors


def main() -> int:
    errors = validate_fixture_file()
    if errors:
        print("Model-selection tie-break validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Model-selection tie-break fixtures are deterministic.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
