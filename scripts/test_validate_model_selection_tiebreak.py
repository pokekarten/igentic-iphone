#!/usr/bin/env python3
"""Unit tests for the model-selection tie-break validator."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from validate_model_selection_tiebreak import (  # noqa: E402
    FIXTURE_PATH,
    POLICY_PATH,
    load_fixtures,
    load_policy,
    select_candidate,
    validate_fixture_file,
)


class ValidateModelSelectionTieBreakTests(unittest.TestCase):
    def test_bundled_fixtures_validate_cleanly(self) -> None:
        self.assertEqual(validate_fixture_file(), [])

    def test_expected_selection_mismatch_is_detected(self) -> None:
        payload = json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))
        payload["fixtures"][0]["expected_selected_model_id"] = "model-not-the-winner"
        with tempfile.TemporaryDirectory() as tmpdir:
            fixture_path = Path(tmpdir) / "fixtures.json"
            fixture_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
            errors = validate_fixture_file(POLICY_PATH, fixture_path)
        self.assertTrue(any("tie_break_lowest_latency" in error for error in errors))

    def test_hard_constraint_filtering_excludes_invalid_candidate(self) -> None:
        policy = load_policy(POLICY_PATH)
        safe_refusal_model_id, fixtures, _ = load_fixtures(FIXTURE_PATH)
        fixture = next(item for item in fixtures if item.name == "hard_constraint_excludes_best_score")
        result = select_candidate(policy, fixture, safe_refusal_model_id)
        self.assertEqual(result.selected_model_id, "model-valid")
        self.assertEqual(result.reason, "highest_weighted_score")

    def test_tie_break_uses_safe_refusal_when_latency_also_ties(self) -> None:
        policy = load_policy(POLICY_PATH)
        safe_refusal_model_id, fixtures, _ = load_fixtures(FIXTURE_PATH)
        fixture = next(item for item in fixtures if item.name == "tie_break_safe_refusal")
        result = select_candidate(policy, fixture, safe_refusal_model_id)
        self.assertEqual(result.selected_model_id, "model-safe-refusal")
        self.assertEqual(result.reason, "safe_refusal_model")


if __name__ == "__main__":
    unittest.main(verbosity=2)
