#!/usr/bin/env python3
"""Opt-in, SHA-pinned ARTEMIS iOS host integration for the iGentic research app.

This is developer-machine tooling, NOT an iPhone runtime or a security approval
service. It never grants Xcode consent, signs a device app, or saves private data.
"""
from __future__ import annotations

import argparse
import json
import platform
import shutil
import subprocess
import sys
from pathlib import Path

UPSTREAM_REPOSITORY = "https://github.com/banggaoo/artemis.git"
UPSTREAM_BRANCH = "feat/ios-support"
UPSTREAM_SHA = "31df538d3e8a0ff11e735a4e2c04e6e0936fc68f"
UPSTREAM_PR = "https://github.com/google/artemis/pull/175"
DEFAULT_CHECKOUT = Path.home() / ".cache" / "igentic" / "artemis-ios-pr175"
DIAGNOSTIC_APP = "org.example.iGenticDiagnostics"
SAFE_TASK = (
    "Test only the iGentic Diagnostics app (" + DIAGNOSTIC_APP + "). "
    "Inspect the synthetic Safety and Explore diagnostic views, then report "
    "visible UI problems and screenshots. Do not open other applications, "
    "modify settings, use personal accounts, or access private user data."
)
PROJECT_FILE = (
    Path(__file__).resolve().parents[1]
    / "app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj"
)


def command_output(command: list[str]) -> tuple[int, str]:
    try:
        completed = subprocess.run(
            command, check=False, capture_output=True, text=True, timeout=12
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        return 1, str(error)
    return completed.returncode, (completed.stdout or completed.stderr).strip()


def revision(path: Path) -> str | None:
    if not (path / ".git").exists():
        return None
    result, output = command_output(["git", "-C", str(path), "rev-parse", "HEAD"])
    return output if result == 0 else None


def is_pinned(path: Path) -> bool:
    if revision(path) != UPSTREAM_SHA:
        return False
    # A matching commit is not enough if its tracked source was edited after
    # checkout. Untracked local provider configuration is not evaluated here.
    code, changes = command_output(
        ["git", "-C", str(path), "status", "--porcelain", "--untracked-files=no"]
    )
    return code == 0 and changes == ""


def require_simulator_target(device: str) -> None:
    """Refuse to select a physical device without the explicit --physical mode."""
    code, inventory = command_output(
        ["xcrun", "simctl", "list", "devices", "available", "--json"]
    )
    if code != 0:
        raise ValueError("Cannot confirm simulator inventory; refusing device control.")
    try:
        devices = [
            entry
            for group in json.loads(inventory).get("devices", {}).values()
            for entry in group
        ]
    except (ValueError, AttributeError, TypeError):
        raise ValueError("Simulator inventory is not valid JSON.") from None
    if device == "booted":
        if len([item for item in devices if item.get("state") == "Booted"]) != 1:
            raise ValueError("Exactly one booted simulator is required.")
    elif not any(item.get("udid") == device for item in devices):
        raise ValueError("Device is not an available iOS simulator; use explicit --physical.")


def require_pinned(path: Path) -> None:
    if not is_pinned(path):
        raise ValueError(
            "ARTEMIS is missing or is not at the reviewed, pinned PR commit. "
            "Use 'fetch' in a separate directory; never run a drifting branch."
        )


def fetch(path: Path) -> None:
    if path.exists():
        if is_pinned(path):
            print("Already pinned: " + str(path))
            return
        raise ValueError("Destination already exists and is not pinned: " + str(path))
    if shutil.which("git") is None:
        raise ValueError("git is required for fetch.")
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "git", "clone", "--no-checkout", "--filter=blob:none",
            "--single-branch", "--branch", UPSTREAM_BRANCH,
            UPSTREAM_REPOSITORY, str(path),
        ],
        check=True,
    )
    subprocess.run(
        ["git", "-C", str(path), "checkout", "--detach", UPSTREAM_SHA], check=True
    )
    require_pinned(path)
    print("Pinned source fetched; no upstream code has been executed: " + str(path))


def read_xcode_major() -> int | None:
    code, output = command_output(["xcodebuild", "-version"])
    if code != 0:
        return None
    for line in output.splitlines():
        if line.startswith("Xcode "):
            try:
                return int(line.split()[1].split(".")[0])
            except (IndexError, ValueError):
                return None
    return None


