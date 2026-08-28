#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import qwen3_baseline_adapter as adapter
import qwen3_baseline_packager as packager
import qwen3_host_runner as runner
from validate_action_benchmark import DEFAULT_BENCHMARK, ValidationError, validate_benchmark
from validate_baseline_run import load_manifest, validate_manifest


def _write_json(path: Path, value) -> None:
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True, allow_nan=False)
        + "\n",
        encoding="utf-8",
    )


def _write_jsonl(path: Path, values: list[dict[str, object]]) -> None:
    path.write_text(
        "".join(
            json.dumps(value, ensure_ascii=False, sort_keys=True, allow_nan=False)
            + "\n"
            for value in values
        ),
        encoding="utf-8",
    )


def _assistant_text(record: dict[str, object]) -> str:
    proposal = {
        "proposalType": record["expected_proposal_type"],
        "intent": record["expected_intent"],
        "tool": record["expected_tool"],
        "arguments": record["expected_arguments"],
        "missingArguments": record["expected_missing_arguments"],
        "reasonCode": record["expected_reason_code"],
    }
    transport = {
        "name": adapter.TOOL_NAME,
        "arguments": proposal,
    }
    return (
        adapter.TOOL_CALL_OPEN
        + json.dumps(transport, ensure_ascii=False, sort_keys=True)
        + adapter.TOOL_CALL_CLOSE
    )


class Qwen3BaselinePackagerTests(unittest.TestCase):
    def make_run(
        self,
        root: Path,
        *,
        profile: str = "Router-small",
        seed: int = 0,
        metadata_overrides: dict[str, object] | None = None,
    ) -> Path:
        records = validate_benchmark(DEFAULT_BENCHMARK)
        run_dir = root / profile / f"seed-{seed}"
        run_dir.mkdir(parents=True)

        _write_jsonl(
            run_dir / packager.RAW_OUTPUTS,
            [
                {
                    "case_id": record["case_id"],
                    "assistant_text": _assistant_text(record),
                }
                for record in records
            ],
        )
        _write_json(
            run_dir / packager.TOKEN_COUNTS,
            {record["case_id"]: 128 for record in records},
        )
        generation = dict(adapter.NON_THINKING_GENERATION_KWARGS)
        generation["max_new_tokens"] = runner.PROFILES[profile]["max_new_tokens"]
        generation["eos_token_id"] = [151645, 151643]
        _write_json(run_dir / packager.APPLIED_GENERATION_CONFIG, generation)

        metadata: dict[str, object] = {
            "model_id": adapter.MODEL_ID,
            "model_revision": adapter.MODEL_REVISION,
            "profile": profile,
            "seed": seed,
            "case_count": len(records),
            "device": "cpu",
            "model_dtype": "torch.float32",
            "transformers_version": "4.51.0",
            "torch_version": "2.8.0",
            "evidence_class": "host",
            "physical_device_run": False,
            "os": "SyntheticOS 1",
            "architecture": "arm64",
            "python_version": "3.12.0",
            "prompt_template_id": runner.PROMPT_TEMPLATE_ID,
            "prompt_template_sha256": "a" * 64,
        }
        if metadata_overrides:
            metadata.update(metadata_overrides)
        _write_json(run_dir / packager.RUN_METADATA, metadata)
        return run_dir

    def test_synthetic_run_packages_to_valid_byte_stable_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            first = self.make_run(root / "one")
            second = self.make_run(root / "two")

            first_package = packager.build_package(first)
            second_package = packager.build_package(second)
            self.assertEqual(first_package, second_package)

            packager.package_run(first)
            manifest_path = first / packager.BASELINE_MANIFEST
            manifest = load_manifest(manifest_path)
            self.assertEqual(validate_manifest(manifest), [])
            self.assertEqual(manifest["backend"]["model_id"], adapter.MODEL_ID)
            self.assertEqual(manifest["backend"]["model_revision"], adapter.MODEL_REVISION)
            self.assertEqual(manifest["profile"]["name"], "Router-small")
            self.assertEqual(manifest["decoding"]["seed"], 0)
            self.assertEqual(manifest["execution"]["evidence_class"], "host")
            self.assertFalse(manifest["claims"]["physical_device_readiness_claimed"])
            self.assertEqual(manifest["next_decision"], "unverified")

            for name in packager.OUTPUT_FILENAMES:
                self.assertTrue((first / name).is_file())

            normalized_input = (first / packager.NORMALIZED_INPUT).read_bytes()
            self.assertEqual(
                manifest["input"]["normalized_input_sha256"],
                hashlib.sha256(normalized_input).hexdigest(),
            )
            normalized = (first / packager.NORMALIZED_PROPOSALS).read_bytes()
            self.assertEqual(
                manifest["artifacts"]["normalized_proposals_sha256"],
                hashlib.sha256(normalized).hexdigest(),
            )
            result = (first / packager.EVALUATOR_RESULT).read_bytes()
            self.assertEqual(
                manifest["artifacts"]["evaluator_result_sha256"],
                hashlib.sha256(result).hexdigest(),
            )

    def test_wrong_identity_and_physical_claims_fail_closed(self) -> None:
        mutations = (
            {"model_id": "other/model"},
            {"model_revision": "0" * 40},
            {"profile": "Router-normal"},
            {"seed": 4},
            {"case_count": 39},
            {"evidence_class": "physical_device"},
            {"physical_device_run": True},
            {"prompt_template_id": "other-template"},
            {"prompt_template_sha256": "not-a-hash"},
        )
        for mutation in mutations:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temp:
                run_dir = self.make_run(
                    Path(temp),
                    metadata_overrides=mutation,
                )
                with self.assertRaises(ValidationError):
                    packager.build_package(run_dir)

    def test_generation_profile_mismatch_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            run_dir = self.make_run(Path(temp))
            config_path = run_dir / packager.APPLIED_GENERATION_CONFIG
            config = json.loads(config_path.read_text(encoding="utf-8"))
            config["max_new_tokens"] = 64
            _write_json(config_path, config)
            with self.assertRaises(ValidationError):
                packager.build_package(run_dir)

    def test_token_count_identity_and_limit_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            run_dir = self.make_run(Path(temp))
            token_path = run_dir / packager.TOKEN_COUNTS
            counts = json.loads(token_path.read_text(encoding="utf-8"))
            first_case = next(iter(counts))
            counts[first_case] = 513
            _write_json(token_path, counts)
            with self.assertRaises(ValidationError):
                packager.build_package(run_dir)

    def test_existing_output_causes_prewrite_failure_without_partial_package(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            run_dir = self.make_run(Path(temp))
            existing = run_dir / packager.NORMALIZED_PROPOSALS
            existing.write_text("preexisting\n", encoding="utf-8")

            with self.assertRaises(ValidationError):
                packager.package_run(run_dir)

            self.assertEqual(existing.read_text(encoding="utf-8"), "preexisting\n")
            for name in packager.OUTPUT_FILENAMES:
                if name != packager.NORMALIZED_PROPOSALS:
                    self.assertFalse((run_dir / name).exists())

    def test_symlinked_input_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            run_dir = self.make_run(root)
            raw = run_dir / packager.RAW_OUTPUTS
            real = run_dir / "raw-real.jsonl"
            raw.rename(real)
            try:
                raw.symlink_to(real.name)
            except OSError:
                self.skipTest("symlinks are unavailable in this environment")

            with self.assertRaises(ValidationError):
                packager.build_package(run_dir)


if __name__ == "__main__":
    unittest.main()
