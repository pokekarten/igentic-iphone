#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import qwen3_baseline_adapter as adapter
import qwen3_host_runner as runner
from validate_action_benchmark import ValidationError


class FakeIds:
    def __init__(self, count: int) -> None:
        self.shape = (1, count)


class FakeTokenizer:
    def __init__(
        self,
        count: int,
        chat_template: str | dict[str, str] | None = "synthetic-template",
    ) -> None:
        self.count = count
        self.chat_template = chat_template
        self.calls: list[dict[str, object]] = []
        self.template_calls: list[object] = []

    def get_chat_template(self, *, tools=None):
        self.template_calls.append(tools)
        if isinstance(self.chat_template, str):
            if not self.chat_template:
                raise ValueError("empty")
            return self.chat_template
        if isinstance(self.chat_template, dict):
            if tools and "tool_use" in self.chat_template:
                return self.chat_template["tool_use"]
            if "default" in self.chat_template:
                return self.chat_template["default"]
            raise ValueError("no matching template")
        raise ValueError("missing template")

    def apply_chat_template(self, messages, **kwargs):
        self.calls.append({"messages": messages, **kwargs})
        return {"input_ids": FakeIds(self.count)}


class FakeModelConfig:
    def __init__(self, max_position_embeddings) -> None:
        self.max_position_embeddings = max_position_embeddings


class FakeModel:
    def __init__(self, max_position_embeddings) -> None:
        self.config = FakeModelConfig(max_position_embeddings)


