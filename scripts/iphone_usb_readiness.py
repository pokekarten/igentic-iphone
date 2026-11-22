#!/usr/bin/env python3
"""Read-only, identifier-free physical iPhone USB-C preflight (no Wi-Fi needed).

This only discovers USB / Xcode CoreDevice / MobileCLI state. It never pairs,
opens a tunnel, installs apps, takes screenshots, sends taps or reads phone UI.
Even full discovery is NOT evidence of successful phone control.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from iphone_wireless_readiness import mobilecli_probe


def coredevice_usb_summary(payload: dict) -> dict:
    rows = payload.get("result", {}).get("devices", [])
    if not isinstance(rows, list):
        raise ValueError("Invalid CoreDevice device list")
    registered = False
    paired = False
    directly_ready = False
    for row in rows:
        if not isinstance(row, dict):
            continue
        hardware = row.get("hardwareProperties") or {}
        conn = row.get("connectionProperties") or {}
        if (hardware.get("reality") != "physical"
                or hardware.get("platform") != "iOS"
                or hardware.get("deviceType") != "iPhone"):
            continue
        registered = True
        if conn.get("pairingState") == "paired":
            paired = True
            if (str(conn.get("transportType") or "").lower() in ("wired", "usb")
                    and conn.get("tunnelState") in ("available", "connected", "active")):
                directly_ready = True
    return {
        "physical_iphone_registered": registered,
        "physical_iphone_paired": paired,
        "physical_wired_tunnel_available": directly_ready,
    }


def usb_cable_presence(text: str) -> bool:
    # This is one negative/positive *signal*, never sufficient for control.
    # Do not return matching USB lines: they can contain names/serial numbers.
    return re.search(r'\b(?:iPhone|Apple Mobile Device)\b', text, re.I) is not None


def usb_probe() -> dict:
    if not shutil.which("ioreg"):
        return {"error": "ioreg_missing"}
    try:
        process = subprocess.run(["ioreg", "-p", "IOUSB", "-l"],
                                 capture_output=True, text=True, timeout=12)
        if process.returncode:
            return {"error": "usb_enumeration_failed"}
        return {"physical_iphone_usb_present": usb_cable_presence(process.stdout)}
    except subprocess.TimeoutExpired:
        return {"error": "usb_enumeration_timeout"}
    except OSError:
        return {"error": "usb_enumeration_failed"}


def coredevice_probe() -> dict:
    if not shutil.which("xcrun"):
        return {"error": "xcrun_missing"}
    with tempfile.TemporaryDirectory(prefix="igentic-usb-preflight-") as directory:
        output_file = Path(directory) / "devices.json"
        try:
            process = subprocess.run(
                ["xcrun", "devicectl", "list", "devices", "--json-output",
                 str(output_file)],
                capture_output=True, timeout=25,
            )
            if process.returncode:
                return {"error": "coredevice_failed"}
            return coredevice_usb_summary(json.loads(output_file.read_text()))
        except subprocess.TimeoutExpired:
            return {"error": "coredevice_timeout"}
        except (OSError, ValueError, TypeError, KeyError):
            return {"error": "coredevice_invalid_response"}


def summarize(usb: dict, core: dict, mobilecli: dict) -> dict:
    ready = (usb.get("physical_iphone_usb_present") is True
             and core.get("physical_wired_tunnel_available") is True
             and mobilecli.get("mobilecli_real_discovered") is True)
    return {
        "usb": usb,
        "coredevice": core,
        "mobilecli": mobilecli,
        "usb_readonly_candidate": ready,
        "physical_ui_control_verified": False,
        "next_step": ("Confirm explicit user authorization before any "
                      "MobileCLI UI observation or tap; this is discovery only."),
    }


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--require-usb-candidate", action="store_true")
    args = p.parse_args()
    result = summarize(usb_probe(), coredevice_probe(), mobilecli_probe())
    print(json.dumps(result, sort_keys=True))
    return 2 if args.require_usb_candidate and not result["usb_readonly_candidate"] else 0


if __name__ == "__main__":
    sys.exit(main())
