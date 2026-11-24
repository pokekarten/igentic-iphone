#!/usr/bin/env python3
"""Read-only, identifier-free CoreDevice readiness check, not device control."""
import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROUTES = {
    "wired": "usb-coredevice", "usb": "usb-coredevice", "usbmux": "usb-coredevice",
    "wireless": "network-coredevice", "wifi": "network-coredevice",
    "wi-fi": "network-coredevice", "network": "network-coredevice",
    "localnetwork": "network-coredevice",
}

def classify(payload: dict) -> dict:
    if not isinstance(payload, dict) or not isinstance(payload.get("result"), dict):
        raise ValueError("invalid CoreDevice result")
    rows = payload["result"].get("devices")
    if not isinstance(rows, list):
        raise ValueError("invalid device list")
    states, routes = [], []
    simulated = 0
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("invalid device entry")
        hardware = row.get("hardwareProperties")
        connection = row.get("connectionProperties", {})
        if not isinstance(hardware, dict) or not isinstance(connection, dict):
            raise ValueError("invalid nested fields")
        if hardware.get("reality") == "simulated":
            simulated += 1
        if (hardware.get("reality") != "physical" or
                hardware.get("platform") != "iOS" or
                hardware.get("deviceType") != "iPhone"):
            continue
        if connection.get("pairingState") != "paired":
            states.append("pairing-required")
        elif connection.get("tunnelState") not in ("connected", "available"):
            states.append("no-active-tunnel")
        else:
            states.append("xcode-tunnel-available")
            transport = connection.get("transportType")
            routes.append(ROUTES.get(transport.lower(), "coredevice-transport-unclassified")
                          if isinstance(transport, str) and len(transport) <= 24
                          else "coredevice-transport-unclassified")
    ready = "xcode-tunnel-available" in states
    return {
        "physical_device_count": len(states),
        "physical_states": sorted(states),
        "simulator_count": simulated,
        "physical_test_ready": ready,
        "ready_routes": sorted(set(routes)),
        "verdict": "ready_for_test_attempt" if ready else "physical_device_not_ready",
    }

def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, help="Synthetic CoreDevice JSON, no device contacted")
    parser.add_argument("--json", action="store_true", help="Emit identifier-free JSON")
    args = parser.parse_args(argv)
    try:
        if args.fixture:
            payload = json.loads(args.fixture.read_text(encoding="utf-8"))
        else:
            with tempfile.TemporaryDirectory(prefix="igentic-physical-readiness-") as directory:
                path = Path(directory) / "devices.json"
                result = subprocess.run(
                    ["xcrun", "devicectl", "list", "devices", "--json-output", str(path)],
                    capture_output=True, timeout=25, check=False,
                )
                if result.returncode != 0:
                    print("DEVICE_CHECK=devicectl_failed", file=sys.stderr)
                    return 3
                payload = json.loads(path.read_text(encoding="utf-8"))
        report = classify(payload)
    except (OSError, ValueError, TypeError, subprocess.TimeoutExpired):
        print("DEVICE_CHECK=unverified", file=sys.stderr)
        return 3
    if args.json:
        print(json.dumps(report, sort_keys=True))
    else:
        print("PHYSICAL_IPHONE_READY=" + ("yes" if report["physical_test_ready"] else "no"))
        print("PHYSICAL_DEVICE_COUNT=" + str(report["physical_device_count"]))
        print("SIMULATOR_COUNT=" + str(report["simulator_count"]))
        print("PHYSICAL_DEVICE_STATES=" + ",".join(report["physical_states"]))
        print("READY_ROUTES=" + ",".join(report["ready_routes"]))
        print("VERDICT=" + report["verdict"])
    return 0 if report["physical_test_ready"] else 2

if __name__ == "__main__":
    raise SystemExit(main())
