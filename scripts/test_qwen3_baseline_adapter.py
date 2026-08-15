#!/usr/bin/env python3
"""Regression tests for the dependency-free Qwen3 Benchmark V0 adapter."""
from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

import qwen3_baseline_adapter as adapter
from validate_action_benchmark import ValidationError


BASE_RECORD = {
    "case_id": "de-create-reminder-001",
    "language": "de",
    "user_text": "Erinnere mich morgen um neun an einen Termin.",
    "expected_proposal_type": "tool_call",
    "expected_intent": "createReminder",
    "expected_tool": "createReminder",
    "expected_arguments": {"title": "Termin", "time": "tomorrow 09:00"},
    "required_arguments": ["title", "time"],
    "expected_missing_arguments": [],
    "expected_reason_code": "direct_intent",
    "category": "clear",
    "immutable_test": True,
}

VALID_PROPOSAL = {
    "proposalType": "tool_call",
    "intent": "createReminder",
    "tool": "createReminder",
    "arguments": {"title": "Termin", "time": "tomorrow 09:00"},
    "missingArguments": [],
    "reasonCode": "direct_intent",
}


def native_tool_call(arguments: object, name: str = adapter.TOOL_NAME) -> str:
    payload = {"name": name, "arguments": arguments}
    return (
        f"{adapter.TOOL_CALL_OPEN}\n"
        f"{json.dumps(payload, ensure_ascii=False)}\n"
        f"{adapter.TOOL_CALL_CLOSE}"
    )


class RequestEnvelopeTests(unittest.TestCase):
    def test_request_pins_revision_and_non_thinking_mode(self) -> None:
        request = adapter.build_request(BASE_RECORD)

        self.assertEqual(request["model_id"], "Qwen/Qwen3-0.6B")
        self.assertEqual(
            request["model_revision"],
            "c1899de289a04d12100db370d81485cdf75e47ca",
        )
        self.assertEqual(request["tokenizer_revision"], request["model_revision"])
        self.assertEqual(
            request["chat_template_kwargs"],
            {"add_generation_prompt": True, "enable_thinking": False},
        )

    def test_request_exposes_user_text_without_benchmark_answers(self) -> None:
        request = adapter.build_request(BASE_RECORD)
        encoded = json.dumps(request, ensure_ascii=False)

        self.assertEqual(request["messages"][-1]["content"], BASE_RECORD["user_text"])
        for forbidden in (
            "expected_proposal_type",
            "expected_intent",
            "expected_tool",
            "expected_arguments",
            "required_arguments",
            "expected_missing_arguments",
            "expected_reason_code",
            '"category"',
            "immutable_test",
        ):
            self.assertNotIn(forbidden, encoded)

    def test_tool_schema_is_proposal_only(self) -> None:
        function = adapter.TOOL_SCHEMA["function"]
        parameters = function["parameters"]

        self.assertEqual(function["name"], adapter.TOOL_NAME)
        self.assertEqual(set(parameters["properties"]), set(adapter.PROPOSAL_FIELDS))
        self.assertEqual(set(parameters["required"]), set(adapter.PROPOSAL_FIELDS))
        self.assertFalse(parameters["additionalProperties"])
        self.assertNotIn("policy", parameters["properties"])
        self.assertNotIn("approved", parameters["properties"])
        self.assertNotIn("execute", parameters["properties"])


