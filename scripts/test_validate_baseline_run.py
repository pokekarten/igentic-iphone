#!/usr/bin/env python3
"""Regression tests for the untouched baseline run manifest validator."""
from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import unittest

import validate_baseline_run as validator

ROOT = Path(__file__).resolve().parents[1]
EXAMPLE = ROOT / "docs/model-research/baseline-run-manifest-v0.example.json"


class BaselineRunValidatorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = validator.load_manifest(EXAMPLE)

    def errors(self, manifest: dict) -> list[str]:
        return validator.validate_manifest(manifest)

    def assert_error_contains(self, manifest: dict, fragment: str) -> None:
        errors = self.errors(manifest)
        self.assertTrue(
            any(fragment in error for error in errors),
            f"expected error containing {fragment!r}, got {errors!r}",
        )

    def test_canonical_router_small_example_passes(self) -> None:
        self.assertEqual(self.errors(self.manifest), [])

    def test_canonical_router_normal_passes(self) -> None:
        manifest = deepcopy(self.manifest)
        manifest["profile"].update(
            {
                "name": "Router-normal",
                "input_limit_tokens": 1024,
                "output_limit_tokens": 64,
            }
        )
        manifest["decoding"]["max_output_tokens"] = 64
        self.assertEqual(self.errors(manifest), [])

    def test_router_small_wrong_input_limit_fails(self) -> None:
        manifest = deepcopy(self.manifest)
        manifest["profile"]["input_limit_tokens"] = 1024
        self.assert_error_contains(
            manifest,
            "profile Router-small requires input_limit_tokens=512",
        )

    def test_router_small_wrong_output_limit_fails(self) -> None:
        manifest = deepcopy(self.manifest)
        manifest["profile"]["output_limit_tokens"] = 64
        manifest["decoding"]["max_output_tokens"] = 64
        self.assert_error_contains(
            manifest,
            "profile Router-small requires output_limit_tokens=32",
        )

    def test_router_normal_wrong_input_limit_fails(self) -> None:
        manifest = deepcopy(self.manifest)
        manifest["profile"].update(
            {
                "name": "Router-normal",
                "input_limit_tokens": 512,
                "output_limit_tokens": 64,
            }
        )
        manifest["decoding"]["max_output_tokens"] = 64
        self.assert_error_contains(
            manifest,
            "profile Router-normal requires input_limit_tokens=1024",
        )

    def test_router_normal_wrong_output_limit_fails(self) -> None:
        manifest = deepcopy(self.manifest)
        manifest["profile"].update(
            {
                "name": "Router-normal",
                "input_limit_tokens": 1024,
                "output_limit_tokens": 32,
            }
        )
        manifest["decoding"]["max_output_tokens"] = 32
        self.assert_error_contains(
            manifest,
            "profile Router-normal requires output_limit_tokens=64",
        )

    def test_decoding_max_below_profile_output_limit_fails(self) -> None:
        manifest = deepcopy(self.manifest)
        manifest["decoding"]["max_output_tokens"] = 16
        self.assert_error_contains(
            manifest,
            "decoding.max_output_tokens must equal profile.output_limit_tokens",
        )

    def test_decoding_max_above_profile_output_limit_fails(self) -> None:
        manifest = deepcopy(self.manifest)
        manifest["decoding"]["max_output_tokens"] = 64
        self.assert_error_contains(
            manifest,
            "decoding.max_output_tokens must equal profile.output_limit_tokens",
        )

    def test_backend_specific_larger_context_remains_valid(self) -> None:
        manifest = deepcopy(self.manifest)
        manifest["profile"]["context_limit_tokens"] = 32768
        self.assertEqual(self.errors(manifest), [])

    def test_context_smaller_than_profile_budget_fails(self) -> None:
        manifest = deepcopy(self.manifest)
        manifest["profile"]["context_limit_tokens"] = 543
        self.assert_error_contains(
            manifest,
            "profile input_limit_tokens + output_limit_tokens must not exceed context_limit_tokens",
        )

    def test_unverified_license_cannot_keep(self) -> None:
        manifest = deepcopy(self.manifest)
        manifest["backend"]["license_gate_status"] = "unverified"
        manifest["next_decision"] = "keep"
        self.assert_error_contains(
            manifest,
            "a blocked or unverified license gate cannot produce keep or rework",
        )

    def test_training_claim_remains_rejected(self) -> None:
        manifest = deepcopy(self.manifest)
        manifest["specialization"]["training_performed"] = True
        self.assert_error_contains(
            manifest,
            "specialization.training_performed must be false for an untouched baseline",
        )

    def test_host_evidence_cannot_claim_physical_readiness(self) -> None:
        manifest = deepcopy(self.manifest)
        manifest["claims"]["physical_device_readiness_claimed"] = True
        self.assert_error_contains(
            manifest,
            "physical-device readiness cannot be claimed from host or simulator evidence",
        )


if __name__ == "__main__":
    unittest.main()
