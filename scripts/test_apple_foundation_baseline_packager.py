#!/usr/bin/env python3
"""Regression tests for apple_foundation_baseline_packager.py."""
from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import apple_foundation_baseline_packager as packager
from validate_action_benchmark import ValidationError
from validate_baseline_run import validate_manifest


class AppleFoundationBaselinePackagerTests(unittest.TestCase):
    def test_identical_synthetic_runs_package_byte_identically(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            left = self._make_run(root / "left")
            right = self._make_run(root / "right")

            left_package = packager.build_package(left)
            right_package = packager.build_package(right)

            self.assertEqual(left_package, right_package)
            self.assertNotIn(b"expected_", left_package[packager.NORMALIZED_INPUT])

            manifest = json.loads(left_package[packager.BASELINE_MANIFEST])
            self.assertEqual(validate_manifest(manifest), [])
            self.assertEqual(manifest["backend"]["class"], "apple_system")
            self.assertIsNone(manifest["backend"]["model_id"])
            self.assertIsNone(manifest["backend"]["model_revision"])
            self.assertEqual(manifest["backend"]["license_gate_status"], "unverified")
            self.assertEqual(manifest["execution"]["evidence_class"], "host")
            self.assertFalse(manifest["execution"]["physical_device_run"])
            self.assertFalse(manifest["claims"]["physical_device_readiness_claimed"])
            self.assertEqual(manifest["next_decision"], "unverified")
            self.assertFalse(manifest["decoding"]["seed_supported"])
            self.assertIsNone(manifest["decoding"]["seed"])
            self.assertRegex(manifest["normalizer"]["revision"], r"^[0-9a-f]{64}$")

    def test_package_run_writes_only_three_package_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            run_dir = self._make_run(Path(temp) / "run")
            packager.package_run(run_dir)

            self.assertEqual(
                {path.name for path in run_dir.iterdir()},
                set(packager.INPUT_FILENAMES) | set(packager.OUTPUT_FILENAMES),
            )
            manifest = json.loads((run_dir / packager.BASELINE_MANIFEST).read_text())
            self.assertEqual(validate_manifest(manifest), [])

    def test_preserves_wrong_allowed_semantics_and_duplicate_missing_arguments(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            run_dir = self._make_run(Path(temp) / "run")
            raw = self._read_jsonl(run_dir / packager.RAW_PROPOSALS)
            normalized = self._read_jsonl(run_dir / packager.NORMALIZED_PROPOSALS)

            raw[0]["proposal"] = {
                "proposalType": "clarify",
                "intent": "findFile",
                "tool": "findFile",
                "arguments": {"title": "model-generated but wrong"},
                "missingArguments": ["query", "query"],
                "reasonCode": "ambiguous_file_reference",
            }
            normalized[0] = {
                "case_id": raw[0]["case_id"],
                "proposalType": "clarify",
                "intent": "findFile",
                "tool": "findFile",
                "arguments": {"title": "model-generated but wrong"},
                "missingArguments": ["query", "query"],
                "reasonCode": "ambiguous_file_reference",
                "repetitionDetected": False,
                "truncationDetected": False,
            }
            self._write_jsonl(run_dir / packager.RAW_PROPOSALS, raw)
            self._write_jsonl(run_dir / packager.NORMALIZED_PROPOSALS, normalized)

            package = packager.build_package(run_dir)
            result = json.loads(package[packager.EVALUATOR_RESULT])
            first = result["case_results"][0]
            self.assertFalse(first["schema_valid"])
            self.assertTrue(first["invented_tool"])

    def test_rejects_metadata_identity_drift_before_writes(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            run_dir = self._make_run(Path(temp) / "run")
            metadata = self._read_json(run_dir / packager.RUN_METADATA)
            metadata["system_model_identifier"] = "SystemLanguageModel.default|different"
            self._write_json(run_dir / packager.RUN_METADATA, metadata)

            with self.assertRaises(ValidationError):
                packager.package_run(run_dir)
            self._assert_no_outputs(run_dir)

    def test_rejects_profile_generation_config_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            run_dir = self._make_run(Path(temp) / "run")
            metadata = self._read_json(run_dir / packager.RUN_METADATA)
            metadata["profile"] = "Router-normal"
            self._write_json(run_dir / packager.RUN_METADATA, metadata)

            with self.assertRaises(ValidationError):
                packager.build_package(run_dir)

    def test_rejects_token_sum_and_budget_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            sum_run = self._make_run(root / "sum")
            token_counts = self._read_json(sum_run / packager.TOKEN_COUNTS)
            token_counts[0]["model_visible_input_token_count"] += 1
            self._write_json(sum_run / packager.TOKEN_COUNTS, token_counts)
            with self.assertRaises(ValidationError):
                packager.build_package(sum_run)

            budget_run = self._make_run(root / "budget")
            token_counts = self._read_json(budget_run / packager.TOKEN_COUNTS)
            raw = self._read_jsonl(budget_run / packager.RAW_PROPOSALS)
            token_counts[0]["prompt_token_count"] = 400
            total = (
                token_counts[0]["instructions_token_count"]
                + token_counts[0]["schema_token_count"]
                + token_counts[0]["prompt_token_count"]
            )
            token_counts[0]["model_visible_input_token_count"] = total
            raw[0]["model_visible_input_token_count"] = total
            self._write_json(budget_run / packager.TOKEN_COUNTS, token_counts)
            self._write_jsonl(budget_run / packager.RAW_PROPOSALS, raw)
            with self.assertRaises(ValidationError):
                packager.build_package(budget_run)

    def test_rejects_raw_normalized_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            run_dir = self._make_run(Path(temp) / "run")
            normalized = self._read_jsonl(run_dir / packager.NORMALIZED_PROPOSALS)
            normalized[0]["reasonCode"] = "unclear_intent"
            self._write_jsonl(run_dir / packager.NORMALIZED_PROPOSALS, normalized)

            with self.assertRaises(ValidationError):
                packager.build_package(run_dir)

    def test_rejects_missing_or_noncanonical_observation_flags(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            missing_run = self._make_run(root / "missing")
            normalized = self._read_jsonl(missing_run / packager.NORMALIZED_PROPOSALS)
            del normalized[0]["truncationDetected"]
            self._write_jsonl(missing_run / packager.NORMALIZED_PROPOSALS, normalized)
            with self.assertRaises(ValidationError):
                packager.build_package(missing_run)

            true_run = self._make_run(root / "true")
            normalized = self._read_jsonl(true_run / packager.NORMALIZED_PROPOSALS)
            normalized[0]["repetitionDetected"] = True
            self._write_jsonl(true_run / packager.NORMALIZED_PROPOSALS, normalized)
            with self.assertRaises(ValidationError):
                packager.build_package(true_run)

    def test_rejects_symlinked_required_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            run_dir = self._make_run(root / "run")
            token_path = run_dir / packager.TOKEN_COUNTS
            backup = root / "token-counts-backup.json"
            backup.write_bytes(token_path.read_bytes())
            token_path.unlink()
            token_path.symlink_to(backup)

            with self.assertRaises(ValidationError):
                packager.build_package(run_dir)

    def test_rejects_existing_and_dangling_symlink_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            existing_run = self._make_run(root / "existing")
            (existing_run / packager.NORMALIZED_INPUT).write_text("existing\n")
            with self.assertRaises(ValidationError):
                packager.package_run(existing_run)

            dangling_run = self._make_run(root / "dangling")
            (dangling_run / packager.EVALUATOR_RESULT).symlink_to(root / "missing-target")
            with self.assertRaises(ValidationError):
                packager.package_run(dangling_run)

    def test_write_failure_removes_only_outputs_created_by_attempt(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            run_dir = self._make_run(Path(temp) / "run")
            synthetic_package = {
                packager.NORMALIZED_INPUT: b"input\n",
                packager.EVALUATOR_RESULT: b"{}\n",
                packager.BASELINE_MANIFEST: b"{}\n",
            }
            original_open = Path.open
            writes = {"count": 0}

            def flaky_open(path: Path, mode: str = "r", *args, **kwargs):
                if mode == "xb":
                    writes["count"] += 1
                    if writes["count"] == 2:
                        raise OSError("synthetic write failure")
                return original_open(path, mode, *args, **kwargs)

            with patch.object(packager, "build_package", return_value=synthetic_package):
                with patch.object(Path, "open", new=flaky_open):
                    with self.assertRaises(ValidationError):
                        packager.package_run(run_dir)

            self._assert_no_outputs(run_dir)
            for name in packager.INPUT_FILENAMES:
                self.assertTrue((run_dir / name).is_file())

    def test_rejects_unexpected_directory_entry(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            run_dir = self._make_run(Path(temp) / "run")
            (run_dir / ".DS_Store").write_bytes(b"synthetic")
            with self.assertRaises(ValidationError):
                packager.build_package(run_dir)

    def _make_run(self, run_dir: Path, profile: str = "Router-small") -> Path:
        run_dir.mkdir(parents=True)
        benchmark = packager.validate_benchmark(packager.DEFAULT_BENCHMARK)
        raw_records = []
        normalized_records = []
        token_records = []

        for index, record in enumerate(benchmark):
            prompt_tokens = 20 + (index % 7)
            total = 100 + 80 + prompt_tokens
            raw_records.append(
                {
                    "case_id": record["case_id"],
                    "proposal": {
                        "proposalType": "no_tool",
                        "intent": "unknown",
                        "arguments": {},
                        "missingArguments": [],
                        "reasonCode": "no_matching_local_tool",
                    },
                    "model_visible_input_token_count": total,
                }
            )
            normalized_records.append(
                {
                    "case_id": record["case_id"],
                    "proposalType": "no_tool",
                    "intent": "unknown",
                    "tool": None,
                    "arguments": {},
                    "missingArguments": [],
                    "reasonCode": "no_matching_local_tool",
                    "repetitionDetected": False,
                    "truncationDetected": False,
                }
            )
            token_records.append(
                {
                    "case_id": record["case_id"],
                    "instructions_token_count": 100,
                    "schema_token_count": 80,
                    "prompt_token_count": prompt_tokens,
                    "model_visible_input_token_count": total,
                }
            )

        os_string = "Version 26.5.2 (Build 25F84)"
        metadata = {
            "backend_class": "apple_system",
            "framework": "Apple Foundation Models",
            "profile": profile,
            "benchmark_case_count": len(benchmark),
            "system_model_identifier": f"SystemLanguageModel.default|{os_string}",
            "context_limit_tokens": 4_096,
            "os": os_string,
            "architecture": "arm64",
            "swift_toolchain": (
                "Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)\n"
                "Target: arm64-apple-macosx26.0"
            ),
            "minimum_evidence_os": "26.4",
            "token_evidence_method": "SystemLanguageModel.tokenCount(for:)",
            "instructions_id": packager.RUNNER_INSTRUCTIONS_ID,
            "instructions_text": packager.RUNNER_INSTRUCTIONS,
            "evidence_class": "host",
            "physical_device_run": False,
            "physical_device_readiness_claimed": False,
        }
        generation_config = {
            "sampling_mode": "greedy",
            "sampling_enabled": False,
            "temperature": 0.0,
            "top_p": 1.0,
            "top_k": None,
            "maximum_response_tokens": packager.PROFILES[profile]["output_limit_tokens"],
            "seed_supported": False,
            "seed": None,
            "include_schema_in_prompt": True,
            "tools_count": 0,
        }

        self._write_jsonl(run_dir / packager.RAW_PROPOSALS, raw_records)
        self._write_jsonl(run_dir / packager.NORMALIZED_PROPOSALS, normalized_records)
        self._write_json(run_dir / packager.TOKEN_COUNTS, token_records)
        self._write_json(run_dir / packager.APPLIED_GENERATION_CONFIG, generation_config)
        self._write_json(run_dir / packager.RUN_METADATA, metadata)
        return run_dir

    @staticmethod
    def _write_json(path: Path, value) -> None:
        path.write_text(
            json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

    @staticmethod
    def _write_jsonl(path: Path, records: list[dict]) -> None:
        path.write_text(
            "".join(
                json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n"
                for record in records
            ),
            encoding="utf-8",
        )

    @staticmethod
    def _read_json(path: Path):
        return json.loads(path.read_text(encoding="utf-8"))

    @staticmethod
    def _read_jsonl(path: Path) -> list[dict]:
        return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]

    def _assert_no_outputs(self, run_dir: Path) -> None:
        for name in packager.OUTPUT_FILENAMES:
            self.assertFalse((run_dir / name).exists())
            self.assertFalse((run_dir / name).is_symlink())


if __name__ == "__main__":
    unittest.main()
