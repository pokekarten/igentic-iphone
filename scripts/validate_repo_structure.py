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
    "ROADMAP.md",
    "GOVERNANCE.md",
    "LICENSE",
    "CONTRIBUTING.md",
    "CODE_OF_CONDUCT.md",
    "SECURITY.md",
    "SUPPORT.md",
    "MODEL_STRATEGY.md",
    "docs/CODEX_NEXT_TASK.md",
    "docs/CHATGPT_NEXT_TASK.md",
    "docs/SPARSAMKEIT.md",
    "docs/SOURCE_VERIFICATION.md",
    "docs/apple-api-review.md",
    "docs/local-runtime-review.md",
    "docs/brand/BRAND.md",
    "docs/brand/DESIGN_SYSTEM.md",
    "docs/brand/LOGO_BRIEF.md",
    "docs/brand/LOGO_USAGE.md",
    "docs/community/COMMUNITY_STRATEGY.md",
    "docs/community/COMMUNICATION_CHANNELS.md",
    "docs/community/SOCIAL_MEDIA_PLAYBOOK.md",
    "docs/community/CONTRIBUTOR_STARTER_GUIDE.md",
    "docs/community/GOOD_FIRST_ISSUES.md",
    "assets/brand/README.md",
    "assets/brand/logo-mark.svg",
    "assets/brand/logo-lockup.svg",
    "assets/brand/social-card.svg",
    ".github/PULL_REQUEST_TEMPLATE.md",
    ".github/dependabot.yml",
    ".github/workflows/ci-phase-0-validation.yml",
    ".github/workflows/pr-change-scope.yml",
    ".github/workflows/docs-consistency.yml",
    ".github/workflows/workflow-lint.yml",
    ".github/workflows/repo-audit.yml",
    ".github/workflows/pr-quality.yml",
    ".github/workflows/main-health.yml",
    ".github/workflows/control-dashboard.yml",
    ".github/workflows/project-control.yml",
    ".github/workflows/issue-triage.yml",
    ".github/ISSUE_TEMPLATE/config.yml",
    ".github/ISSUE_TEMPLATE/feature_request.md",
    ".github/ISSUE_TEMPLATE/design_feedback.md",
    ".github/ISSUE_TEMPLATE/device_test_report.md",
    ".github/ISSUE_TEMPLATE/good_first_issue.md",
    ".github/ISSUE_TEMPLATE/social_content.md",
    "ios/Package.swift",
    "ios/Sources/AgentCore/DataClassification.swift",
    "ios/Sources/AgentCore/PolicyEngine.swift",
    "ios/Sources/AgentCore/TaskRouter.swift",
    "ios/Sources/AgentCore/AuditLog.swift",
    "ios/Sources/AgentCore/ApprovalManager.swift",
    "ios/Sources/AgentCore/ApprovalReceipt.swift",
    "ios/Sources/AgentCore/ToolRegistry.swift",
    "ios/Sources/AgentCore/DelegationBroker.swift",
    "ios/Sources/AgentCore/MemoryStore.swift",
    "ios/Sources/AgentCore/SensitiveDataDetector.swift",
    "ios/Sources/AgentCore/RiskScorer.swift",
    "ios/Sources/AgentCore/ScenarioRunner.swift",
]

FORBIDDEN_PARTS = {
    ".DS_Store",
    "xcuserdata",
    "DerivedData",
    ".env",
    ".env.local",
    ".build",
}

REQUIRED_README_MARKERS = [
    "assets/brand/logo-lockup.svg",
    "docs/community/CONTRIBUTOR_STARTER_GUIDE.md",
    "docs/community/GOOD_FIRST_ISSUES.md",
    "GitHub-first, social-supported",
]

REQUIRED_PROJECT_STATE_MARKERS = [
    "Master brand: `iGentic`",
    "Community model: GitHub-first, social-supported",
    "docs/brand/BRAND.md",
    "docs/community/COMMUNITY_STRATEGY.md",
    "ApprovalReceipt",
]

BRAND_SVG_FILES = [
    "assets/brand/logo-mark.svg",
    "assets/brand/logo-lockup.svg",
    "assets/brand/social-card.svg",
]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def validate_required_files() -> list[str]:
    return [path for path in REQUIRED_FILES if not (ROOT / path).exists()]


def validate_no_forbidden_files() -> list[Path]:
    forbidden = []
    for path in ROOT.rglob("*"):
        if any(part in FORBIDDEN_PARTS for part in path.relative_to(ROOT).parts):
            forbidden.append(path.relative_to(ROOT))
    return forbidden


def validate_non_empty_required_files() -> list[str]:
    empty = []
    for path in REQUIRED_FILES:
        full_path = ROOT / path
        if full_path.exists() and full_path.is_file() and full_path.stat().st_size == 0:
            empty.append(path)
    return empty


def validate_readme_markers() -> list[str]:
    readme = read_text(ROOT / "README.md")
    return [marker for marker in REQUIRED_README_MARKERS if marker not in readme]


def validate_project_state_markers() -> list[str]:
    project_state = read_text(ROOT / "PROJECT_STATE.md")
    return [marker for marker in REQUIRED_PROJECT_STATE_MARKERS if marker not in project_state]


def validate_svg_accessibility() -> list[str]:
    invalid = []
    for path in BRAND_SVG_FILES:
        content = read_text(ROOT / path)
        required_snippets = ["<title", "<desc", "role=\"img\""]
        if any(snippet not in content for snippet in required_snippets):
            invalid.append(path)
    return invalid


def main() -> int:
    errors: list[str] = []

    missing = validate_required_files()
    if missing:
        errors.append("Missing required files:")
        errors.extend(f"- {path}" for path in missing)

    empty = validate_non_empty_required_files()
    if empty:
        errors.append("Required files are empty:")
        errors.extend(f"- {path}" for path in empty)

    forbidden = validate_no_forbidden_files()
    if forbidden:
        errors.append("Forbidden files found:")
        errors.extend(f"- {path}" for path in forbidden)

    readme_missing = validate_readme_markers()
    if readme_missing:
        errors.append("README.md is missing required project/community markers:")
        errors.extend(f"- {marker}" for marker in readme_missing)

    project_state_missing = validate_project_state_markers()
    if project_state_missing:
        errors.append("PROJECT_STATE.md is missing required status markers:")
        errors.extend(f"- {marker}" for marker in project_state_missing)

    svg_invalid = validate_svg_accessibility()
    if svg_invalid:
        errors.append("Brand SVG files must include <title>, <desc> and role=\"img\":")
        errors.extend(f"- {path}" for path in svg_invalid)

    if errors:
        print("\n".join(errors))
        return 1

    print("Repo structure looks good.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
