#!/usr/bin/env python3
"""Offline unit tests for the macOS/Xcode 27 preparation runner.

These tests do not need macOS, Xcode, model weights or the internet.
"""
from __future__ import annotations

import importlib.util
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
