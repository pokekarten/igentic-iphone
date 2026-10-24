"""No-device tests for the opt-in ARTEMIS iOS host integration."""
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts/igentic_artemis_ios.py"
SPEC = importlib.util.spec_from_file_location("igentic_artemis_ios", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ArtemisIosIntegrationTests(unittest.TestCase):
    def test_upstream_is_pinned_to_full_sha(self):
        self.assertEqual(40, len(MODULE.UPSTREAM_SHA))
        self.assertEqual("https://github.com/google/artemis/pull/175", MODULE.UPSTREAM_PR)

    def test_plan_keeps_ios_platform_and_synthetic_task(self):
        args = SimpleNamespace(device="booted", profile="flash",
                               physical=False, app_path=None)
        command = MODULE.build_command(args)
        self.assertEqual(command[:4], ["uv", "run", "artemis", "run"])
        self.assertEqual(command[command.index("--platform") + 1], "ios")
        self.assertIn("org.example.iGenticDiagnostics", command[4])
        self.assertIn("--standalone", command)
        self.assertNotIn("http", command[4])

    def test_physical_requires_explicit_udid(self):
        args = SimpleNamespace(device="booted", profile="flash",
                               physical=True, app_path=None)
        with self.assertRaisesRegex(ValueError, "explicit UDID"):
            MODULE.build_command(args)

    def test_profile_pro_is_forwarded(self):
        args = SimpleNamespace(device="1234", profile="pro",
                               physical=True, app_path="/tmp/demo.app")
        command = MODULE.build_command(args)
        self.assertEqual(command[command.index("--profile") + 1], "pro")
        self.assertEqual(command[command.index("--app-path") + 1], "/tmp/demo.app")

    def test_no_execution_in_plan_mode(self):
        with patch.object(MODULE.subprocess, "run") as run:
            with redirect_stdout(io.StringIO()) as out:
                self.assertEqual(0, MODULE.main(["plan"]))
            body = json.loads(out.getvalue())
            self.assertEqual("ios", body["argv"][body["argv"].index("--platform") + 1])
            run.assert_not_called()

    def test_run_requires_both_explicit_acknowledgments(self):
        with patch.object(MODULE.subprocess, "run") as run:
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                self.assertEqual(2, MODULE.main(["run", "--execute"]))
            run.assert_not_called()

    def test_run_refuses_unpinned_checkout(self):
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(MODULE.subprocess, "run") as run:
                with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                    code = MODULE.main([
                        "--checkout", temporary, "run", "--execute",
                        "--acknowledge-model-io",
                    ])
                self.assertEqual(2, code)
                run.assert_not_called()

    def test_fetch_refuses_existing_drifting_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(MODULE.subprocess, "run") as run:
                with self.assertRaisesRegex(ValueError, "already exists"):
                    MODULE.fetch(Path(temporary))
                run.assert_not_called()

    def test_mcp_config_does_not_write_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary)
            with patch.object(MODULE, "require_pinned") as check:
                config = MODULE.mcp_config(target)
            check.assert_called_once_with(target)
            self.assertIn("[mcp_servers.artemis_ios]", config)
            self.assertIn("mcp_server", config)
            self.assertIn("PYTHONPATH", config)

    def test_doctor_reports_missing_local_prereqs(self):
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(MODULE.platform, "system", return_value="Linux"):
                result = MODULE.doctor(Path(temporary))
            self.assertFalse(result["xcode_27_or_newer"])
            self.assertFalse(result["source_pinned"])
            self.assertEqual(MODULE.UPSTREAM_SHA, result["upstream_sha"])


if __name__ == "__main__":
    unittest.main()
