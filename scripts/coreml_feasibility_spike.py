#!/usr/bin/env python3
"""Compile-only CoreML feasibility spike harness.

This script is intentionally conservative:
- it never downloads model weights
- it never performs network access
- it never touches runtime wiring
- it only records whether a local source artifact is available for a future
  compile-only conversion attempt

The current repository state does not include the candidate weights, so a run
from repo-only state should report `blocked`.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


@dataclass(frozen=True)
class SpikeResult:
    status: str
    model_name: str
    source_path: Optional[str]
    notes: str

    def to_markdown(self) -> str:
        return (
            "# CoreML conversion feasibility spike\n\n"
            f"- Status: **{self.status}**\n"
            f"- Model: {self.model_name}\n"
            f"- Local source path: {self.source_path or 'none'}\n"
            f"- Notes: {self.notes}\n"
        )


def evaluate(model_name: str, source_path: Optional[str]) -> SpikeResult:
    if not source_path:
        return SpikeResult(
            status="blocked",
            model_name=model_name,
            source_path=None,
            notes=(
                "No local model artifact was supplied. This repo also forbids "
                "network downloads for the spike, so conversion cannot be run."
            ),
        )

    path = Path(source_path)
    if not path.exists():
        return SpikeResult(
            status="blocked",
            model_name=model_name,
            source_path=str(path),
            notes="Supplied local source path does not exist.",
        )

    try:
        import coremltools  # type: ignore
    except Exception as exc:  # pragma: no cover - environment dependent
        return SpikeResult(
            status="blocked",
            model_name=model_name,
            source_path=str(path),
            notes=f"coremltools is unavailable in this environment: {exc}",
        )

    return SpikeResult(
        status="blocked",
        model_name=model_name,
        source_path=str(path),
        notes=(
            "Local artifact is present and coremltools imported successfully, "
            "but model-specific conversion logic is not defined in this harness. "
            "Use the report to record the eventual operator/graph outcome."
        ),
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-name", required=True)
    parser.add_argument("--source-path", default=None)
    parser.add_argument("--output", default=None)
    args = parser.parse_args()

    result = evaluate(args.model_name, args.source_path)
    markdown = result.to_markdown()

    if args.output:
        Path(args.output).write_text(markdown, encoding="utf-8")
    else:
        print(markdown)

    return 0 if result.status == "success" else 2


if __name__ == "__main__":
    raise SystemExit(main())
