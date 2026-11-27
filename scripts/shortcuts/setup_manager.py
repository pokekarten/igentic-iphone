#!/usr/bin/env python3
"""Idempotent local Shortcut setup. No automatic import, model calls or UI consent.

Existing artifacts are never overwritten. Cloud staging is opt-in. The system
Shortcuts library is queried for only the exact test name; other names are not
returned. A signed file's presence is not proof of signature or import.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import stat
import subprocess
import sys
import tempfile

from status_loop_factory import NAME, app_identity, check_metadata, workflow, write_private_candidate

UNSIGNED = "iGentic-status-unsigned.shortcut"
SIGNED = NAME + ".shortcut"
MANIFEST = "shortcut-build-manifest.json"
MAX_BYTES = 16 * 1024 * 1024


def read_artifact(path):
    # Open once and validate the opened inode, not a separate path lookup.
    # Nonblocking open prevents an unexpected FIFO from hanging preflight.
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, "rb") as artifact:
        info = os.fstat(artifact.fileno())
        if not stat.S_ISREG(info.st_mode):
            raise ValueError("Artifact missing or not a regular file")
        if info.st_size > MAX_BYTES:
            raise ValueError("Artifact too large")
        data = artifact.read(MAX_BYTES + 1)
        if len(data) > MAX_BYTES:
            raise ValueError("Artifact too large")
        return data


def digest(data):
    return hashlib.sha256(data).hexdigest()


def manifest_for(unsigned, signed):
    return {"schema": 1, "unsignedSHA256": digest(unsigned),
            "signedSHA256": digest(signed)}


def stage(signed, destination):
    if destination.exists() or destination.is_symlink():
        if read_artifact(destination) != signed:
            raise ValueError("Cloud destination conflict; no overwrite")
        return False
    write_private_candidate(destination, signed)
    return True


def next_gate(report):
    for key, gate in (("appMetadataReady", "rebuild_app"),
                      ("unsignedMatchesBuild", "prepare_candidate"),
                      ("signedArtifactPresent", "sign_candidate"),
                      ("cloudFileMatches", "stage_cloud_file"),
                      ("cloudUploadVerified", "verify_cloud_upload"),
                      ("macShortcutListed", "verify_system_import")):
        if report[key] is not True:
            return gate
    return "verify_physical_two_turn_loop"


def library_status():
    r = subprocess.run(["shortcuts", "list"], capture_output=True, text=True, timeout=30)
    if r.returncode:
        return None
    return NAME in r.stdout.splitlines()


def cloud_status(path):
    # Foundation returns the exact item's metadata only; no names or error text.
    code = ('import Foundation; let u=URL(fileURLWithPath:CommandLine.arguments[1]); '
            'let r=try u.resourceValues(forKeys:[.isUbiquitousItemKey,'
            '.ubiquitousItemIsUploadedKey,.ubiquitousItemUploadingErrorKey]); '
            'print(r.isUbiquitousItem == true && r.ubiquitousItemIsUploaded == true '
            '&& r.ubiquitousItemUploadingError == nil ? "yes" : "no")')
    r = subprocess.run(["swift", "-e", code, str(path)], capture_output=True, text=True, timeout=45)
    return r.stdout.strip() == "yes" if r.returncode == 0 else None


def inspect(app, local, cloud, *, prepare=False, publish=False):
    meta = json.loads((app / "Metadata.appintents/extract.actionsdata").read_text())
    check_metadata(meta)
    bundle, team = app_identity(app)
    expected = plistlib.dumps(workflow(meta, bundle, team), fmt=plistlib.FMT_BINARY)
    unsigned, signed, manifest = (local / n for n in (UNSIGNED, SIGNED, MANIFEST))
    destination = cloud / SIGNED
    report = {"appMetadataReady": True, "unsignedMatchesBuild": False,
              "signedArtifactPresent": False, "signedArtifactRecorded": False,
              "cloudFileMatches": False, "cloudUploadVerified": None,
              "macShortcutListed": None, "physicalVerified": False,
              "importAttempted": False, "newUnsigned": False,
              "newSigned": False, "newCloudCopy": False}
    if prepare:
        local.mkdir(mode=0o700, parents=True, exist_ok=True)
        if local.is_symlink() or stat.S_IMODE(local.stat().st_mode) & 0o077:
            raise ValueError("Local artifact directory must be private")
        if not unsigned.exists() and not unsigned.is_symlink():
            write_private_candidate(unsigned, expected)
            report["newUnsigned"] = True
    if unsigned.exists() or unsigned.is_symlink():
        report["unsignedMatchesBuild"] = read_artifact(unsigned) == expected
        if not report["unsignedMatchesBuild"]:
            raise ValueError("Unsigned artifact differs from current app; no overwrite")
    if prepare and not signed.exists() and not signed.is_symlink():
        if not report["unsignedMatchesBuild"] or manifest.exists() or manifest.is_symlink():
            raise ValueError("Inconsistent local artifact state")
        # Sign in a private temporary directory, then publish exclusively.
        with tempfile.TemporaryDirectory(dir=local) as tmp:
            out = Path(tmp) / SIGNED
            r = subprocess.run(["shortcuts", "sign", "--mode", "people-who-know-me",
                                "--input", str(unsigned), "--output", str(out)],
                               capture_output=True, timeout=60)
            if r.returncode:
                raise ValueError("Apple signing failed")
            data = read_artifact(out)
            if not data:
                raise ValueError("Empty signed artifact")
            write_private_candidate(signed, data)
            write_private_candidate(manifest, json.dumps(manifest_for(expected, data)).encode())
            report["newSigned"] = True
    if signed.exists() or signed.is_symlink():
        data = read_artifact(signed)
        if not data:
            raise ValueError("Empty signed artifact")
        report["signedArtifactPresent"] = True
        if manifest.exists() or manifest.is_symlink():
            report["signedArtifactRecorded"] = json.loads(read_artifact(manifest)) == manifest_for(expected, data)
            if not report["signedArtifactRecorded"]:
                raise ValueError("Artifact manifest mismatch")
        if publish:
            if not report["unsignedMatchesBuild"] or not report["signedArtifactRecorded"]:
                raise ValueError("Cannot publish unrecorded artifact; inspect existing file separately")
            if cloud.is_symlink() or not cloud.parent.is_dir():
                raise ValueError("Cloud directory unavailable")
            cloud.mkdir(exist_ok=True)
            report["newCloudCopy"] = stage(data, destination)
        if destination.exists() or destination.is_symlink():
            report["cloudFileMatches"] = read_artifact(destination) == data
            if report["cloudFileMatches"]:
                report["cloudUploadVerified"] = cloud_status(destination)
    report["macShortcutListed"] = library_status()
    report["nextGate"] = next_gate(report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--local", type=Path, required=True)
    parser.add_argument("--cloud", type=Path, required=True)
    parser.add_argument("--prepare", action="store_true", help="Generate/sign missing local artifacts")
    parser.add_argument("--publish", action="store_true", help="Stage recorded signed artifact to private iCloud folder")
    args = parser.parse_args()
    try:
        report = inspect(args.app, args.local, args.cloud, prepare=args.prepare, publish=args.publish)
        print(json.dumps(report, sort_keys=True))
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        print(json.dumps({"status": "blocked", "physicalVerified": False,
                          "importAttempted": False, "nextGate": "inspect_local_artifacts"}))
        return 2


if __name__ == "__main__":
    sys.exit(main())
