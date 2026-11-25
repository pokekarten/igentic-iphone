import json
import unittest
from unittest.mock import patch
from contextlib import redirect_stdout
from io import StringIO

import mlx_qwen_local_tool_probe as probe


def envelope(arguments, name="igentic_propose_action"):
    return "<tool_call>" + json.dumps({"name": name, "arguments": arguments}) + "</tool_call>"


class NativeToolProbeTests(unittest.TestCase):
    def test_exact_preview(self):
        self.assertEqual(probe.classify_native_output(
            envelope({"action": "diagnostics.read", "approved": False}), 30),
            "synthetic_preview_only")

    def test_no_semantic_repair(self):
        good = envelope({"action": "diagnostics.read", "approved": False})
        for raw in (good[len("<tool_call>"):-len("</tool_call>")],
                    "reasoning " + good, good + " more", good + good,
                    "```json\n" + good + "\n```"):
            self.assertEqual(probe.classify_native_output(raw, 30),
                             "invalid_native_envelope")

    def test_duplicate_keys(self):
        raw = '<tool_call>{"name":"igentic_propose_action","arguments":{"action":"diagnostics.read","approved":false,"approved":false}}</tool_call>'
        self.assertEqual(probe.classify_native_output(raw, 30), "invalid_native_envelope")

    def test_wrong_tool(self):
        self.assertEqual(probe.classify_native_output(
            envelope({"action": "diagnostics.read", "approved": False}, "other"), 30),
            "invalid_native_envelope")

    def test_wrong_action_or_approval(self):
        for args in ({"action": "reminder.create", "approved": False},
                     {"action": "diagnostics.read", "approved": True},
                     {"action": "diagnostics.read", "approved": 0}):
            self.assertEqual(probe.classify_native_output(envelope(args), 30),
                             "action_or_approval_not_permitted")

    def test_extra_fields(self):
        self.assertEqual(probe.classify_native_output(
            envelope({"action": "diagnostics.read", "approved": False, "extra": 1}), 30),
            "invalid_schema")

    def test_generation_cap(self):
        good = envelope({"action": "diagnostics.read", "approved": False})
        for tokens in (64, 65, -1, True):
            self.assertEqual(probe.classify_native_output(good, tokens),
                             "invalid_or_capped_generation")

    def test_opt_in_default(self):
        with patch("sys.argv", ["probe"]), patch.object(probe, "run_smoke") as run:
            with redirect_stdout(StringIO()) as out:
                self.assertEqual(probe.main(), 0)
            run.assert_not_called()
            self.assertEqual(json.loads(out.getvalue())["status"], "skipped_opt_in_required")

    def test_rejected_run_fails(self):
        with patch("sys.argv", ["probe", "--run"]), patch.object(
                probe, "run_smoke", return_value={"status": "output_rejected"}):
            with redirect_stdout(StringIO()):
                self.assertEqual(probe.main(), 1)


if __name__ == "__main__":
    unittest.main()
