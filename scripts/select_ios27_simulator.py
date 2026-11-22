#!/usr/bin/env python3
"""Select a compatible iPhone simulator on iOS 27 or later, fail closed."""
from __future__ import annotations

import json
import re
import sys
from typing import Any


IOS_RUNTIME = re.compile(r"(?:^|\.)iOS-(\d+)(?:-(\d+))?(?:-(\d+))?$")


def select_compatible_iphone(payload: dict[str, Any]) -> tuple[str, str, str]:
    """Return (UDID, device name, runtime); never choose an iOS 26 runtime."""
    candidates: list[tuple[tuple[int, int, int], str, str, str]] = []
    devices_by_runtime = payload.get("devices", {})
    if not isinstance(devices_by_runtime, dict):
        raise ValueError("Invalid CoreSimulator device list")

    for runtime, devices in devices_by_runtime.items():
        if not isinstance(runtime, str) or not isinstance(devices, list):
            continue
        match = IOS_RUNTIME.search(runtime)
        if match is None:
            continue
        version = tuple(int(v or 0) for v in match.groups())
        if version[0] < 27:
            continue
        for device in devices:
            if not isinstance(device, dict):
                continue
            name = device.get("name")
            udid = device.get("udid")
            if (
                device.get("isAvailable") is True
                and isinstance(name, str)
                and name.startswith("iPhone")
                and isinstance(udid, str)
                and udid
            ):
                candidates.append((version, name, udid, runtime))

    if not candidates:
        raise ValueError("No iOS 27+ iPhone simulator found")
    candidates.sort()
    _, name, udid, runtime = candidates[-1]
    return udid, name, runtime


def main() -> int:
    try:
        udid, name, runtime = select_compatible_iphone(json.load(sys.stdin))
    except (ValueError, json.JSONDecodeError) as error:
        print(f"Simulator selection failed: {error}", file=sys.stderr)
        return 1
    print(udid)
    print(f"Selected simulator: {name} ({runtime})", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