class OutputNormalizationTests(unittest.TestCase):
    def test_valid_native_tool_call_normalizes_without_semantic_repair(self) -> None:
        result = adapter.normalize_record(
            {
                "case_id": BASE_RECORD["case_id"],
                "assistant_text": f" \n{native_tool_call(VALID_PROPOSAL)}\n ",
                "repetitionDetected": False,
                "truncationDetected": False,
            }
        )

        self.assertEqual(result["case_id"], BASE_RECORD["case_id"])
        for key, value in VALID_PROPOSAL.items():
            self.assertEqual(result[key], value)
        self.assertFalse(result["repetitionDetected"])
        self.assertFalse(result["truncationDetected"])
        self.assertNotIn("normalizerError", result)

    def test_semantic_schema_errors_are_not_repaired(self) -> None:
        malformed_semantics = dict(VALID_PROPOSAL)
        malformed_semantics["unexpectedSemanticField"] = True

        result = adapter.normalize_record(
            {
                "case_id": BASE_RECORD["case_id"],
                "assistant_text": native_tool_call(malformed_semantics),
            }
        )

        self.assertTrue(result["unexpectedSemanticField"])
        self.assertNotIn("normalizerError", result)

    def test_malformed_backend_text_becomes_joinable_failure(self) -> None:
        malformed_texts = [
            "plain prose",
            f"```json\n{native_tool_call(VALID_PROPOSAL)}\n```",
            "<tool_call>{bad json}</tool_call>",
            native_tool_call(VALID_PROPOSAL) + native_tool_call(VALID_PROPOSAL),
            "<tool_call><tool_call>{}</tool_call></tool_call>",
            native_tool_call(VALID_PROPOSAL) + " trailing prose",
        ]

        for assistant_text in malformed_texts:
            with self.subTest(assistant_text=assistant_text):
                result = adapter.normalize_record(
                    {
                        "case_id": BASE_RECORD["case_id"],
                        "assistant_text": assistant_text,
                    }
                )
                self.assertEqual(result["case_id"], BASE_RECORD["case_id"])
                self.assertIn("normalizerError", result)
                self.assertNotIn("proposalType", result)

    def test_wrong_name_and_non_object_arguments_become_failures(self) -> None:
        cases = [
            native_tool_call(VALID_PROPOSAL, name="createReminder"),
            native_tool_call(["not", "an", "object"]),
        ]
        for assistant_text in cases:
            with self.subTest(assistant_text=assistant_text):
                result = adapter.normalize_record(
                    {
                        "case_id": BASE_RECORD["case_id"],
                        "assistant_text": assistant_text,
                    }
                )
                self.assertIn("normalizerError", result)

    def test_model_cannot_control_identity_or_runtime_observations(self) -> None:
        for reserved in adapter.RESERVED_MODEL_FIELDS:
            with self.subTest(reserved=reserved):
                proposal = dict(VALID_PROPOSAL)
                proposal[reserved] = True
                result = adapter.normalize_record(
                    {
                        "case_id": BASE_RECORD["case_id"],
                        "assistant_text": native_tool_call(proposal),
                    }
                )
                self.assertEqual(
                    result["normalizerError"], "model_controls_reserved_field"
                )

    def test_runtime_observations_survive_joinable_failure(self) -> None:
        result = adapter.normalize_record(
            {
                "case_id": BASE_RECORD["case_id"],
                "assistant_text": "not a tool call",
                "repetitionDetected": True,
                "truncationDetected": True,
            }
        )

        self.assertTrue(result["repetitionDetected"])
        self.assertTrue(result["truncationDetected"])
        self.assertIn("normalizerError", result)

    def test_unexpected_transport_fields_fail_without_being_copied(self) -> None:
        result = adapter.normalize_record(
            {
                "case_id": BASE_RECORD["case_id"],
                "assistant_text": native_tool_call(VALID_PROPOSAL),
                "provider_debug": "must not enter evaluator artifacts",
            }
        )

        self.assertEqual(result["normalizerError"], "unexpected_transport_fields")
        self.assertNotIn("provider_debug", result)


class TransportIdentityTests(unittest.TestCase):
    def write_records(self, records: list[dict[str, object]]) -> Path:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / "raw.jsonl"
        path.write_text(
            "".join(json.dumps(record) + "\n" for record in records),
            encoding="utf-8",
        )
        return path

    def test_missing_invalid_or_duplicate_case_id_fails_closed(self) -> None:
        cases = [
            [{"assistant_text": "x"}],
            [{"case_id": "", "assistant_text": "x"}],
            [
                {"case_id": "same", "assistant_text": "x"},
                {"case_id": "same", "assistant_text": "y"},
            ],
        ]

        for records in cases:
            with self.subTest(records=records):
                path = self.write_records(records)
                loaded = adapter.load_jsonl(path)
                with self.assertRaises(ValidationError):
                    adapter._validate_transport_identity(loaded, path)


if __name__ == "__main__":
    unittest.main()
