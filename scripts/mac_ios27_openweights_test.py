#!/usr/bin/env python3
"""No-download, identifier-free macOS/Xcode 27 preflight and iGentic build smoke.

Default performs only read-only checks. Explicit --phase build or simulator
builds the existing iGentic package; neither mode fetches model weights.
No user identifiers, provisioning data, API keys or full device lists are logged.
"""
from __future__ import annotations

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
from contextlib import contextmanager

from select_ios27_simulator import select_compatible_iphone
from pathlib import Path
from typing import NamedTuple

ROOT = Path(__file__).resolve().parents[1]
GIB = 1024 ** 3


class Check(NamedTuple):
    label: str
    ok: bool
    detail: str


def major_version(text: str, pattern: str) -> int | None:
    match = re.search(pattern, text, re.MULTILINE)
    return int(match.group(1)) if match else None


def run_capture(argv: list[str]) -> str:
    try:
        result = subprocess.run(
            argv, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            check=False, timeout=40,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise RuntimeError(f"{argv[0]} could not be queried: {type(error).__name__}") from error
    if result.returncode:
        raise RuntimeError(f"{argv[0]} returned non-zero status {result.returncode}")
    return result.stdout.strip()


def preflight() -> tuple[list[Check], dict[str, str]]:
    checks: list[Check] = []
    info: dict[str, str] = {}
    machine = platform.machine()
    os_name = platform.system()
    checks.append(Check("macOS host", os_name == "Darwin", os_name))
    checks.append(Check("Apple Silicon", machine == "arm64", machine))
    if os_name != "Darwin":
        return checks, info

    version = platform.mac_ver()[0]
    info["macos_version"] = version
    host_major = major_version(version, r"^(\d+)")
    # A macOS 26 host may cross-compile an iOS 27 app if Xcode 27 supports it,
    # but native macOS 27-only Core AI / FoundationModels providers cannot run.
    if host_major is not None and host_major < 27:
        print(f"NOTE: macOS {version} cannot prove native macOS 27 model inference; "
              "cross-compiling iOS still requires the iOS 27 SDK.")
    for label, command, regex, minimum in [
        ("Xcode 27", ["xcodebuild", "-version"], r"^Xcode (\d+)(?:[.]|$)", 27),
        ("Swift 6.4", ["swift", "--version"], r"Swift version (\d+)[.](\d+)", 6),
        ("iOS 27 SDK", ["xcrun", "--sdk", "iphoneos", "--show-sdk-version"], r"^(\d+)", 27),
    ]:
        try:
            output = run_capture(command)
            if label == "Swift 6.4":
                match = re.search(regex, output, re.MULTILINE)
                ok = bool(match and (int(match.group(1)), int(match.group(2))) >= (6, 4))
                detail = f"{match.group(1)}.{match.group(2)}" if match else "unknown"
            else:
                value = major_version(output, regex)
                ok = value is not None and value >= minimum
                detail = output.splitlines()[0] if output else "empty"
            checks.append(Check(label, ok, detail))
            info[label.replace(" ", "_").lower()] = detail
        except RuntimeError as error:
            checks.append(Check(label, False, str(error)))

    try:
        memory = int(run_capture(["sysctl", "-n", "hw.memsize"]))
        info["ram_gib"] = f"{memory / GIB:.1f}"
        # The unsigned compile smoke does not load model weights. Hosted
        # Xcode 27 runners may expose 7 GiB; reserve stricter RAM assessment
        # for a separate, opt-in local model inference acceptance run.
        checks.append(Check("Build host RAM >= 7 GiB", memory >= 7 * GIB, info["ram_gib"] + " GiB"))
        if memory < 8 * GIB:
            print("NOTE: below 8 GiB RAM; local model inference readiness NOT assessed")
    except (ValueError, RuntimeError) as error:
        checks.append(Check("Build host RAM >= 7 GiB", False, type(error).__name__))

    free = shutil.disk_usage(ROOT).free
    info["free_disk_gib"] = f"{free / GIB:.1f}"
    checks.append(Check("Free disk >= 5 GiB", free >= 5 * GIB, info["free_disk_gib"] + " GiB"))
    return checks, info


def command_plan(phase: str, scratch: Path) -> list[tuple[list[str], Path]]:
    if phase == "preflight":
        return []
    steps: list[tuple[list[str], Path]] = [
        ([sys.executable, "scripts/validate_repo_structure.py"], ROOT),
        ([sys.executable, "scripts/validate_ios27_baseline.py"], ROOT),
        ([sys.executable, "-m", "unittest", "discover", "-s", "scripts",
          "-p", "test_ios27_*.py"], ROOT),
        ([sys.executable, "-m", "unittest", "discover", "-s", "scripts",
          "-p", "test_mac_ios27_*.py"], ROOT),
        (["swift", "build", "--scratch-path", str(scratch / "swift-build"), "-j", "2"], ROOT / "ios"),
        (["swift", "test", "--scratch-path", str(scratch / "swift-build"), "-j", "2"], ROOT / "ios"),
        ([
            "xcodebuild", "-project", "app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj",
            "-scheme", "iGenticDiagnostics", "-configuration", "Debug",
            "-sdk", "iphonesimulator", "-destination", "generic/platform=iOS Simulator",
            "-derivedDataPath", str(scratch / "derived"), "CODE_SIGNING_ALLOWED=NO",
            "-jobs", "2", "build",
        ], ROOT),
    ]
    if phase == "simulator":
        steps.append((["bash", "scripts/smoke-ios-simulator.sh"], ROOT))
    return steps


@contextmanager
def isolated_simulator():
    """Use an existing simulator only as a template, never as a test target."""
    version = run_capture(["xcodebuild", "-version"])
    match = re.search(r"^Xcode (\d+\.\d+)", version, re.MULTILINE)
    if not match:
        raise ValueError("Xcode runtime version unavailable")
    payload = json.loads(run_capture(["xcrun", "simctl", "list", "devices", "available", "-j"]))
    source, _, runtime = select_compatible_iphone(payload, match.group(1))
    rows = [d for d in payload["devices"][runtime] if d.get("udid") == source]
    if len(rows) != 1:
        raise ValueError("Ambiguous simulator template")
    kind = rows[0].get("deviceTypeIdentifier", "")
    if not isinstance(kind, str) or not re.fullmatch(r"com\.apple\.CoreSimulator\.SimDeviceType\.iPhone-[A-Za-z0-9-]+", kind):
        raise ValueError("Invalid iPhone simulator template")
    created = run_capture(["xcrun", "simctl", "create", "iGentic-readiness-" + str(uuid.uuid4()), kind, runtime])
    if not re.fullmatch(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}", created) or created.lower() == source.lower():
        raise ValueError("Disposable simulator identity unverified")
    try:
        yield created
    finally:
        for operation in ("shutdown", "delete"):
            try:
                subprocess.run(["xcrun", "simctl", operation, created], capture_output=True, timeout=40, check=False)
            except (OSError, subprocess.TimeoutExpired):
                pass


def run_steps(phase: str, scratch: Path) -> list[dict[str, object]]:
    results: list[dict[str, object]] = []
    env = os.environ.copy()
    env.pop("IGENTIC_SIMULATOR_UDID", None)
    env.pop("IOS27_MATCHED_RUNTIME", None)
    env["APP_PATH"] = str(scratch / "derived/Build/Products/Debug-iphonesimulator/iGenticDiagnostics.app")
    env["SCREENSHOT_PATH"] = str(scratch / "iGenticDiagnostics-launch.png")
    env["BUNDLE_IDENTIFIER"] = "org.example.iGenticDiagnostics"
    for index, (argv, cwd) in enumerate(command_plan(phase, scratch), start=1):
        label = f"step {index}: {Path(argv[0]).name} {argv[1]}"
        print(f"Running {label}", flush=True)
        try:
            if argv == ["bash", "scripts/smoke-ios-simulator.sh"]:
                with isolated_simulator() as udid:
                    result = subprocess.run(argv, cwd=cwd, env={**env, "IGENTIC_SIMULATOR_UDID": udid}, check=False, timeout=900)
            else:
                result = subprocess.run(argv, cwd=cwd, env=env, check=False, timeout=900)
            status = int(result.returncode)
        except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
            status = 1
        results.append({"step": index, "command": label, "ok": status == 0})
        if status != 0:
            print(f"FAILED: {label} (exit {status})", file=sys.stderr)
            break
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--phase", choices=("preflight", "build", "simulator"), default="preflight",
        help="Default is read-only; build compiles; simulator additionally boots an iOS 27 simulator",
    )
    parser.add_argument(
        "--report", type=Path,
        help="Optional JSON report path (never contains account or device identifiers)",
    )
    args = parser.parse_args()
    if args.report and args.report.exists():
        print("Report path already exists; refusing to overwrite", file=sys.stderr)
        return 2

    checks, info = preflight()
    for item in checks:
        print(f"{'PASS' if item.ok else 'FAIL'}: {item.label}: {item.detail}")
    okay = bool(checks) and all(item.ok for item in checks)
    results: list[dict[str, object]] = []

    if okay and args.phase != "preflight":
        # Scratch data is removed on exit; Mac home directories and model
        # stores are never purged or modified.
        with tempfile.TemporaryDirectory(prefix="igentic-mac-ios27-") as tmp:
            results = run_steps(args.phase, Path(tmp))
        okay = all(item["ok"] for item in results) and bool(results)

    if args.report:
        report = {"phase": args.phase, "passed": okay,
                  "preflight": [x._asdict() for x in checks], "environment": info,
                  "steps": results, "model_inference_performed": False,
                  "physical_iphone_test_performed": False}
        try:
            args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        except OSError as error:
            print(f"Could not save report: {type(error).__name__}", file=sys.stderr)
            return 2

    if okay:
        print(f"PASS: macOS iOS-27 {args.phase} phase completed. No model weights downloaded.")
        return 0
    print("BLOCKED: resolve failed prerequisite or build step before proceeding", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
