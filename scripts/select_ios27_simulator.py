#!/usr/bin/env python3
"""Select a compatible iPhone simulator on iOS 27 or later, fail closed."""
from __future__ import annotations

import argparse
import json
import re
import sys
from typing import Any


IOS_RUNTIME = re.compile(r"(?:^|\.)iOS-(\d+)(?:-(\d+))?(?:-(\d+))?$")


def select_compatible_iphone(
    payload: dict[str, Any], match_runtime: str | None = None
) -> tuple[str, str, str]:
    """Return a compatible simulator, optionally matching Xcode's major.minor.

    AppIntentsTesting may link against unavailable symbols in a newer iOS
    simulator. Never silently fall back to a mismatched simulator version.
    """
    expected = None
    if match_runtime is not None:
        match = re.fullmatch(r"(\d+)\.(\d+)(?:\.\d+)?", match_runtime)
        if not match or int(match.group(1)) < 27:
            raise ValueError("Invalid Xcode/iOS 27+ runtime version")
        expected = (int(match.group(1)), int(match.group(2)))
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
        if version[0] < 27 or (expected is not None and version[:2] != expected):
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
        if expected is not None:
            raise ValueError(
                f"No iOS {expected[0]}.{expected[1]} iPhone simulator found for "
                "matching Xcode; AppIntentsTesting must not use a different "
                "major.minor runtime (install a matching Xcode or iOS runtime)"
            )
        raise ValueError("No iOS 27+ iPhone simulator found")
    candidates.sort()
    _, name, udid, runtime = candidates[-1]
    return udid, name, runtime


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--match-runtime", metavar="MAJOR.MINOR",
                        help="Require iOS simulator major.minor equal to Xcode version")
    args = parser.parse_args()
    try:
        udid, name, runtime = select_compatible_iphone(
            json.load(sys.stdin), match_runtime=args.match_runtime
        )
    except (ValueError, json.JSONDecodeError) as error:
        print(f"Simulator selection failed: {error}", file=sys.stderr)
        return 1
    print(udid)
    print(f"Selected simulator: {name} ({runtime})", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
