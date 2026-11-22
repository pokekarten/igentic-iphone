"""Synthetic no-device USB-C readiness tests; no Apple account or cable needed."""
from __future__ import annotations

import unittest

from iphone_usb_readiness import coredevice_usb_summary, summarize, usb_cable_presence


def iphone(*, kind="iPhone", reality="physical", transport="wired",
           tunnel="connected", pairing="paired"):
    return {
        "hardwareProperties": {
            "platform": "iOS", "reality": reality, "deviceType": kind,
        },
        "connectionProperties": {
            "transportType": transport, "tunnelState": tunnel,
            "pairingState": pairing,
        },
        "identifier": "SENSITIVE_ID_NOT_FOR_OUTPUT",
        "deviceProperties": {"name": "SENSITIVE_NAME_NOT_FOR_OUTPUT"},
    }


class USBReadinessTests(unittest.TestCase):
    def test_valid_physical_paired_wired_iphone_can_be_candidate_not_proof(self):
        core = coredevice_usb_summary({"result": {"devices": [iphone()]}})
        result = summarize({"physical_iphone_usb_present": True}, core,
                           {"mobilecli_real_discovered": True})
        self.assertTrue(result["usb_readonly_candidate"])
        self.assertFalse(result["physical_ui_control_verified"])
        self.assertNotIn("SENSITIVE_", str(result))

    def test_no_usb_or_unavailable_phone_is_not_ready(self):
        core = coredevice_usb_summary({"result": {"devices": [
            iphone(tunnel="unavailable", transport=None)
        ]}})
        self.assertTrue(core["physical_iphone_registered"])
        self.assertTrue(core["physical_iphone_paired"])
        self.assertFalse(core["physical_wired_tunnel_available"])
        self.assertFalse(summarize({"physical_iphone_usb_present": False}, core,
                                   {"mobilecli_real_discovered": False})[
            "usb_readonly_candidate"])

    def test_simulator_ipad_unpaired_wireless_and_down_tunnel_rejected(self):
        invalid = [
            iphone(reality="simulated"), iphone(kind="iPad"),
            iphone(pairing="unpaired"), iphone(transport="localNetwork"),
            iphone(tunnel="unavailable"), iphone(tunnel="disconnected"),
        ]
        for row in invalid:
            with self.subTest(row=row):
                self.assertFalse(coredevice_usb_summary(
                    {"result": {"devices": [row]}})["physical_wired_tunnel_available"])

    def test_separate_devices_must_not_combine_individual_flags(self):
        rows = [iphone(tunnel="unavailable"), iphone(pairing="unpaired")]
        core = coredevice_usb_summary({"result": {"devices": rows}})
        self.assertFalse(core["physical_wired_tunnel_available"])

    def test_missing_mobilecli_or_usb_always_rejected(self):
        core = coredevice_usb_summary({"result": {"devices": [iphone()]}})
        for usb, cli in [(False, True), (True, False)]:
            with self.subTest(usb=usb, cli=cli):
                self.assertFalse(summarize(
                    {"physical_iphone_usb_present": usb}, core,
                    {"mobilecli_real_discovered": cli})["usb_readonly_candidate"])

    def test_usb_presence_is_one_signal_only_not_a_device_credential(self):
        self.assertTrue(usb_cable_presence('  "USB Product Name" = "iPhone"'))
        self.assertTrue(usb_cable_presence('  "Apple Mobile Device"'))
        self.assertFalse(usb_cable_presence('  "USB Product Name" = "iPad"'))
        self.assertFalse(usb_cable_presence('  "Device Name" = "Keyboard"'))
        self.assertFalse(usb_cable_presence(''))

    def test_invalid_payload_fails_closed(self):
        self.assertRaises(ValueError, coredevice_usb_summary,
                          {"result": {"devices": "not a list"}})
        self.assertEqual(coredevice_usb_summary({})[
            "physical_iphone_registered"], False)


if __name__ == "__main__":
    unittest.main()
