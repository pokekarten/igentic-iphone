#!/usr/bin/env python3
"""Strict offline verification of a pinned on-device open-weight artifact.

The verifier never downloads or executes a model. It accepts a manifest plus a
model directory, and exits nonzero unless the file matches the pinned identity.
"""

import argparse
import hashlib
import json
import os
import re
import stat
from pathlib import Path

REQUIRED_FIELDS = {"model_id", "filename", "sha256", "size_bytes", "source_revision", "license_reviewed"}
HASH_RE = re.compile(r"[0-9a-f]{64}\Z")
REV_RE = re.compile(r"[0-9a-f]{40}\Z")


class ArtifactRejected(ValueError):
    """Non-actionable artifact; no inference is authorized."""


def verify(manifest_path: Path, model_directory: Path) -> dict:
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ArtifactRejected("unreadable manifest") from exc
    if not isinstance(manifest, dict) or set(manifest) != REQUIRED_FIELDS:
        raise ArtifactRejected("invalid manifest fields")
    model_id = manifest["model_id"]
    filename = manifest["filename"]
    sha256 = manifest["sha256"]
    size_bytes = manifest["size_bytes"]
    revision = manifest["source_revision"]
    if not isinstance(model_id, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/-]{0,127}", model_id):
        raise ArtifactRejected("invalid model identity")
    if not isinstance(filename, str) or filename in (".", "..") or Path(filename).name != filename or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,255}", filename):
        raise ArtifactRejected("invalid artifact filename")
    if not isinstance(sha256, str) or not HASH_RE.fullmatch(sha256):
        raise ArtifactRejected("invalid sha256")
    if not isinstance(revision, str) or not REV_RE.fullmatch(revision):
        raise ArtifactRejected("source revision must be a pinned 40-character commit")
    if type(size_bytes) is not int or not 0 < size_bytes <= 20_000_000_000:
        raise ArtifactRejected("invalid artifact size")
    if manifest["license_reviewed"] is not True:
        raise ArtifactRejected("model license review required")
    if model_directory.is_symlink() or not model_directory.is_dir():
        raise ArtifactRejected("invalid model directory")
    file_path = model_directory / filename
    try:
        metadata = file_path.lstat()
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_size != size_bytes:
            raise ArtifactRejected("not a regular file of expected size")
        digest = hashlib.sha256()
        # O_NOFOLLOW prevents a symlink swap between lstat and open.
        fd = os.open(file_path, os.O_RDONLY | os.O_NOFOLLOW)
        with os.fdopen(fd, "rb") as model_file:
            opened = os.fstat(model_file.fileno())
            if (not stat.S_ISREG(opened.st_mode)
                    or opened.st_dev != metadata.st_dev
                    or opened.st_ino != metadata.st_ino
                    or opened.st_size != size_bytes):
                raise ArtifactRejected("artifact changed before verification")
            while chunk := model_file.read(1024 * 1024):
                digest.update(chunk)
            if os.fstat(model_file.fileno()).st_size != size_bytes:
                raise ArtifactRejected("artifact size changed while verifying")
    except OSError as exc:
        raise ArtifactRejected("artifact inaccessible") from exc
    if digest.hexdigest() != sha256:
        raise ArtifactRejected("artifact SHA-256 mismatch")
    return {"model_id": model_id, "sha256": sha256, "size_bytes": size_bytes, "verified": True}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--model-directory", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = verify(args.manifest, args.model_directory)
    except ArtifactRejected as exc:
        print(json.dumps({"verified": False, "reason": str(exc)}))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