def doctor(path: Path) -> dict[str, object]:
    return {
        "platform": platform.system(),
        "xcode_major": read_xcode_major() if platform.system() == "Darwin" else None,
        "xcode_27_or_newer": platform.system() == "Darwin"
        and (read_xcode_major() or 0) >= 27,
        "uv_available": shutil.which("uv") is not None,
        "git_available": shutil.which("git") is not None,
        "source_pinned": is_pinned(path),
        "source_path": str(path),
        "upstream_pr": UPSTREAM_PR,
        "upstream_sha": UPSTREAM_SHA,
        "ios_project_exists": PROJECT_FILE.is_dir(),
        "notes": "Real iPhone use additionally needs pairing, Developer Mode, "
        "explicit Xcode consent and a signed WebDriverAgent; this check does not grant any.",
    }


def build_command(args: argparse.Namespace) -> list[str]:
    if args.device == "":
        raise ValueError("A device identifier is required.")
    if args.physical and args.device == "booted":
        raise ValueError("A physical device requires an explicit UDID.")
    command = [
        "uv", "run", "artemis", "run", SAFE_TASK,
        "--platform", "ios", "--standalone",
        "--device-serial", args.device,
        "--profile", args.profile,
        "--ios-workspace", str(PROJECT_FILE),
    ]
    if args.app_path:
        command.extend(["--app-path", str(Path(args.app_path).expanduser().resolve())])
    return command


def mcp_config(path: Path) -> str:
    require_pinned(path)
    python = path / ".venv/bin/python"
    # This is informational; no configuration file is modified.
    return (
        "[mcp_servers.artemis_ios]\n"
        + 'command = ' + json.dumps(str(python)) + "\n"
        + 'args = ["-m", "mcp_server"]\n'
        + 'cwd = ' + json.dumps(str(path)) + "\n"
        + "\n[mcp_servers.artemis_ios.env]\n"
        + 'PYTHONUNBUFFERED = "1"\n'
        + 'PYTHONPATH = ' + json.dumps(str(path)) + "\n"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkout", type=Path, default=DEFAULT_CHECKOUT)
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("fetch", help="Fetch exact unmerged upstream PR revision; no install")
    sub.add_parser("doctor", help="Report host prerequisites without modification")
    sub.add_parser("mcp-config", help="Print an optional Codex MCP configuration")
    for name in ("plan", "run"):
        p = sub.add_parser(name, help=("Preview" if name == "plan" else "Execute") + " a synthetic iOS UI test")
        p.add_argument("--device", default="booted", help="Simulator UDID, booted, or physical UDID")
        p.add_argument("--physical", action="store_true", help="Explicitly select an owned physical iPhone")
        p.add_argument("--profile", choices=("flash", "pro"), default="flash")
        p.add_argument("--app-path", help="Optional prebuilt and appropriately signed .app")
        if name == "run":
            p.add_argument("--execute", action="store_true", help="Explicit consent for device input")
            p.add_argument("--acknowledge-model-io", action="store_true",
                           help="Acknowledge the configured model provider may receive UI screenshots")
    args = parser.parse_args(argv)
    path = args.checkout.expanduser().resolve()
    try:
        if args.action == "fetch":
            fetch(path)
        elif args.action == "doctor":
            print(json.dumps(doctor(path), indent=2))
        elif args.action == "mcp-config":
            print(mcp_config(path), end="")
        elif args.action in ("plan", "run"):
            command = build_command(args)
            print(json.dumps({"cwd": str(path), "argv": command}, indent=2))
            if args.action == "run":
                if not args.execute or not args.acknowledge_model_io:
                    raise ValueError("Run requires --execute and --acknowledge-model-io.")
                if not args.physical:
                    require_simulator_target(args.device)
                require_pinned(path)
                checks = doctor(path)
                if not checks["xcode_27_or_newer"] or not checks["uv_available"]:
                    raise ValueError("macOS, Xcode 27+, and uv are required.")
                if not checks["ios_project_exists"]:
                    raise ValueError("The iGentic Xcode project is missing.")
                # The user owns provider configuration, signing, Xcode approvals,
                # pairing and WDA. No subprocess shell invocation or implicit setup.
                return subprocess.run(command, cwd=path, check=False).returncode
        return 0
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"ARTEMIS iOS: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
