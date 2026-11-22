"""Synthetic no-device USB-C readiness tests; no Apple account or cable needed."""
from __future__ import annotations

import unittest

from iphone_usb_readiness import coredevice_usb_summary, summarize, usb_cable_presence
from iphone_wireless_readiness import mobilecli_summary


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
                           {"mobilecli_real_discovered": True, "mobilecli_real_count": 1})
        self.assertTrue(result["usb_readonly_candidate"])
        self.assertEqual(result["blockers"], [])
        self.assertEqual(core["physical_wired_iphone_count"], 1)
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
                                   {"mobilecli_real_discovered": False, "mobilecli_real_count": 0})[
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
                    {"mobilecli_real_discovered": cli, "mobilecli_real_count": int(cli)})["usb_readonly_candidate"])

    def test_usb_presence_is_one_signal_only_not_a_device_credential(self):
        self.assertTrue(usb_cable_presence('  "USB Product Name" = "iPhone"'))
        self.assertTrue(usb_cable_presence('  "Apple Mobile Device"'))
        self.assertFalse(usb_cable_presence('  "USB Product Name" = "iPad"'))
        self.assertFalse(usb_cable_presence('  "Device Name" = "Keyboard"'))
        self.assertFalse(usb_cable_presence(''))

    def test_multiple_live_wired_iphones_are_ambiguous_not_ready(self):
        core = coredevice_usb_summary({"result": {"devices": [iphone(), iphone()]}})
        self.assertEqual(core["physical_wired_iphone_count"], 2)
        result = summarize({"physical_iphone_usb_present": True}, core,
                           {"mobilecli_real_discovered": True, "mobilecli_real_count": 1})
        self.assertFalse(result["usb_readonly_candidate"])
        self.assertIn("multiple_wired_iphones_ambiguous", result["blockers"])
        self.assertNotIn("SENSITIVE_", str(result))

    def test_multiple_mobilecli_phones_are_ambiguous_not_ready(self):
        core = coredevice_usb_summary({"result": {"devices": [iphone()]}})
        cli = mobilecli_summary({"status": "ok", "data": {"devices": [
            {"id": "SENSITIVE_PHONE_A"}, {"id": "SENSITIVE_PHONE_B"},
        ]}})
        result = summarize({"physical_iphone_usb_present": True}, core, cli)
        self.assertFalse(result["usb_readonly_candidate"])
        self.assertIn("multiple_mobilecli_devices_ambiguous", result["blockers"])
        self.assertNotIn("SENSITIVE_", str(result))

    def test_missing_count_never_authorizes_even_if_boolean_says_yes(self):
        core = coredevice_usb_summary({"result": {"devices": [iphone()]}})
        result = summarize({"physical_iphone_usb_present": True}, core,
                           {"mobilecli_real_discovered": True})
        self.assertFalse(result["usb_readonly_candidate"])
        self.assertIn("mobilecli_candidate_count_unknown", result["blockers"])

    def test_unavailable_discovery_reports_anonymous_blockers(self):
        result = summarize({"error": "usb_enumeration_failed"},
                           {"error": "coredevice_timeout"},
                           {"error": "mobilecli_invalid_response"})
        self.assertFalse(result["usb_readonly_candidate"])
        self.assertEqual(result["blockers"], [
            "usb_enumeration_unavailable", "coredevice_enumeration_unavailable",
            "mobilecli_enumeration_unavailable",
        ])

    def test_mobilecli_malformed_data_fails_closed_without_identifiers(self):
        for payload in [None, {"status": "ok", "data": "bad"},
                        {"status": "ok", "data": {"devices": ["fake"]}}]:
            with self.subTest(payload=type(payload).__name__):
                self.assertRaises(ValueError, mobilecli_summary, payload)

    def test_invalid_nested_coredevice_fields_fail_closed(self):
        for bad in [None, {"result": "string"},
                    {"result": {"devices": [{"hardwareProperties": "bad"}]}},
                    {"result": {"devices": ["not-a-device"]}}]:
            with self.subTest(payload=type(bad).__name__):
                self.assertRaises(ValueError, coredevice_usb_summary, bad)

    def test_invalid_payload_fails_closed(self):
        self.assertRaises(ValueError, coredevice_usb_summary,
                          {"result": {"devices": "not a list"}})
        self.assertEqual(coredevice_usb_summary({})[
            "physical_iphone_registered"], False)


if __name__ == "__main__":
    unittest.main()
