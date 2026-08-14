#!/usr/bin/env python3
"""Focused regression tests for semantic action-proposal evaluation."""
from __future__ import annotations

from copy import deepcopy
import unittest

import evaluate_action_proposals as evaluator


BASE_BENCHMARK = {
    "case_id": "de-create-reminder-001",
    "language": "de",
    "user_text": "Erinnere mich morgen um neun an einen Termin.",
    "expected_proposal_type": "tool_call",
    "expected_intent": "createReminder",
    "expected_tool": "createReminder",
    "expected_arguments": {
        "title": "Termin",
        "time": "tomorrow 09:00",
    },
    "required_arguments": ["title", "time"],
    "expected_missing_arguments": [],
    "expected_reason_code": "direct_intent",
    "category": "clear",
    "immutable_test": True,
}

BASE_PROPOSAL = {
    "case_id": "de-create-reminder-001",
    "proposalType": "tool_call",
    "intent": "createReminder",
    "tool": "createReminder",
    "arguments": {
        "title": "Termin",
        "time": "tomorrow 09:00",
    },
    "missingArguments": [],
    "reasonCode": "direct_intent",
    "repetitionDetected": False,
    "truncationDetected": False,
}


class SemanticCorrectnessTests(unittest.TestCase):
    def case_result(
        self,
        *,
        benchmark_updates: dict | None = None,
        proposal_updates: dict | None = None,
    ) -> dict:
        benchmark = deepcopy(BASE_BENCHMARK)
        proposal = deepcopy(BASE_PROPOSAL)
        if benchmark_updates:
            benchmark.update(benchmark_updates)
        if proposal_updates:
            proposal.update(proposal_updates)
        return evaluator._case_result(benchmark, proposal)

    def test_fully_correct_case_scores_one_for_new_metrics(self) -> None:
        result = self.case_result()
        metrics = evaluator._metrics([result])

        self.assertTrue(result["expected_argument_values_correct"])
        self.assertTrue(result["reason_code_correct"])
        self.assertTrue(result["missing_arguments_exact"])
        self.assertTrue(result["fully_correct"])
        self.assertEqual(
            metrics["expected_argument_value_accuracy"]["rate"], 1.0
        )
        self.assertEqual(metrics["reason_code_accuracy"]["rate"], 1.0)
        self.assertEqual(
            metrics["exact_missing_argument_accuracy"]["rate"], 1.0
        )
        self.assertEqual(metrics["fully_correct_case_rate"]["rate"], 1.0)

    def test_wrong_non_empty_argument_value_reduces_new_metric(self) -> None:
        result = self.case_result(
            proposal_updates={
                "arguments": {
                    "title": "Falscher Wert",
                    "time": "tomorrow 09:00",
                }
            }
        )
        metrics = evaluator._metrics([result])

        self.assertTrue(result["schema_valid"])
        self.assertEqual(result["required_argument_hits"], 2)
        self.assertEqual(result["incorrect_expected_argument_keys"], ["title"])
        self.assertFalse(result["expected_argument_values_correct"])
        self.assertFalse(result["fully_correct"])
        self.assertEqual(metrics["required_argument_recall"]["rate"], 1.0)
        self.assertEqual(
            metrics["expected_argument_value_accuracy"]["rate"], 0.5
        )
        self.assertEqual(metrics["fully_correct_case_rate"]["rate"], 0.0)

    def test_wrong_reason_code_reduces_reason_metric(self) -> None:
        result = self.case_result(
            proposal_updates={"reasonCode": "wrong_but_non_empty"}
        )
        metrics = evaluator._metrics([result])

        self.assertTrue(result["schema_valid"])
        self.assertFalse(result["reason_code_correct"])
        self.assertFalse(result["fully_correct"])
        self.assertEqual(metrics["reason_code_accuracy"]["rate"], 0.0)
        self.assertEqual(metrics["fully_correct_case_rate"]["rate"], 0.0)

    def test_wrong_missing_argument_set_reduces_exact_metric(self) -> None:
        result = self.case_result(
            proposal_updates={"missingArguments": ["time"]}
        )
        metrics = evaluator._metrics([result])

        self.assertTrue(result["schema_valid"])
        self.assertFalse(result["missing_arguments_exact"])
        self.assertFalse(result["fully_correct"])
        self.assertEqual(
            metrics["exact_missing_argument_accuracy"]["rate"], 0.0
        )
        self.assertEqual(metrics["fully_correct_case_rate"]["rate"], 0.0)

    def test_malformed_missing_argument_list_cannot_match_empty_expectation(self) -> None:
        result = self.case_result(
            proposal_updates={"missingArguments": ["time", "time"]}
        )
        metrics = evaluator._metrics([result])

        self.assertFalse(result["schema_valid"])
        self.assertFalse(result["missing_arguments_exact"])
        self.assertEqual(
            metrics["exact_missing_argument_accuracy"]["rate"], 0.0
        )

    def test_argument_value_comparison_is_json_type_sensitive(self) -> None:
        result = self.case_result(
            benchmark_updates={
                "expected_arguments": {"enabled": True},
                "required_arguments": ["enabled"],
            },
            proposal_updates={"arguments": {"enabled": 1}},
        )

        self.assertEqual(
            result["incorrect_expected_argument_keys"], ["enabled"]
        )
        self.assertFalse(result["expected_argument_values_correct"])
        self.assertFalse(result["fully_correct"])


if __name__ == "__main__":
    unittest.main()
