"""Deterministic simulator-selection tests; no Xcode or physical iPhone needed."""
from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from select_ios27_simulator import select_compatible_iphone  # noqa: E402


def device(name: str, udid: str, available: bool = True) -> dict:
    return {"name": name, "udid": udid, "isAvailable": available}


class IOS27SimulatorSelectionTests(unittest.TestCase):
    def test_prefers_latest_ios27_iphone_not_old_runtime(self):
        payload = {"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-26-6": [device("iPhone 16", "old")],
            "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [device("iPhone Air", "new")],
            "com.apple.CoreSimulator.SimRuntime.iOS-27-2": [device("iPhone Air", "newer")],
        }}
        self.assertEqual(
            select_compatible_iphone(payload),
            ("newer", "iPhone Air", "com.apple.CoreSimulator.SimRuntime.iOS-27-2"),
        )

    def test_xcode_271_chooses_271_not_newer_272(self):
        payload = {"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-27-1": [device("iPhone Air", "matching")],
            "com.apple.CoreSimulator.SimRuntime.iOS-27-2": [device("iPhone Air", "mismatched")],
        }}
        self.assertEqual(select_compatible_iphone(payload, "27.1")[0], "matching")
        self.assertEqual(select_compatible_iphone(payload, "27.2")[0], "mismatched")

    def test_missing_matching_runtime_fails_closed(self):
        payload = {"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-27-2": [device("iPhone Air", "newer")],
        }}
        with self.assertRaisesRegex(ValueError, "No iOS 27.1 iPhone simulator"):
            select_compatible_iphone(payload, "27.1")

    def test_cli_requires_xcode_matched_runtime_and_never_falls_back(self):
        payload = json.dumps({"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-27-2": [device("iPhone Air", "fixture-272")]
        }})
        command = [sys.executable, str(Path(__file__).with_name("select_ios27_simulator.py"))]
        good = subprocess.run(command + ["--match-runtime", "27.2"],
                              input=payload, capture_output=True, text=True)
        self.assertEqual(good.returncode, 0, good.stderr)
        self.assertEqual(good.stdout.strip(), "fixture-272")
        bad = subprocess.run(command + ["--match-runtime", "27.1"],
                             input=payload, capture_output=True, text=True)
        self.assertEqual(bad.returncode, 1)
        self.assertFalse(bad.stdout.strip())
        self.assertIn("No iOS 27.1 iPhone simulator", bad.stderr)

    def test_bad_xcode_version_rejected(self):
        payload = {"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-27-2": [device("iPhone Air", "newer")],
        }}
        for version in ("26.7", "27", "xcode27.2", "27.2.2x", ""):
            with self.subTest(version=version), self.assertRaisesRegex(ValueError, "Invalid"):
                select_compatible_iphone(payload, version)

    def test_rejects_only_older_iphones(self):
        payload = {"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-26-6": [device("iPhone 16", "old")],
        }}
        with self.assertRaisesRegex(ValueError, "iOS 27"):
            select_compatible_iphone(payload)

    def test_does_not_select_ipad_or_unavailable_iphone(self):
        payload = {"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-27-2": [
                device("iPad Pro", "ipad"),
                device("iPhone Air", "off", available=False),
            ],
        }}
        with self.assertRaises(ValueError):
            select_compatible_iphone(payload)

    def test_supports_future_ios_without_downgrading(self):
        payload = {"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-27-2": [device("iPhone Air", "27")],
            "com.apple.CoreSimulator.SimRuntime.iOS-28-0": [device("iPhone", "28")],
        }}
        self.assertEqual(select_compatible_iphone(payload)[0], "28")

    def test_rejects_invalid_payload_and_bad_runtime(self):
        with self.assertRaises(ValueError):
            select_compatible_iphone({"devices": []})
        with self.assertRaises(ValueError):
            select_compatible_iphone({"devices": {
                "com.apple.CoreSimulator.SimRuntime.iOS-27-bogus": [device("iPhone", "bad")],
            }})


if __name__ == "__main__":
    unittest.main()
