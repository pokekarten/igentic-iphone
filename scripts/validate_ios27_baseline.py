#!/usr/bin/env python3
"""Fail closed if the release, simulator or Apple CI path targets pre-iOS 27."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def validate_ios27_baseline(root: Path = ROOT) -> list[str]:
    errors: list[str] = []

    def read(relative: str) -> str:
        try:
            return (root / relative).read_text(encoding="utf-8")
        except OSError:
            errors.append(f"Missing or unreadable file: {relative}")
            return ""

    manifest = read("ios/Package.swift")
    if not re.search(r"(?m)^// swift-tools-version:\s*6\.2\s*$", manifest):
        errors.append("ios/Package.swift must use Swift tools 6.2")
    if '.iOS("27.0")' not in manifest:
        errors.append("ios/Package.swift must set iOS 27.0 minimum")

    project = read("app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj/project.pbxproj")
    minimums = re.findall(r"\bIPHONEOS_DEPLOYMENT_TARGET\s*=\s*([^;]+);", project)
    if not minimums or any(value.strip() != "27.0" for value in minimums):
        errors.append("Every Xcode target/configuration must deploy on iOS 27.0")

    workflows = [
        ".github/workflows/ci-phase-0-validation.yml",
        ".github/workflows/ios-app-wrapper.yml",
        ".github/workflows/swift.yml",
        ".github/workflows/codeql-advanced.yml",
    ]
    for path in workflows:
        content = read(path)
        if "runs-on: xcode-27" not in content:
            errors.append(f"{path} must use the Xcode 27 runner")
        if re.search(r"runs-on:\s*(?:macos-15|macos-latest)\b|Xcode_26|Xcode 26", content):
            errors.append(f"{path} still uses an obsolete Apple build environment")

    phase = read(workflows[0])
    if "container: swift:6.2" not in phase:
        errors.append("Linux Swift CI must support the Swift tools 6.2 manifest")

    smoke = read("scripts/smoke-ios-simulator.sh")
    if "select_ios27_simulator.py" not in smoke:
        errors.append("Simulator smoke must use the fail-closed iOS 27 selector")

    return errors


if __name__ == "__main__":
    errors = validate_ios27_baseline()
    if errors:
        print("iOS 27 baseline regression:\n- " + "\n- ".join(errors), file=sys.stderr)
        raise SystemExit(1)
    print("iOS 27 baseline gate passed.")
