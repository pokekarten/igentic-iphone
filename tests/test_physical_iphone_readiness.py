"""Synthetic, no-device tests for the physical iPhone readiness preflight."""
import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "check-physical-iphone-readiness.py"
spec = importlib.util.spec_from_file_location("iphone_readiness", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

HEADER = (
    "Name            Hostname   Identifier                                    State         Model                        Reality  \n"
    "-------------   --------   -------------------------------------------   -----------   --------------------------   ---------\n"
)


class ReadinessTests(unittest.TestCase):
    def test_unavailable_physical_does_not_become_ready_from_connected_simulator(self):
        data = HEADER + (
            "BOS's iPhone               00000000-00000000 (UDID)              unavailable   iPhone Air (iPhone18,4)      physical \n"
            "iPhone Air                 AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA (UDID)   connected     iPhone Air (iPhone18,4)      simulated\n"
        )
        result = module.classify(data)
        self.assertFalse(result["physical_test_ready"])
        self.assertEqual(result["physical_states"], ["unavailable"])
        self.assertEqual(result["simulator_count"], 1)
        self.assertNotIn("00000000", str(result))

    def test_connected_physical_is_ready_for_test_attempt_only(self):
        result = module.classify(
            "My iPhone     00000000-00000000 (UDID)    connected    iPhone Air    physical\n"
        )
        self.assertTrue(result["physical_test_ready"])
        self.assertEqual(result["verdict"], "ready_for_test_attempt")

    def test_no_devices_fail_closed(self):
        result = module.classify(HEADER)
        self.assertFalse(result["physical_test_ready"])
        self.assertEqual(result["physical_device_count"], 0)

    def test_unrecognized_state_fails_closed(self):
        result = module.classify(
            "My iPhone     00000000-00000000 (UDID)    new-unexpected-state    iPhone Air    physical\n"
        )
        self.assertFalse(result["physical_test_ready"])
        self.assertEqual(result["physical_states"], ["unknown"])


if __name__ == "__main__":
    unittest.main()
