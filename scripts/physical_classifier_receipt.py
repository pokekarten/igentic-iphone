#!/usr/bin/env python3
"""Normalize the existing native V0 classifier receipt, without retaining raw logs.

This adapter validates a completed metadata-only receipt; it does not attest
hardware identity, build identity, or infer missing resource measurements.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PINS = ROOT / "ios/Sources/AgentCore/PinnedMLXSnapshot.swift"
FIXTURES = ROOT / "Tools/MLXModelLab/Sources/MLXProbe/LFMResearch.swift"
REGISTRY = {
    "qwen3": ("QWEN_CLASS", "qwenFiles", "mlx-community/Qwen3-0.6B-4bit", "73e3e38d981303bc594367cd910ea6eb48349da8"),
    "lfm25": ("LFM", "lfmResearchFiles", "LiquidAI/LFM2.5-350M-MLX-4bit", "f6cb4e006bb7a2d8a6afa14ec0a53e0586f65a5b"),
    "qwen35": ("QWEN35_CLASS", "qwen35ResearchFiles", "mlx-community/Qwen3.5-0.8B-4bit", "da28692b5f139cb0ec58a356b437486b7dac7462"),
    "granite350": ("GRANITE350_CLASS", "granite350ResearchFiles", "mlx-community/granite-4.0-h-350m-4bit", "2b96c1f68e5349bcaec2a498a68cc177537e46d1"),
    "minicpm5": ("MINICPM5_CLASS", "miniCPM5ResearchFiles", "openbmb/MiniCPM5-1B-MLX", "c973e24a2c77861038301f4e27d1b34a5931fc91"),
}

def manifest(candidate):
    prefix, name, model, revision = REGISTRY[candidate]
    block = PINS.read_text().split(f"static let {name}: [Entry] = [", 1)[1].split("    ]", 1)[0]
    entries = re.findall(r'\.init\(name: "([^"]+)", bytes: ([0-9]+), digest: "([a-f0-9]{64})"\)', block)
    if not entries or len(entries) != len({x[0] for x in entries}):
        raise ValueError("invalid native manifest")
    normalized = sorted((n, int(s), h) for n, s, h in entries)
    digest = hashlib.sha256(json.dumps(normalized, separators=(",", ":")).encode()).hexdigest()
    return prefix, model, revision, len(entries), sum(x[1] for x in normalized), digest

def normalize(candidate, text):
    prefix, model, revision, files, size, manifest_hash = manifest(candidate)
    # Exact whole lines only. Ignore transport chatter, never export it.
    lines = [line for line in text.splitlines() if line.startswith(prefix + "_")]
    if len(lines) != 15:
        raise ValueError("missing, duplicate or unexpected receipt lines")
    if lines[0] != f"{prefix}_INTEGRITY=verified; files={files}; bytes={size}":
        raise ValueError("artifact inventory mismatch")
    load = re.fullmatch(prefix + r"_LOAD=completed; milliseconds=([0-9]+)", lines[1])
    if not load:
        raise ValueError("missing load receipt")
    records = []
    for i, line in enumerate(lines[2:-1], 1):
        m = re.fullmatch(prefix + r"_CASE=([0-9]+); outcome=(pass|reject); tokens=([0-9]+); milliseconds=([0-9]+)", line)
        if not m or int(m[1]) != i:
            raise ValueError("case sequence mismatch")
        tokens = int(m[3])
        passed = m[2] == "pass"
        if not 0 <= tokens <= 16 or (passed and not 1 <= tokens < 16):
            raise ValueError("invalid token budget or pass")
        records.append({"case": i, "language": "de" if i in (2,3,5,6,9,10) else "en",
                        "split": "development" if i <= 6 else "additional",
                        "passed": passed, "tokens": tokens, "elapsed_ms": int(m[4]),
                        "token_cap_reached": tokens == 16})
    total = sum(r["passed"] for r in records)
    holdout = sum(r["passed"] for r in records[6:])
    if lines[-1] != f"{prefix}_RESEARCH=completed; passed={total}; total=12; holdout={holdout}; actionsExecuted=0":
        raise ValueError("aggregate mismatch or nonzero actions")
    return {"schema": "igentic.physical.classifier.v0.receipt.v1",
            "model": model, "revision": revision, "artifact_manifest_sha256": manifest_hash,
            "artifact_files": files, "artifact_bytes": size,
            "reference_classifier_source_sha256": hashlib.sha256(FIXTURES.read_bytes()).hexdigest(),
            "receipt_sha256": hashlib.sha256(("\n".join(lines)+"\n").encode()).hexdigest(),
            "source": "native_metadata_receipt_not_hardware_attestation",
            "suite": "bilingual_ab_v0", "runtime": "mlx_swift", "status": "completed",
            "load_ms": int(load[1]), "actions_executed": 0, "cases": records,
            "summary": {"passed": total, "total": 12, "additional_passed": holdout,
                        "additional_total": 6, "token_caps": sum(r["token_cap_reached"] for r in records),
                        "median_case_ms": statistics.median(r["elapsed_ms"] for r in records),
                        "de_passed": sum(r["passed"] for r in records if r["language"] == "de"),
                        "en_passed": sum(r["passed"] for r in records if r["language"] == "en")},
            "unmeasured": ["peak_physical_footprint", "energy", "thermal", "prefill", "ttft"]}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", choices=REGISTRY)
    parser.add_argument("receipt", type=Path)
    args = parser.parse_args()
    try:
        result = normalize(args.candidate, args.receipt.read_text())
    except (ValueError, OSError, IndexError) as exc:
        parser.exit(2, f"invalid receipt: {exc}\n")
    print(json.dumps(result, sort_keys=True, allow_nan=False))

if __name__ == "__main__":
    main()
