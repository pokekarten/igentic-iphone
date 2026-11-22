"""Deterministic iOS 27 dual-display simulator smoke-contract tests.

No real simulator, phone, screenshot, app installation or external service used.
"""
from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SMOKE = ROOT / "scripts/smoke-ios-simulator.sh"

FAKE_XCRUN = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
args=sys.argv[1:]
with open(os.environ["IGENTIC_TEST_LOG"], "a") as f:
    f.write(json.dumps(args) + "\n")
if args[:5] == ["simctl","list","devices","available","-j"]:
    print(json.dumps({"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-1":[
        {"name":"iPhone Duo","udid":"FAKE-DUO","isAvailable":True}
    ]}}))
elif args[:2] == ["simctl","launch"]:
    print("org.example.iGenticDiagnostics: 1234")
elif args[:3] == ["simctl","io","FAKE-DUO"]:
    if len(args) != 6 or args[3:5] != ["screenshot","--display=1"]:
        print("Cannot choose between 2 displays",file=sys.stderr)
        sys.exit(22)
    pathlib.Path(args[5]).write_bytes(b"\x89PNG\r\n\x1a\nsynthetic")
elif args[:2] == ["simctl","bootstatus"]:
    pass
elif args[:2] == ["simctl","boot"]:
    pass
elif args[:2] == ["simctl","install"]:
    pass
elif args[:2] == ["simctl","terminate"]:
    pass
elif args[:2] == ["simctl","shutdown"]:
    pass
else:
    print("unknown simulated command",args,file=sys.stderr)
    sys.exit(7)
'''


class DualDisplaySmokeContract(unittest.TestCase):
    def test_screenshot_explicitly_chooses_primary_display(self):
        with tempfile.TemporaryDirectory(prefix="igentic-dual-display-") as d:
            work = Path(d)
            bin_dir = work / "bin"
            bin_dir.mkdir()
            xcrun = bin_dir / "xcrun"
            xcrun.write_text(FAKE_XCRUN)
            xcrun.chmod(0o755)
            sleep = bin_dir / "sleep"
            sleep.write_text("#!/bin/sh\nexit 0\n")
            sleep.chmod(0o755)
            # A Linux audit host has no macOS `stat -f %z` semantics.
            # If the smoke script ever reintroduces that call, fail.
            stat = bin_dir / "stat"
            stat.write_text("#!/bin/sh\nexit 88\n")
            stat.chmod(0o755)
            app = work / "iGenticDiagnostics.app"
            app.mkdir()
            screenshot = work / "simulator-only.png"
            log = work / "calls.jsonl"
            env = {**os.environ,
                   "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"],
                   "APP_PATH": str(app),
                   "SCREENSHOT_PATH": str(screenshot),
                   "IOS27_MATCHED_RUNTIME": "27.1",
                   "BUNDLE_IDENTIFIER": "org.example.iGenticDiagnostics",
                   "IGENTIC_TEST_LOG": str(log)}
            result = subprocess.run(["bash", str(SMOKE)], env=env, capture_output=True,
                                    text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(screenshot.read_bytes()[:8], b"\x89PNG\r\n\x1a\n")
            commands = [json.loads(line) for line in log.read_text().splitlines()]
            screenshot_calls = [x for x in commands if x[:4] == ["simctl","io","FAKE-DUO","screenshot"]]
            self.assertEqual(screenshot_calls, [["simctl","io","FAKE-DUO","screenshot",
                                                 "--display=1",str(screenshot)]])
            self.assertEqual(len([x for x in commands if x[:2] == ["simctl","launch"]]), 2)
            self.assertEqual(len([x for x in commands if x[:2] == ["simctl","shutdown"]]), 1)
            self.assertIn("Captured simulator screenshot (17 bytes)", result.stdout)
            self.assertIn("smoke test passed", result.stdout)


if __name__ == "__main__":
    unittest.main()