class Qwen3HostRunnerTests(unittest.TestCase):
    def test_snapshot_must_be_exact_pinned_revision(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            exact = root / adapter.MODEL_REVISION
            exact.mkdir()
            self.assertEqual(runner.validate_snapshot_dir(exact), exact.resolve())

            wrong = root / "main"
            wrong.mkdir()
            with self.assertRaises(ValidationError):
                runner.validate_snapshot_dir(wrong)

    def test_runtime_load_options_are_offline_safe_and_dtype_pinned(self) -> None:
        tokenizer_options, model_options = runner.runtime_load_options()
        self.assertEqual(
            tokenizer_options,
            {"local_files_only": True, "trust_remote_code": False},
        )
        self.assertEqual(
            model_options,
            {
                "local_files_only": True,
                "trust_remote_code": False,
                "torch_dtype": "auto",
            },
        )

    def test_host_environment_provenance_is_non_empty(self) -> None:
        environment = runner.host_environment()
        self.assertEqual(set(environment), {"os", "architecture", "python_version"})
        self.assertTrue(all(isinstance(value, str) and value for value in environment.values()))

    def test_prompt_template_hash_binds_exact_selected_tool_template(self) -> None:
        tools = [{"type": "function"}]
        tokenizer = FakeTokenizer(128, chat_template="template-v0")
        self.assertEqual(
            runner.tokenizer_chat_template_sha256(tokenizer, tools),
            hashlib.sha256(b"template-v0").hexdigest(),
        )
        self.assertEqual(tokenizer.template_calls, [tools])
        self.assertEqual(runner.PROMPT_TEMPLATE_ID, "qwen3-tokenizer-chat-template")

    def test_prompt_template_mapping_hashes_selected_tool_use_template_only(self) -> None:
        tools = [{"type": "function"}]
        tokenizer = FakeTokenizer(
            128,
            chat_template={
                "default": "default-template",
                "tool_use": "tool-template",
            },
        )
        self.assertEqual(
            runner.tokenizer_chat_template_sha256(tokenizer, tools),
            hashlib.sha256(b"tool-template").hexdigest(),
        )
        self.assertNotEqual(
            runner.tokenizer_chat_template_sha256(
                FakeTokenizer(128, chat_template="default-template"),
                tools,
            ),
            hashlib.sha256(b"tool-template").hexdigest(),
        )

    def test_missing_or_unresolvable_prompt_template_fails_closed(self) -> None:
        tools = [{"type": "function"}]
        for template in (None, "", {}):
            with self.subTest(template=template):
                with self.assertRaises(ValidationError):
                    runner.tokenizer_chat_template_sha256(
                        FakeTokenizer(128, chat_template=template),
                        tools,
                    )

        class NoGetter:
            pass

        with self.assertRaises(ValidationError):
            runner.tokenizer_chat_template_sha256(NoGetter(), tools)

    def test_model_context_limit_is_explicit_and_fail_closed(self) -> None:
        self.assertEqual(runner.model_context_limit(FakeModel(32768)), 32768)
        for value in (None, 0, -1, True, "32768"):
            with self.subTest(value=value):
                with self.assertRaises(ValidationError):
                    runner.model_context_limit(FakeModel(value))

    def test_profile_limits_are_canonical(self) -> None:
        self.assertEqual(
            runner.profile_config("Router-small"),
            {"input_limit_tokens": 512, "max_new_tokens": 32},
        )
        self.assertEqual(
            runner.profile_config("Router-normal"),
            {"input_limit_tokens": 1024, "max_new_tokens": 64},
        )
        with self.assertRaises(ValidationError):
            runner.profile_config("assistant")

    def test_output_plan_rejects_any_existing_seed_before_creating_new_dirs(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            existing = root / "Router-small" / "seed-3"
            existing.mkdir(parents=True)

            with self.assertRaises(ValidationError):
                runner.plan_run_dirs(root, "Router-small")

            for seed in adapter.BASELINE_SEEDS:
                path = root / "Router-small" / f"seed-{seed}"
                if seed == 3:
                    self.assertTrue(path.is_dir())
                else:
                    self.assertFalse(path.exists())

    def test_output_plan_uses_exact_precommitted_seed_set(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            planned = runner.plan_run_dirs(root, "Router-normal")
            self.assertEqual(tuple(planned), adapter.BASELINE_SEEDS)
            self.assertTrue(all(not path.exists() for path in planned.values()))

    def test_generation_config_reuses_adapter_and_only_adds_output_cap(self) -> None:
        config = runner.applied_generation_config("Router-small")
        expected = dict(adapter.NON_THINKING_GENERATION_KWARGS)
        expected["max_new_tokens"] = 32
        self.assertEqual(config, expected)
        self.assertEqual(runner.BASELINE_SEEDS, (0, 1, 2, 3, 4))

    def test_effective_generation_config_binds_inherited_defaults_and_overrides(self) -> None:
        upstream = {
            "temperature": 0.6,
            "top_p": 0.95,
            "top_k": 20,
            "eos_token_id": [151645, 151643],
            "max_length": 20,
        }
        effective = runner.effective_generation_config(upstream, "Router-small")
        self.assertEqual(effective["temperature"], 0.7)
        self.assertEqual(effective["top_p"], 0.8)
        self.assertEqual(effective["top_k"], 20)
        self.assertEqual(effective["min_p"], 0.0)
        self.assertEqual(effective["max_new_tokens"], 32)
        self.assertEqual(effective["eos_token_id"], [151645, 151643])
        self.assertEqual(effective["max_length"], 20)
        self.assertEqual(upstream["temperature"], 0.6)
        with self.assertRaises(ValidationError):
            runner.effective_generation_config([], "Router-small")

    def test_output_observations_are_explicit_and_conservative(self) -> None:
        self.assertFalse(runner.generation_cap_reached([1] * 31, 32))
        self.assertTrue(runner.generation_cap_reached([1] * 32, 32))
        with self.assertRaises(ValidationError):
            runner.generation_cap_reached([1], 0)

        single = f"{adapter.TOOL_CALL_OPEN}{{}}{adapter.TOOL_CALL_CLOSE}"
        repeated = single + single
        self.assertFalse(runner.repeated_proposal_envelope_detected(single))
        self.assertTrue(runner.repeated_proposal_envelope_detected(repeated))
        with self.assertRaises(ValidationError):
            runner.repeated_proposal_envelope_detected(None)

    def test_preflight_uses_adapter_visible_inputs_and_transport_template_kwargs(self) -> None:
        tokenizer = FakeTokenizer(128)
        rendered, counts = runner.render_and_preflight(tokenizer, "Router-small")
        requests = runner.build_requests()

        self.assertEqual(len(rendered), len(requests))
        self.assertEqual(set(counts), {request["case_id"] for request in requests})
        first = tokenizer.calls[0]
        self.assertEqual(first["messages"], requests[0]["messages"])
        self.assertEqual(first["tools"], requests[0]["tools"])
        self.assertTrue(first["tokenize"])
        self.assertTrue(first["return_dict"])
        self.assertEqual(first["return_tensors"], "pt")
        self.assertEqual(first["add_generation_prompt"], True)
        self.assertEqual(first["enable_thinking"], False)
        self.assertNotIn("generation_kwargs", first)
        self.assertNotIn("replicate_seeds", first)

    def test_over_budget_input_fails_closed(self) -> None:
        with self.assertRaises(ValidationError):
            runner.render_and_preflight(FakeTokenizer(513), "Router-small")

    def test_transformers_version_parser_is_fail_closed(self) -> None:
        self.assertEqual(runner._version_tuple("4.51.0"), (4, 51, 0))
        self.assertEqual(runner._version_tuple("5.0.0.dev0"), (5, 0, 0))
        with self.assertRaises(ValidationError):
            runner._version_tuple("unknown")


if __name__ == "__main__":
    unittest.main()
