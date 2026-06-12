#!/usr/bin/env python3
"""Print a concise, dependency-free validation summary for contributors and CI logs.

This script is intentionally read-only. It does not execute Swift commands,
perform network calls, write files or inspect private data. It only checks
repository structure signals that are safe to summarize before a human or CI
runs the canonical validation commands.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = [
    "README.md",
    "PROJECT_STATE.md",
    "AGENTS.md",
    "ROADMAP.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "docs/VALIDATION.md",
    "docs/GITHUB_CONTROL.md",
    "docs/WORKFLOWS.md",
    "scripts/validate_repo_structure.py",
    "ios/Package.swift",
    "ios/Sources/AgentCore/PolicyEngine.swift",
    "ios/Tests/AgentCoreTests/SmokeTests.swift",
]

FORBIDDEN_PATH_HINTS = [
    ".env",
    ".p12",
    ".mobileprovision",
    "id_rsa",
    "private_key",
    "secret",
]

CANONICAL_COMMANDS = [
    "python3 scripts/validate_repo_structure.py",
    "cd ios && swift test",
    "cd ios && swift build",
]


@dataclass(frozen=True)
class CheckResult:
    name: str
    ok: bool
    detail: str


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def check_required_files() -> CheckResult:
    missing = [path for path in REQUIRED_FILES if not (ROOT / path).exists()]
    if missing:
        return CheckResult("required files", False, "missing: " + ", ".join(missing))
    return CheckResult("required files", True, f"{len(REQUIRED_FILES)} expected files present")


def check_forbidden_paths() -> CheckResult:
    matches: list[str] = []
    for path in ROOT.rglob("*"):
        if ".git" in path.parts or not path.is_file():
            continue
        lowered = path.name.lower()
        if any(hint in lowered for hint in FORBIDDEN_PATH_HINTS):
            matches.append(rel(path))
    if matches:
        return CheckResult("forbidden path hints", False, ", ".join(matches))
    return CheckResult("forbidden path hints", True, "no obvious secret/signing-file names found")


def check_markdown_nonempty() -> CheckResult:
    empty = [rel(path) for path in ROOT.rglob("*.md") if ".git" not in path.parts and path.read_text(encoding="utf-8").strip() == ""]
    if empty:
        return CheckResult("markdown files", False, "empty: " + ", ".join(empty))
    return CheckResult("markdown files", True, "all markdown files are non-empty")


def check_workflows_present() -> CheckResult:
    workflow_dir = ROOT / ".github" / "workflows"
    workflows = sorted(path.name for path in workflow_dir.glob("*.yml")) if workflow_dir.exists() else []
    if not workflows:
        return CheckResult("workflows", False, "no .github/workflows/*.yml files found")
    return CheckResult("workflows", True, ", ".join(workflows))


def print_result(result: CheckResult) -> None:
    icon = "PASS" if result.ok else "FAIL"
    print(f"- {icon}: {result.name}: {result.detail}")


def main() -> int:
    checks = [
        check_required_files(),
        check_forbidden_paths(),
        check_markdown_nonempty(),
        check_workflows_present(),
    ]

    print("# Validation Summary")
    print()
    print(f"Repository root: {ROOT}")
    print()
    print("## Safe preflight checks")
    for check in checks:
        print_result(check)

    print()
    print("## Canonical validation commands")
    for command in CANONICAL_COMMANDS:
        print(f"- {command}")

    print()
    print("## Notes")
    print("- This summary does not replace the canonical validation commands.")
    print("- It does not execute Swift, access networks, write files or read private user data.")

    return 0 if all(check.ok for check in checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
