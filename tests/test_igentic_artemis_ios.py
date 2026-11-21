"""No-device tests for the opt-in ARTEMIS iOS host integration."""
import importlib.util
import io
import subprocess
import json
import plistlib
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import call, patch

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
        self.assertEqual(command[:7], [
            "uv", "run", "--frozen", "--no-sync", "--offline", "artemis", "run"
        ])
        self.assertEqual(command[command.index("--platform") + 1], "ios")
        self.assertIn("org.example.iGenticDiagnostics", command[7])
        self.assertIn("--standalone", command)
        self.assertNotIn("http", command[7])

    def test_run_preserves_no_implicit_dependency_setup(self):
        checks = {
            "xcode_27_or_newer": True,
            "uv_available": True,
            "ios_project_exists": True,
        }
        with patch.object(MODULE, "require_pinned"), \
             patch.object(MODULE, "require_simulator_target"), \
             patch.object(MODULE, "doctor", return_value=checks), \
             patch.object(MODULE, "run_bounded", return_value=0) as run:
            with redirect_stdout(io.StringIO()):
                result = MODULE.main(["run", "--execute", "--acknowledge-model-io"])
        self.assertEqual(result, 0)
        run.assert_called_once()
        argv = run.call_args.args[0]
        self.assertEqual(
            argv[:7],
            ["uv", "run", "--frozen", "--no-sync", "--offline", "artemis", "run"],
        )
        self.assertEqual(run.call_args.kwargs["cwd"], MODULE.DEFAULT_CHECKOUT.resolve())

    def test_bounded_runner_uses_new_process_session(self):
        with patch.object(MODULE.subprocess, "Popen") as popen:
            popen.return_value.wait.return_value = 0
            self.assertEqual(MODULE.run_bounded(["uv", "run"], Path("/tmp")), 0)
            popen.assert_called_once_with(
                ["uv", "run"], cwd=Path("/tmp"), start_new_session=True
            )
            popen.return_value.wait.assert_called_once_with(
                timeout=MODULE.MAX_RUN_SECONDS
            )

    def test_bounded_runner_timeout_terminates_group(self):
        timed_out = subprocess.TimeoutExpired("artemis", MODULE.MAX_RUN_SECONDS)
        with patch.object(MODULE.subprocess, "Popen") as popen, \
             patch.object(MODULE.os, "killpg") as kill_group:
            popen.return_value.pid = 12345
            popen.return_value.wait.side_effect = [timed_out, 0]
            with self.assertRaisesRegex(ValueError, "exceeded"):
                MODULE.run_bounded(["uv", "run"], Path("/tmp"))
            kill_group.assert_called_once_with(12345, MODULE.signal.SIGTERM)

    def test_bounded_runner_escalates_if_group_does_not_exit(self):
        timed_out = subprocess.TimeoutExpired("artemis", MODULE.MAX_RUN_SECONDS)
        with patch.object(MODULE.subprocess, "Popen") as popen, \
             patch.object(MODULE.os, "killpg") as kill_group:
            popen.return_value.pid = 12345
            popen.return_value.wait.side_effect = [timed_out, timed_out, 0]
            with self.assertRaisesRegex(ValueError, "exceeded"):
                MODULE.run_bounded(["uv", "run"], Path("/tmp"))
            self.assertEqual(kill_group.call_args_list, [
                call(12345, MODULE.signal.SIGTERM),
                call(12345, MODULE.signal.SIGKILL),
            ])

    def test_diagnostic_app_bundle_accepts_exact_identifier(self):
        with tempfile.TemporaryDirectory() as temp:
            bundle = Path(temp) / "iGenticDiagnostics.app"
            bundle.mkdir()
            with (bundle / "Info.plist").open("wb") as output:
                plistlib.dump({"CFBundleIdentifier": MODULE.DIAGNOSTIC_APP}, output)
            MODULE.require_diagnostic_app_bundle(str(bundle))

    def test_diagnostic_app_bundle_rejects_unrelated_identifier(self):
        with tempfile.TemporaryDirectory() as temp:
            bundle = Path(temp) / "Unrelated.app"
            bundle.mkdir()
            with (bundle / "Info.plist").open("wb") as output:
                plistlib.dump({"CFBundleIdentifier": "com.example.other"}, output)
            with self.assertRaisesRegex(ValueError, "not the iGentic"):
                MODULE.require_diagnostic_app_bundle(str(bundle))

    def test_diagnostic_app_bundle_rejects_invalid_or_missing_plist(self):
        with tempfile.TemporaryDirectory() as temp:
            bundle = Path(temp) / "iGenticDiagnostics.app"
            bundle.mkdir()
            with self.assertRaisesRegex(ValueError, "Cannot read"):
                MODULE.require_diagnostic_app_bundle(str(bundle))
            (bundle / "Info.plist").write_text("not a plist")
            with self.assertRaisesRegex(ValueError, "Cannot read"):
                MODULE.require_diagnostic_app_bundle(str(bundle))

    def test_run_fails_closed_before_execution_for_wrong_app(self):
        with tempfile.TemporaryDirectory() as temp:
            bundle = Path(temp) / "Wrong.app"
            bundle.mkdir()
            with (bundle / "Info.plist").open("wb") as output:
                plistlib.dump({"CFBundleIdentifier": "org.example.Other"}, output)
            with patch.object(MODULE, "require_pinned") as pinned, \
                 patch.object(MODULE, "run_bounded") as run:
                with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                    code = MODULE.main([
                        "run", "--execute", "--acknowledge-model-io",
                        "--app-path", str(bundle),
                    ])
            self.assertEqual(code, 2)
            pinned.assert_not_called()
            run.assert_not_called()

    def test_physical_requires_explicit_udid(self):
        args = SimpleNamespace(device="booted", profile="flash",
                               physical=True, app_path=None)
        with self.assertRaisesRegex(ValueError, "explicit UDID"):
            MODULE.build_command(args)

    def test_physical_requires_explicit_signed_bundle_path_and_id(self):
        args = SimpleNamespace(device="OWNED-DEVICE", profile="flash",
                               physical=True, app_path=None,
                               expected_bundle_id="com.example.owned.igentic")
        with self.assertRaisesRegex(ValueError, "--app-path"):
            MODULE.build_command(args)
        args.app_path = "/tmp/Diagnostics.app"
        args.expected_bundle_id = None
        with self.assertRaisesRegex(ValueError, "--expected-bundle-id"):
            MODULE.build_command(args)
        args.expected_bundle_id = MODULE.DIAGNOSTIC_APP
        with self.assertRaisesRegex(ValueError, "non-placeholder"):
            MODULE.build_command(args)

    def test_simulator_rejects_physical_bundle_id_override(self):
        args = SimpleNamespace(device="booted", profile="flash",
                               physical=False, app_path=None,
                               expected_bundle_id="com.example.owned.igentic")
        with self.assertRaisesRegex(ValueError, "only valid with --physical"):
            MODULE.build_command(args)

    def test_physical_run_accepts_matching_owner_signed_bundle(self):
        with tempfile.TemporaryDirectory() as temp:
            bundle = Path(temp) / "iGenticDiagnostics.app"
            bundle.mkdir()
            with (bundle / "Info.plist").open("wb") as output:
                plistlib.dump({"CFBundleIdentifier": "com.example.owned.igentic"}, output)
            checks = {"xcode_27_or_newer": True, "uv_available": True,
                      "ios_project_exists": True}
            with patch.object(MODULE, "require_pinned"), \
                 patch.object(MODULE, "doctor", return_value=checks), \
                 patch.object(MODULE, "run_bounded", return_value=0) as run:
                with redirect_stdout(io.StringIO()):
                    code = MODULE.main([
                        "run", "--execute", "--acknowledge-model-io",
                        "--physical", "--device", "OWNED-DEVICE",
                        "--app-path", str(bundle),
                        "--expected-bundle-id", "com.example.owned.igentic",
                    ])
            self.assertEqual(code, 0)
            run.assert_called_once()

    def test_physical_run_refuses_mismatched_signed_bundle_before_execution(self):
        with tempfile.TemporaryDirectory() as temp:
            bundle = Path(temp) / "iGenticDiagnostics.app"
            bundle.mkdir()
            with (bundle / "Info.plist").open("wb") as output:
                plistlib.dump({"CFBundleIdentifier": "com.example.other"}, output)
            with patch.object(MODULE, "require_pinned") as pinned, \
                 patch.object(MODULE, "run_bounded") as run:
                with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                    code = MODULE.main([
                        "run", "--execute", "--acknowledge-model-io",
                        "--physical", "--device", "OWNED-DEVICE",
                        "--app-path", str(bundle),
                        "--expected-bundle-id", "com.example.owned.igentic",
                    ])
            self.assertEqual(code, 2)
            pinned.assert_not_called()
            run.assert_not_called()

    def test_profile_pro_is_forwarded(self):
        args = SimpleNamespace(device="1234", profile="pro",
                               physical=True, app_path="/tmp/demo.app",
                               expected_bundle_id="com.example.owned.igentic")
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

    def test_simulator_inventory_accepts_single_booted_device(self):
        inventory = json.dumps({
            "devices": {"iOS 27": [{"udid": "SIM-123", "state": "Booted"}]}
        })
        with patch.object(MODULE, "command_output", return_value=(0, inventory)):
            MODULE.require_simulator_target("booted")
            MODULE.require_simulator_target("SIM-123")

    def test_simulator_inventory_rejects_physical_udid(self):
        inventory = json.dumps({
            "devices": {"iOS 27": [{"udid": "SIM-123", "state": "Booted"}]}
        })
        with patch.object(MODULE, "command_output", return_value=(0, inventory)):
            with self.assertRaisesRegex(ValueError, "not an available iOS simulator"):
                MODULE.require_simulator_target("REAL-PHONE")

    def test_simulator_inventory_rejects_ambiguous_booted_state(self):
        with patch.object(MODULE, "command_output", return_value=(0, '{"devices": {}}')):
            with self.assertRaisesRegex(ValueError, "Exactly one"):
                MODULE.require_simulator_target("booted")

    def test_simulator_inventory_refuses_invalid_data(self):
        with patch.object(MODULE, "command_output", return_value=(0, "not json")):
            with self.assertRaisesRegex(ValueError, "not valid JSON"):
                MODULE.require_simulator_target("booted")

    def test_pinned_checkout_rejects_dirty_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / ".git").mkdir()
            with patch.object(MODULE, "command_output", side_effect=[
                (0, MODULE.UPSTREAM_SHA), (0, " M artemis/drivers/ios/xcode_driver.py")
            ]):
                self.assertFalse(MODULE.is_pinned(root))

    def test_pinned_checkout_rejects_untracked_python_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / ".git").mkdir()
            with patch.object(MODULE, "command_output", side_effect=[
                (0, MODULE.UPSTREAM_SHA), (0, "?? injected_module.py")
            ]) as command:
                self.assertFalse(MODULE.is_pinned(root))
            self.assertIn("--untracked-files=normal", command.call_args_list[1].args[0])

    def test_doctor_reports_missing_local_prereqs(self):
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(MODULE.platform, "system", return_value="Linux"):
                result = MODULE.doctor(Path(temporary))
            self.assertFalse(result["xcode_27_or_newer"])
            self.assertFalse(result["source_pinned"])
            self.assertEqual(MODULE.UPSTREAM_SHA, result["upstream_sha"])


if __name__ == "__main__":
    unittest.main()
