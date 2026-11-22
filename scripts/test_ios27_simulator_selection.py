"""Deterministic simulator-selection tests; no Xcode or physical iPhone needed."""
from __future__ import annotations

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
