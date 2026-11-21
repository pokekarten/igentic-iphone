#!/usr/bin/env python3
"""Read-only Xcode physical-iPhone readiness preflight.

No pairing, unlock, software installation, device settings, or data reads.
Device identifiers are deliberately omitted from output.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

READY_STATES = {"connected"}
KNOWN_STATES = {"connected", "available", "unavailable", "disconnected", "offline", "paired", "unpaired"}


def classify(output: str) -> dict:
    """Parse the stable trailing columns of 'xcrun devicectl list devices'.

    Empty Hostname columns are permitted; never print an identifier.
    Simulator rows must not count as physical-device readiness.
    """
    physical = []
    simulated = 0
    for line in output.splitlines():
        cols = re.split(r"\s{2,}", line.strip())
        if len(cols) < 4:
            continue
        reality = cols[-1].lower()
        if reality == "simulated":
            simulated += 1
            continue
        if reality != "physical":
            continue
        # Columns at the end: identifier, state, model, reality.
        state = cols[-3].lower() if len(cols) >= 5 else "unknown"
        if state not in KNOWN_STATES:
            state = "unknown"
        physical.append(state)

    return {
        "physical_device_count": len(physical),
        "physical_states": sorted(physical),
        "simulator_count": simulated,
        "physical_test_ready": any(state in READY_STATES for state in physical),
        "verdict": (
            "ready_for_test_attempt"
            if any(state in READY_STATES for state in physical)
            else "physical_device_not_ready"
        ),
    }


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, help="Read saved devicectl output rather than contacting a device")
    parser.add_argument("--json", action="store_true", help="Emit identifier-free JSON")
    args = parser.parse_args(argv)

    if args.fixture:
        try:
            data = args.fixture.read_text(encoding="utf-8")
        except OSError:
            print("DEVICE_CHECK=fixture_unreadable", file=sys.stderr)
            return 3
    else:
        try:
            result = subprocess.run(
                ["xcrun", "devicectl", "list", "devices"],
                capture_output=True,
                text=True,
                timeout=20,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            print("DEVICE_CHECK=tool_unavailable", file=sys.stderr)
            return 3
        if result.returncode != 0:
            # Do not echo stderr; it may include device identifiers.
            print("DEVICE_CHECK=devicectl_failed", file=sys.stderr)
            return 3
        data = result.stdout

    report = classify(data)
    if args.json:
        print(json.dumps(report, sort_keys=True))
    else:
        print("PHYSICAL_IPHONE_READY=" + ("yes" if report["physical_test_ready"] else "no"))
        print("PHYSICAL_DEVICE_COUNT=" + str(report["physical_device_count"]))
        print("SIMULATOR_COUNT=" + str(report["simulator_count"]))
        print("PHYSICAL_DEVICE_STATES=" + ",".join(report["physical_states"]))
        print("VERDICT=" + report["verdict"])
    return 0 if report["physical_test_ready"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
