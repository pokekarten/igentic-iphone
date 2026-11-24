"""Synthetic, no-device tests for structured CoreDevice readiness."""
import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "check-physical-iphone-readiness.py"
spec = importlib.util.spec_from_file_location("iphone_readiness", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

def row(reality="physical", platform="iOS", device_type="iPhone",
        pairing="paired", tunnel="available", transport="localNetwork"):
    return {"identifier": "synthetic-private-id",
            "hardwareProperties": {"reality": reality, "platform": platform, "deviceType": device_type},
            "connectionProperties": {"pairingState": pairing, "tunnelState": tunnel, "transportType": transport}}

def classify(*rows):
    return module.classify({"result": {"devices": list(rows)}})

class ReadinessTests(unittest.TestCase):
    def test_available_paired_physical_is_ready_for_attempt(self):
        report = classify(row())
        self.assertTrue(report["physical_test_ready"])
        self.assertEqual(report["ready_routes"], ["network-coredevice"])
        self.assertEqual(report["verdict"], "ready_for_test_attempt")

    def test_simulator_cannot_make_physical_ready(self):
        report = classify(row(tunnel="unavailable"), row(reality="simulated"))
        self.assertFalse(report["physical_test_ready"])
        self.assertEqual(report["simulator_count"], 1)

    def test_pairing_and_tunnel_must_belong_to_same_phone(self):
        self.assertFalse(classify(row(pairing="unpaired"), row(tunnel="disconnected"))["physical_test_ready"])

    def test_wired_connected(self):
        self.assertEqual(classify(row(tunnel="connected", transport="wired"))["ready_routes"], ["usb-coredevice"])

    def test_other_apple_hardware_is_excluded(self):
        self.assertEqual(classify(row(device_type="iPad"), row(platform="macOS"))["physical_device_count"], 0)

    def test_unknown_state_fails_closed(self):
        self.assertFalse(classify(row(tunnel="new-state"))["physical_test_ready"])

    def test_unknown_transport_only_fixed_code(self):
        report = classify(row(transport="private-hostname"))
        self.assertEqual(report["ready_routes"], ["coredevice-transport-unclassified"])
        self.assertNotIn("private-hostname", str(report))
        self.assertNotIn("synthetic-private-id", str(report))

    def test_no_devices_fail_closed(self):
        self.assertFalse(classify()["physical_test_ready"])

    def test_malformed_response_is_not_success(self):
        for value in (None, {}, {"result": {"devices": "invalid"}}, {"result": {"devices": [None]}},
                      {"result": {"devices": [{"hardwareProperties": "invalid"}]}}):
            with self.subTest(value=value), self.assertRaises(ValueError):
                module.classify(value)

if __name__ == "__main__":
    unittest.main()
