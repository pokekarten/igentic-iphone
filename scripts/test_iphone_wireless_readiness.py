#!/usr/bin/env python3
"""Deterministic offline tests; no device, network or Apple account required."""
import unittest

from iphone_wireless_readiness import coredevice_summary, mobilecli_summary, readiness


def example_device(*, reality="physical", transport=None, tunnel="unavailable", paired=True):
    return {
        "hardwareProperties": {"platform": "iOS", "reality": reality},
        "connectionProperties": {
            "transportType": transport,
            "tunnelState": tunnel,
            "pairingState": "paired" if paired else "unpaired",
        },
        "identifier": "PRIVATE-NOT-FOR-OUTPUT",
        "deviceProperties": {"name": "PRIVATE-NOT-FOR-OUTPUT"},
    }


class WirelessReadinessTests(unittest.TestCase):
    def test_known_but_unavailable_physical_iphone(self):
        result = coredevice_summary({"result": {"devices": [
            example_device(), example_device(reality="simulated", tunnel="connected")
        ]}})
        self.assertEqual(result, {
            "physical_wireless_tunnel_paired": False,
            "physical_registered": True,
            "physical_paired": True,
            "physical_network_transport": False,
            "physical_tunnel_available": False,
        })
        self.assertFalse(readiness(result, {"mobilecli_real_discovered": False})[
            "wireless_discovery_candidate"
        ])

    def test_network_connected_device_still_not_proof_of_control(self):
        result = readiness(
            coredevice_summary({"result": {"devices": [
                example_device(transport="localNetwork", tunnel="connected")
            ]}}),
            mobilecli_summary({"status": "ok", "data": {"devices": [{"id": "PRIVATE"}]}}),
        )
        self.assertTrue(result["wireless_discovery_candidate"])
        self.assertFalse(result["wireless_screen_control_verified"])
        self.assertNotIn("PRIVATE", str(result))

    def test_multiple_devices_cannot_combine_separate_transport_and_tunnel(self):
        result = readiness(
            coredevice_summary({"result": {"devices": [
                example_device(transport="localNetwork", tunnel="unavailable"),
                example_device(transport="usb", tunnel="connected"),
            ]}}),
            {"mobilecli_real_discovered": True},
        )
        self.assertTrue(result["coredevice"]["physical_network_transport"])
        self.assertTrue(result["coredevice"]["physical_tunnel_available"])
        self.assertFalse(result["coredevice"]["physical_wireless_tunnel_paired"])
        self.assertFalse(result["wireless_discovery_candidate"])

    def test_unpaired_wireless_device_fails_closed(self):
        result = readiness(
            coredevice_summary({"result": {"devices": [
                example_device(
                    transport="localNetwork", tunnel="connected", paired=False
                ),
            ]}}),
            {"mobilecli_real_discovered": True},
        )
        self.assertFalse(result["wireless_discovery_candidate"])

    def test_usb_only_is_not_wireless_candidate(self):
        result = readiness(
            coredevice_summary({"result": {"devices": [
                example_device(transport="usb", tunnel="connected")
            ]}}),
            {"mobilecli_real_discovered": True},
        )
        self.assertFalse(result["wireless_discovery_candidate"])

    def test_invalid_mobilecli_payload_fails_closed(self):
        with self.assertRaises(ValueError):
            mobilecli_summary({"status": "ok", "data": {"devices": "private"}})

    def test_empty_result_fails_closed(self):
        self.assertFalse(coredevice_summary({})["physical_registered"])
        self.assertFalse(mobilecli_summary({"status": "ok", "data": {"devices": []}})[
            "mobilecli_real_discovered"
        ])


if __name__ == "__main__":
    unittest.main()
