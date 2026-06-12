#!/usr/bin/env python3
"""Render a Markdown control dashboard report from collected JSON files."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_JSON = Path("reports/latest-repo-state.json")
CI_JSON = Path("reports/latest-ci-runs.json")
OUT = Path("reports/latest-control-report.md")
BAD_CONCLUSIONS = {"failure", "cancelled", "timed_out", "action_required"}


def load(path: Path) -> tuple[dict[str, Any], str | None]:
    if not path.exists():
        return {}, f"Missing input file: {path}"
    try:
        return json.loads(path.read_text(encoding="utf-8")), None
    except json.JSONDecodeError as exc:
        return {}, f"Could not parse {path}: {exc}"


def as_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def row(values: list[Any]) -> str:
    return "| " + " | ".join(str(value).replace("\n", " ").strip() for value in values) + " |"


def table(headers: list[str], rows: list[list[Any]], empty: str) -> list[str]:
    if not rows:
        return [empty]
    return [row(headers), row(["---"] * len(headers)), *[row(values) for values in rows]]


def next_action(warnings: list[str], failed_runs: list[dict[str, Any]], issues: list[Any]) -> str:
    if warnings:
        return "Fix collection warnings first, then rerun the Control Dashboard workflow."
    if failed_runs:
        return "Inspect failing workflow logs, document the exact check, and apply the smallest safe fix."
    if any(isinstance(issue, dict) and issue.get("number") == 1 for issue in issues):
        return "Run Phase 0 CI Validation on latest main and record evidence before closing Issue #1."
    return "Choose the smallest safe open issue that does not add runtime actions or private-data handling."


def main() -> int:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    repo, repo_warning = load(REPO_JSON)
    ci, ci_warning = load(CI_JSON)
    warnings = [warning for warning in (repo_warning, ci_warning) if warning]

    repo_data = repo.get("data", {}) if isinstance(repo, dict) else {}
    ci_data = ci.get("data", {}) if isinstance(ci, dict) else {}
    env = repo.get("environment", {}) if isinstance(repo, dict) else {}

    commits = as_list(repo_data.get("latest_commits_oneline"))
    runs = as_list(ci_data.get("workflow_runs"))
    prs = as_list(repo_data.get("open_prs"))
    issues = as_list(repo_data.get("open_issues"))
    failed_runs = [
        run for run in runs
        if isinstance(run, dict) and str(run.get("conclusion") or "").lower() in BAD_CONCLUSIONS
    ]

    lines = [
        "# GitHub Control Dashboard Report",
        "",
        f"Generated: `{datetime.now(timezone.utc).isoformat()}`",
        "",
        "## Current commit",
        "",
        f"- Commit: `{repo.get('current_commit') or env.get('GITHUB_SHA') or 'unknown'}`",
        f"- Repository: `{env.get('GITHUB_REPOSITORY', 'unknown')}`",
        f"- Workflow: `{env.get('GITHUB_WORKFLOW', 'unknown')}`",
        f"- Event: `{env.get('GITHUB_EVENT_NAME', 'unknown')}`",
        "",
        "## Latest commits",
        "",
    ]
    lines.extend([f"- `{commit}`" for commit in commits[:20]] or ["WARNING: No commit data was available."])

    lines.extend(["", "## Latest workflow runs", ""])
    run_rows = [
        [r.get("workflowName", ""), r.get("status", ""), r.get("conclusion") or "-", r.get("headBranch", ""), r.get("event", ""), r.get("updatedAt", ""), r.get("url", "")]
        for r in runs[:30] if isinstance(r, dict)
    ]
    lines.extend(table(["Workflow", "Status", "Conclusion", "Branch", "Event", "Updated", "URL"], run_rows, "WARNING: No workflow run data was available."))

    lines.extend(["", "## Failed or cancelled workflows", ""])
    failed_rows = [[r.get("workflowName", ""), r.get("conclusion", ""), r.get("headBranch", ""), r.get("updatedAt", ""), r.get("url", "")] for r in failed_runs]
    lines.extend(table(["Workflow", "Conclusion", "Branch", "Updated", "URL"], failed_rows, "No failed or cancelled workflow runs were reported."))

    lines.extend(["", "## Open pull requests", ""])
    pr_rows = [[p.get("number", ""), p.get("title", ""), f"{p.get('headRefName', '')} -> {p.get('baseRefName', '')}", p.get("updatedAt", "")] for p in prs if isinstance(p, dict)]
    lines.extend(table(["#", "Title", "Head to Base", "Updated"], pr_rows, "No open pull requests were reported."))

    lines.extend(["", "## Open issues", ""])
    issue_rows = []
    for issue in issues:
        if isinstance(issue, dict):
            labels = ", ".join(label.get("name", "") for label in issue.get("labels", []) if isinstance(label, dict)) or "-"
            issue_rows.append([issue.get("number", ""), issue.get("title", ""), labels, issue.get("updatedAt", "")])
    lines.extend(table(["#", "Title", "Labels", "Updated"], issue_rows, "No open issues were reported."))

    lines.extend(["", "## Collection warnings", ""])
    lines.extend([f"- WARNING: {warning}" for warning in warnings] or ["No collection warnings were reported."])
    lines.extend(["", "## Recommended next action", "", next_action(warnings, failed_runs, issues), ""])
    lines.extend([
        "## Safety boundaries",
        "",
        "- Report generation is read-only.",
        "- Generated reports are not committed back to main in this first version.",
        "- Required validation remains: python3 scripts/validate_repo_structure.py; cd ios && swift test; cd ios && swift build.",
        "",
    ])

    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
