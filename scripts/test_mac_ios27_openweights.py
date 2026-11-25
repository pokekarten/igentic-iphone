#!/usr/bin/env python3
"""Offline unit tests for the macOS/Xcode 27 preparation runner.

These tests do not need macOS, Xcode, model weights or the internet.
"""
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

MODULE_PATH = Path(__file__).with_name("mac_ios27_openweights_test.py")
SPEC = importlib.util.spec_from_file_location("igentic_mac_probe", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
mod = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = mod
sys.path.insert(0, str(MODULE_PATH.parent))
SPEC.loader.exec_module(mod)


class MacOpenWeightsTest(unittest.TestCase):
    def test_xcode_27_version(self) -> None:
        self.assertEqual(mod.major_version("Xcode 27.1\nBuild version B", r"^Xcode (\d+)(?:[.]|$)"), 27)

    def test_old_xcode_is_detectable(self) -> None:
        self.assertEqual(mod.major_version("Xcode 26.3", r"^Xcode (\d+)(?:[.]|$)"), 26)

    def test_sdk_version(self) -> None:
        self.assertEqual(mod.major_version("27.2", r"^(\d+)"), 27)
        self.assertEqual(mod.major_version("26.4", r"^(\d+)"), 26)

    def test_default_phase_is_preflight_only(self) -> None:
        self.assertEqual(mod.command_plan("preflight", Path("/tmp/probe")), [])

    def test_build_plan_is_local_bounded_and_unsigned(self) -> None:
        steps = mod.command_plan("build", Path("/tmp/igentic-test"))
        self.assertEqual(len(steps), 7)
        commands = [argv for argv, _ in steps]
        self.assertTrue(any("scripts/validate_ios27_baseline.py" in c for c in commands))
        self.assertTrue(any("swift" == c[0] and "build" == c[1] for c in commands))
        self.assertTrue(any("swift" == c[0] and "test" == c[1] for c in commands))
        self.assertTrue(any("xcodebuild" == c[0] for c in commands))
        self.assertTrue(any("CODE_SIGNING_ALLOWED=NO" in c for c in commands))
        self.assertTrue(all("curl" not in c and "wget" not in c and "sudo" not in c for c in commands))
        for c in commands:
            if c[0] == "swift":
                self.assertIn("--scratch-path", c)
                self.assertIn("-j", c)
                self.assertIn("2", c)

    def test_simulator_is_separate_explicit_phase(self) -> None:
        build = mod.command_plan("build", Path("/tmp/probe"))
        simulator = mod.command_plan("simulator", Path("/tmp/probe"))
        self.assertEqual(simulator[:-1], build)
        self.assertEqual(simulator[-1][0], ["bash", "scripts/smoke-ios-simulator.sh"])

    def test_non_mac_preflight_fails_without_external_calls(self) -> None:
        with patch.object(mod.platform, "system", return_value="Linux"), \
             patch.object(mod.platform, "machine", return_value="x86_64"), \
             patch.object(mod, "run_capture", side_effect=AssertionError("probe should not run")):
            checks, info = mod.preflight()
        self.assertEqual(info, {})
        self.assertEqual(len(checks), 2)
        self.assertFalse(all(x.ok for x in checks))

    def test_hosted_7_gib_build_host_is_not_inference_proof(self) -> None:
        from types import SimpleNamespace
        outputs = {
            "xcodebuild": "Xcode 27.1\\nBuild version C",
            "swift": "Apple Swift version 6.4.2",
            "xcrun": "27.1",
            "sysctl": str(7 * mod.GIB),
        }
        def fake_capture(argv: list[str]) -> str:
            return outputs[argv[0]].replace("\\n", "\n")

        with patch.object(mod.platform, "system", return_value="Darwin"), \
             patch.object(mod.platform, "machine", return_value="arm64"), \
             patch.object(mod.platform, "mac_ver", return_value=("27.0.1", ("", "", ""), "")), \
             patch.object(mod, "run_capture", side_effect=fake_capture), \
             patch.object(mod.shutil, "disk_usage", return_value=SimpleNamespace(free=6 * mod.GIB)):
            checks, info = mod.preflight()
        self.assertTrue(all(c.ok for c in checks), checks)
        self.assertEqual(info["ram_gib"], "7.0")
        self.assertIn("Build host RAM >= 7 GiB", [c.label for c in checks])

    def test_isolated_simulator_cleanup_on_failure(self):
        runtime = "com.apple.CoreSimulator.SimRuntime.iOS-27-2"
        source = "11111111-1111-1111-1111-111111111111"
        created = "22222222-2222-2222-2222-222222222222"
        kind = "com.apple.CoreSimulator.SimDeviceType.iPhone-Air"
        payload = {"devices": {runtime: [{"name": "iPhone Air", "udid": source,
                    "isAvailable": True, "deviceTypeIdentifier": kind}]}}
        with patch.object(mod, "run_capture", side_effect=["Xcode 27.2", json.dumps(payload), created]) as capture, patch.object(mod.subprocess, "run") as cleanup:
            with self.assertRaises(RuntimeError):
                with mod.isolated_simulator() as selected:
                    self.assertEqual(selected, created)
                    raise RuntimeError("synthetic failure")
            self.assertEqual(capture.call_args.args[0][-2:], [kind, runtime])
            self.assertEqual([c.args[0] for c in cleanup.call_args_list],
                             [["xcrun", "simctl", op, created] for op in ("shutdown", "delete")])

    def test_refuses_existing_simulator_identity(self):
        runtime = "com.apple.CoreSimulator.SimRuntime.iOS-27-2"
        source = "11111111-1111-1111-1111-111111111111"
        payload = {"devices": {runtime: [{"name": "iPhone Air", "udid": source,
            "isAvailable": True, "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-Air"}]}}
        with patch.object(mod, "run_capture", side_effect=["Xcode 27.2", json.dumps(payload), source]), patch.object(mod.subprocess, "run") as cleanup:
            with self.assertRaises(ValueError):
                with mod.isolated_simulator():
                    self.fail("must not use existing simulator")
            cleanup.assert_not_called()

    def test_report_cannot_overwrite_file_created_after_preflight(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "report.json"
            def preflight():
                report.write_text("existing", encoding="utf-8")
                return [mod.Check("synthetic", True, "ok")], {}
            with patch.object(sys, "argv", ["probe", "--report", str(report)]), \
                 patch.object(mod, "preflight", side_effect=preflight):
                self.assertEqual(mod.main(), 2)
            self.assertEqual(report.read_text(encoding="utf-8"), "existing")

    def test_no_model_execution_is_in_plan(self) -> None:
        for phase in ("preflight", "build", "simulator"):
            commands = [a for argv, _ in mod.command_plan(phase, Path("/tmp/probe"))
                        for a in argv]
            self.assertFalse(any("huggingface" in a.lower() for a in commands))
            self.assertFalse(any("download" in a.lower() for a in commands))
            self.assertFalse(any("ollama" in a.lower() for a in commands))
            self.assertFalse(any("git" == a for a in commands))


if __name__ == "__main__":
    unittest.main()
