#!/usr/bin/env python3
"""Unit tests for the shadow-mode PR autonomy gate evaluator."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from evaluate_pr import evaluate, latest_runs_by_name, required_workflows  # noqa: E402


HEAD = "current-head"
OLD_HEAD = "old-head"


def run(
    name: str,
    *,
    status: str = "completed",
    conclusion: str | None = "success",
    head: str = HEAD,
    number: int = 1,
    created_at: str = "2026-06-21T10:00:00Z",
) -> dict[str, object]:
    return {
        "id": number,
        "name": name,
        "status": status,
        "conclusion": conclusion,
        "head_sha": head,
        "run_number": number,
        "created_at": created_at,
        "html_url": f"https://example.invalid/runs/{number}",
    }


def successful_runs(files: list[str]) -> list[dict[str, object]]:
    return [run(name, number=index + 1) for index, name in enumerate(required_workflows(files))]


class RequiredWorkflowTests(unittest.TestCase):
    def test_baseline_for_swift_file(self) -> None:
        self.assertEqual(
            required_workflows(["ios/Sources/AgentKernel/AgentKernel.swift"]),
            (
                "PR Change Scope",
                "Pull Request Quality",
                "Repo Audit",
                "Phase 0 CI Validation",
            ),
        )

    def test_docs_change_requires_docs_consistency(self) -> None:
        required = required_workflows(["docs/FAQ.md"])
        self.assertIn("Docs Consistency", required)
        self.assertNotIn("Workflow Lint", required)

    def test_workflow_change_requires_docs_and_workflow_lint(self) -> None:
        required = required_workflows([".github/workflows/example.yml"])
        self.assertIn("Docs Consistency", required)
        self.assertIn("Workflow Lint", required)


class LatestRunTests(unittest.TestCase):
    def test_old_head_cannot_authorize_current_head(self) -> None:
        runs = [
            run("Repo Audit", head=OLD_HEAD, number=99),
            run("Repo Audit", head=HEAD, status="queued", conclusion=None, number=1),
        ]
        latest = latest_runs_by_name(runs, HEAD)
        self.assertEqual(latest["Repo Audit"]["run_number"], 1)
        self.assertEqual(latest["Repo Audit"]["status"], "queued")

    def test_latest_same_head_run_supersedes_older_run(self) -> None:
        runs = [
            run(
                "Repo Audit",
                status="completed",
                conclusion="failure",
                number=1,
                created_at="2026-06-21T09:00:00Z",
            ),
            run(
                "Repo Audit",
                status="completed",
                conclusion="success",
                number=2,
                created_at="2026-06-21T10:00:00Z",
            ),
        ]
        latest = latest_runs_by_name(runs, HEAD)
        self.assertEqual(latest["Repo Audit"]["run_number"], 2)
        self.assertEqual(latest["Repo Audit"]["conclusion"], "success")


class EvaluationTests(unittest.TestCase):
    def test_empty_scope_is_unsupported(self) -> None:
        result = evaluate([], [], HEAD)
        self.assertEqual(result.state, "UNSUPPORTED_SCOPE")

    def test_missing_required_workflow_waits(self) -> None:
        files = ["docs/FAQ.md"]
        runs = successful_runs(files)
        runs = [item for item in runs if item["name"] != "Docs Consistency"]
        result = evaluate(files, runs, HEAD)
        self.assertEqual(result.state, "WAITING_CI")

    def test_queued_required_workflow_waits(self) -> None:
        files = ["docs/FAQ.md"]
        runs = successful_runs(files)
        for item in runs:
            if item["name"] == "Docs Consistency":
                item["status"] = "queued"
                item["conclusion"] = None
        result = evaluate(files, runs, HEAD)
        self.assertEqual(result.state, "WAITING_CI")

    def test_failed_required_workflow_needs_fix(self) -> None:
        files = ["docs/FAQ.md"]
        runs = successful_runs(files)
        for item in runs:
            if item["name"] == "Repo Audit":
                item["conclusion"] = "failure"
        result = evaluate(files, runs, HEAD)
        self.assertEqual(result.state, "FIX_NEEDED")

    def test_all_required_workflows_green(self) -> None:
        files = ["docs/FAQ.md"]
        result = evaluate(files, successful_runs(files), HEAD)
        self.assertEqual(result.state, "CI_GREEN")

    def test_cancelled_latest_run_does_not_authorize(self) -> None:
        files = ["scripts/autonomy/evaluate_pr.py"]
        runs = successful_runs(files)
        for item in runs:
            if item["name"] == "Phase 0 CI Validation":
                item["conclusion"] = "cancelled"
        result = evaluate(files, runs, HEAD)
        self.assertEqual(result.state, "WAITING_CI")


if __name__ == "__main__":
    unittest.main(verbosity=2)
