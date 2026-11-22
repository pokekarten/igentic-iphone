#!/usr/bin/env python3
"""Privacy-safe, read-only discovery gate for a physical iPhone on Xcode 27.

This never installs apps, mounts a developer image, opens a tunnel, takes a
screenshot, sends input or prints identifiers. Reachability is not UI control.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def coredevice_summary(payload: dict) -> dict:
    physical = [
        device for device in payload.get("result", {}).get("devices", [])
        if device.get("hardwareProperties", {}).get("platform") == "iOS"
        and device.get("hardwareProperties", {}).get("reality") == "physical"
    ]
    connections = [device.get("connectionProperties", {}) for device in physical]
    # A candidate must satisfy every requirement on one physical device.
    # Combining properties from separate devices would be a false positive.
    wireless_paired_tunnel = any(
        c.get("pairingState") == "paired"
        and c.get("transportType") == "localNetwork"
        and c.get("tunnelState") in ("connected", "available", "active")
        for c in connections
    )
    return {
        "physical_wireless_tunnel_paired": wireless_paired_tunnel,
        "physical_registered": bool(physical),
        "physical_paired": any(c.get("pairingState") == "paired" for c in connections),
        "physical_network_transport": any(
            c.get("transportType") == "localNetwork" for c in connections
        ),
        "physical_tunnel_available": any(
            c.get("tunnelState") in ("connected", "available", "active")
            for c in connections
        ),
    }


def mobilecli_summary(payload: dict) -> dict:
    if payload.get("status") != "ok":
        raise ValueError("mobilecli did not return ok")
    devices = payload.get("data", {}).get("devices", [])
    if not isinstance(devices, list):
        raise ValueError("mobilecli devices is not a list")
    # The CLI command explicitly filters by platform=ios and type=real.
    return {"mobilecli_real_discovered": bool(devices)}


def coredevice_probe() -> dict:
    if not shutil.which("xcrun"):
        return {"error": "xcrun_missing"}
    with tempfile.TemporaryDirectory(prefix="igentic-device-probe-") as temp_dir:
        output_file = Path(temp_dir) / "devices.json"
        try:
            completed = subprocess.run(
                ["xcrun", "devicectl", "list", "devices", "--json-output", str(output_file)],
                capture_output=True, timeout=25, check=False,
            )
            if completed.returncode != 0:
                return {"error": "coredevice_failed"}
            return coredevice_summary(json.loads(output_file.read_text()))
        except subprocess.TimeoutExpired:
            return {"error": "coredevice_timeout"}
        except (OSError, ValueError, KeyError, TypeError):
            return {"error": "coredevice_invalid_response"}


def mobilecli_probe() -> dict:
    cli = shutil.which("mobilecli")
    if cli:
        command = [cli, "devices", "--platform", "ios", "--type", "real"]
    elif shutil.which("npm"):
        # Never install or update a package just to run a discovery check.
        command = [
            "npm", "exec", "--offline", "--yes", "--package=mobilecli@1.0.24",
            "--", "mobilecli", "devices", "--platform", "ios", "--type", "real",
        ]
    else:
        return {"error": "mobilecli_missing"}
    try:
        completed = subprocess.run(
            command, capture_output=True, timeout=25, check=False,
            env={**os.environ, "MOBILEMCP_DISABLE_TELEMETRY": "1"},
        )
        if completed.returncode != 0:
            return {"error": "mobilecli_failed_or_not_cached"}
        return mobilecli_summary(json.loads(completed.stdout))
    except subprocess.TimeoutExpired:
        return {"error": "mobilecli_timeout"}
    except (OSError, ValueError, KeyError, TypeError):
        return {"error": "mobilecli_invalid_response"}


def readiness(coredevice: dict, mobilecli: dict) -> dict:
    discoverable = (
        coredevice.get("physical_wireless_tunnel_paired") is True
        and mobilecli.get("mobilecli_real_discovered") is True
    )
    return {
        "coredevice": coredevice,
        "mobilecli": mobilecli,
        "wireless_discovery_candidate": discoverable,
        "wireless_screen_control_verified": False,
        "note": (
            "Discovery only. A separate, explicitly authorized no-cable "
            "screenshot/UI-tree/tap test is required for control proof."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--require-wireless-candidate", action="store_true",
        help="exit 2 unless both discovery tools agree on a network-reachable device",
    )
    args = parser.parse_args()
    result = readiness(coredevice_probe(), mobilecli_probe())
    print(json.dumps(result, sort_keys=True))
    return 2 if args.require_wireless_candidate and not result["wireless_discovery_candidate"] else 0


if __name__ == "__main__":
    sys.exit(main())
