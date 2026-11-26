#!/usr/bin/env python3
"""Run the already-installed isolated iGentic Model Lab; never install/replace an app.

The explicit device identifier is used only for devicectl, never written to a
receipt. This command launches one candidate at a time; it does not attest
hardware or installed binary identity. Run from a Mac with a paired iPhone
and compatible, already-signed/installed lab. The owner must keep the device
available. No production tool dispatch.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import json
import select
import subprocess
import time

from physical_classifier_receipt import REGISTRY, normalize

LAB_BUNDLE = "de.bos.igentic.diagnostics"
LAUNCH = {
    "qwen3": ("--qwen-classification-probe", "qwen3-06b"),
    "lfm25": ("--lfm-research-probe", "lfm25-350m"),
    "qwen35": ("--qwen35-classification-probe", "qwen35-08b"),
    "granite350": ("--granite350-classification-probe", "granite350"),
    "minicpm5": ("--minicpm5-classification-probe", "minicpm5-1b"),
    "falcon90": ("--falcon90-classification-probe", "falcon90"),
    "smol135": ("--smol135-classification-probe", "smol135"),
}

def collect(device: str, candidate: str):
    prefix = REGISTRY[candidate][0]
    cmd = ["xcrun", "devicectl", "device", "process", "launch", "--device", device,
           "--timeout", "20", "--terminate-existing", "--console", LAB_BUNDLE,
           "--", *LAUNCH[candidate]]
    start = time.monotonic()
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    buf = b""
    lines = []
    end = start + 35
    try:
        while time.monotonic() < end:
            if select.select([proc.stdout], [], [], 1)[0]:
                chunk = os.read(proc.stdout.fileno(), 4096)
                if not chunk:
                    break
                buf += chunk
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    if len(line) > 65536:
                        raise ValueError("oversized transport line")
                    line = line.rstrip(b"\r")
                    if line.startswith((prefix + "_").encode()):
                        lines.append(line.decode("ascii"))
                        if len(lines) > 15:
                            raise ValueError("unexpected extra receipt")
                if len(buf) > 65536:
                    raise ValueError("oversized transport line")
                if any(x.startswith(prefix + "_RESEARCH=") for x in lines):
                    break
            elif proc.poll() is not None:
                break
    finally:
        if proc.poll() is None:
            proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
    raw = "\n".join(lines) + "\n"
    result = normalize(candidate, raw)
    result["launch_and_cleanup_ms"] = round((time.monotonic() - start) * 1000)
    return raw, result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--candidate", action="append", choices=REGISTRY)
    args = parser.parse_args()
    candidates = args.candidate or list(REGISTRY)
    if len(candidates) != len(set(candidates)):
        parser.error("duplicate candidate")
    args.output.mkdir(mode=0o700, parents=True, exist_ok=False)
    failures = 0
    for candidate in candidates:
        try:
            raw, result = collect(args.device, candidate)
        except (ValueError, OSError, UnicodeError) as exc:
            # Do not publish arbitrary devicectl or model text.
            print(json.dumps({"candidate": candidate, "status": "receipt_rejected", "error_type": type(exc).__name__}))
            failures += 1
            continue
        (args.output / (candidate + ".receipt.txt")).write_text(raw)
        (args.output / (candidate + ".json")).write_text(json.dumps(result, sort_keys=True, indent=2) + "\n")
        print(json.dumps({"candidate": candidate, "status": "completed", "summary": result["summary"]}, sort_keys=True))
    return 2 if failures else 0

if __name__ == "__main__":
    raise SystemExit(main())
