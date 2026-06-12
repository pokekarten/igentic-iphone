#!/usr/bin/env python3
"""Validate that the starter repo keeps its controller-oriented structure."""
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = [
    "AGENTS.md",
    "PROJECT_STATE.md",
    "README.md",
    "docs/CODEX_NEXT_TASK.md",
    "docs/SPARSAMKEIT.md",
    "docs/SOURCE_VERIFICATION.md",
    "ios/Package.swift",
    "ios/Sources/AgentCore/DataClassification.swift",
    "ios/Sources/AgentCore/PolicyEngine.swift",
    "ios/Sources/AgentCore/TaskRouter.swift",
    "ios/Sources/AgentCore/AuditLog.swift",
    "ios/Sources/AgentCore/ApprovalManager.swift",
]

FORBIDDEN_PARTS = {
    ".DS_Store",
    "xcuserdata",
    "DerivedData",
    ".env",
    ".env.local",
    ".build",
}


def main() -> int:
    missing = [path for path in REQUIRED_FILES if not (ROOT / path).exists()]
    if missing:
        print("Missing required files:")
        for path in missing:
            print(f"- {path}")
        return 1

    forbidden = []
    for path in ROOT.rglob("*"):
        if any(part in FORBIDDEN_PARTS for part in path.parts):
            forbidden.append(path.relative_to(ROOT))

    if forbidden:
        print("Forbidden files found:")
        for path in forbidden:
            print(f"- {path}")
        return 1

    print("Repo structure looks good.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
