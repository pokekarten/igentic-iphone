#!/usr/bin/env python3
"""Evaluate exact-head GitHub Actions evidence for open pull requests.

This module is intentionally metadata-only. It reads GitHub API data and maintains
one shadow-mode pull-request comment. It never checks out or executes PR-head code,
merges, updates refs, closes issues, or writes outside the current repository.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any, Iterable, Mapping, Sequence

MARKER = "<!-- igentic-pr-autonomy-gate -->"
BASE_REQUIRED = (
    "PR Change Scope",
    "Pull Request Quality",
    "Repo Audit",
    "Phase 0 CI Validation",
)
FAILURE_CONCLUSIONS = {
    "action_required",
    "failure",
    "startup_failure",
    "stale",
    "timed_out",
}
SUCCESS_CONCLUSION = "success"


@dataclass(frozen=True)
class WorkflowEvidence:
    name: str
    status: str
    conclusion: str | None
    run_number: int | None
    html_url: str | None


@dataclass(frozen=True)
class GateResult:
    state: str
    required: tuple[str, ...]
    evidence: tuple[WorkflowEvidence, ...]


def is_docs_or_control_path(path: str) -> bool:
    return (
        path == "README.md"
        or path == "PROJECT_STATE.md"
        or path.endswith(".md")
        or path.startswith("docs/")
        or path.startswith(".github/ISSUE_TEMPLATE/")
        or path == ".github/PULL_REQUEST_TEMPLATE.md"
        or path.startswith(".github/workflows/")
    )


def required_workflows(files: Sequence[str]) -> tuple[str, ...]:
    """Return required workflow names using docs/WORKFLOWS.md as contract."""
    required = list(BASE_REQUIRED)
    if any(is_docs_or_control_path(path) for path in files):
        required.append("Docs Consistency")
    if any(path.startswith(".github/workflows/") for path in files):
        required.append("Workflow Lint")
    return tuple(required)


def latest_runs_by_name(
    runs: Iterable[Mapping[str, Any]], current_head: str
) -> dict[str, Mapping[str, Any]]:
    """Keep only the latest run per workflow for the exact current PR head."""
    filtered = [run for run in runs if run.get("head_sha") == current_head]
    filtered.sort(
        key=lambda run: (
            str(run.get("created_at") or ""),
            int(run.get("run_number") or 0),
            int(run.get("id") or 0),
        ),
        reverse=True,
    )
    latest: dict[str, Mapping[str, Any]] = {}
    for run in filtered:
        name = str(run.get("name") or "")
        if name and name not in latest:
            latest[name] = run
    return latest


def evaluate(files: Sequence[str], runs: Iterable[Mapping[str, Any]], head: str) -> GateResult:
    if not files:
        return GateResult(state="UNSUPPORTED_SCOPE", required=(), evidence=())

    required = required_workflows(files)
    latest = latest_runs_by_name(runs, head)
    evidence: list[WorkflowEvidence] = []
    has_failure = False
    has_waiting = False

    for name in required:
        run = latest.get(name)
        if run is None:
            evidence.append(
                WorkflowEvidence(
                    name=name,
                    status="missing",
                    conclusion=None,
                    run_number=None,
                    html_url=None,
                )
            )
            has_waiting = True
            continue

        status = str(run.get("status") or "unknown")
        raw_conclusion = run.get("conclusion")
        conclusion = str(raw_conclusion) if raw_conclusion is not None else None
        evidence.append(
            WorkflowEvidence(
                name=name,
                status=status,
                conclusion=conclusion,
                run_number=int(run["run_number"]) if run.get("run_number") else None,
                html_url=str(run["html_url"]) if run.get("html_url") else None,
            )
        )

        if conclusion in FAILURE_CONCLUSIONS:
            has_failure = True
        elif status != "completed" or conclusion != SUCCESS_CONCLUSION:
            has_waiting = True

    if has_failure:
        state = "FIX_NEEDED"
    elif has_waiting:
        state = "WAITING_CI"
    else:
        state = "CI_GREEN"
    return GateResult(state=state, required=required, evidence=tuple(evidence))


class GitHubClient:
    def __init__(self, repository: str, token: str) -> None:
        self.repository = repository
        self.token = token
        self.api_root = "https://api.github.com"

    def request(self, method: str, path: str, payload: Any | None = None) -> Any:
        data = None if payload is None else json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(
            f"{self.api_root}{path}",
            data=data,
            method=method,
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {self.token}",
                "X-GitHub-Api-Version": "2022-11-28",
                "User-Agent": "igentic-pr-autonomy-gate",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read()
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"GitHub API {method} {path} failed: {error.code} {detail}"
            ) from error
        return json.loads(body) if body else None

    def paged(self, path: str) -> list[Mapping[str, Any]]:
        separator = "&" if "?" in path else "?"
        page = 1
        results: list[Mapping[str, Any]] = []
        while True:
            batch = self.request("GET", f"{path}{separator}per_page=100&page={page}")
            if not isinstance(batch, list):
                raise RuntimeError(f"Expected list response for {path}")
            results.extend(batch)
            if len(batch) < 100:
                return results
            page += 1

    def open_pull_numbers(self) -> list[int]:
        pulls = self.paged(f"/repos/{self.repository}/pulls?state=open")
        return [int(pull["number"]) for pull in pulls]

    def pull(self, number: int) -> Mapping[str, Any]:
        result = self.request("GET", f"/repos/{self.repository}/pulls/{number}")
        if not isinstance(result, dict):
            raise RuntimeError(f"Unexpected pull request response for #{number}")
        return result

    def pull_files(self, number: int) -> list[str]:
        files = self.paged(f"/repos/{self.repository}/pulls/{number}/files")
        return [str(item["filename"]) for item in files]

    def workflow_runs(self, head: str) -> list[Mapping[str, Any]]:
        query = urllib.parse.urlencode(
            {"event": "pull_request", "head_sha": head, "per_page": 100}
        )
        result = self.request(
            "GET", f"/repos/{self.repository}/actions/runs?{query}"
        )
        if not isinstance(result, dict):
            raise RuntimeError("Unexpected workflow runs response")
        runs = result.get("workflow_runs", [])
        if not isinstance(runs, list):
            raise RuntimeError("workflow_runs is not a list")
        return runs

    def comments(self, number: int) -> list[Mapping[str, Any]]:
        return self.paged(f"/repos/{self.repository}/issues/{number}/comments")

    def upsert_gate_comment(self, number: int, body: str) -> str:
        existing = next(
            (
                comment
                for comment in self.comments(number)
                if MARKER in str(comment.get("body") or "")
            ),
            None,
        )
        if existing is not None:
            if str(existing.get("body") or "") == body:
                return "unchanged"
            self.request(
                "PATCH",
                f"/repos/{self.repository}/issues/comments/{int(existing['id'])}",
                {"body": body},
            )
            return "updated"
        self.request(
            "POST",
            f"/repos/{self.repository}/issues/{number}/comments",
            {"body": body},
        )
        return "created"


def render_comment(number: int, head: str, files: Sequence[str], result: GateResult) -> str:
    rows = []
    for item in result.evidence:
        conclusion = item.conclusion or "—"
        run = f"#{item.run_number}" if item.run_number is not None else "—"
        rows.append(f"| {item.name} | {item.status} | {conclusion} | {run} |")
    table = "\n".join(rows) if rows else "| — | — | — | — |"
    return f"""{MARKER}
## iGentic PR Autonomy Gate — shadow mode

State: `{result.state}`  
PR: `#{number}`  
Head: `{head}`  
Changed files: `{len(files)}`

| Required workflow | Status | Conclusion | Run |
| --- | --- | --- | --- |
{table}

`CI_GREEN` means that the required technical workflow evidence for this exact head is currently green. It is **not** semantic approval, merge authorization, device evidence, or permission to bypass the scheduled reviewer and closer.

This shadow gate never merges, changes branches, closes issues, writes to the private Brain, or executes pull-request code.
"""


def event_pull_numbers() -> list[int]:
    explicit = os.environ.get("PR_NUMBER", "").strip()
    if explicit:
        return [int(explicit)]

    event_path = os.environ.get("GITHUB_EVENT_PATH", "").strip()
    if not event_path or not os.path.exists(event_path):
        return []
    with open(event_path, "r", encoding="utf-8") as handle:
        event = json.load(handle)
    workflow_run = event.get("workflow_run") or {}
    pulls = workflow_run.get("pull_requests") or []
    return [int(item["number"]) for item in pulls if item.get("number")]


def main() -> int:
    repository = os.environ.get("GITHUB_REPOSITORY", "").strip()
    token = os.environ.get("GITHUB_TOKEN", "").strip()
    if not repository or not token:
        print("GITHUB_REPOSITORY and GITHUB_TOKEN are required", file=sys.stderr)
        return 2

    client = GitHubClient(repository, token)
    numbers = event_pull_numbers() or client.open_pull_numbers()
    if not numbers:
        print("No open pull requests to evaluate.")
        return 0

    for number in sorted(set(numbers)):
        pull = client.pull(number)
        if pull.get("state") != "open":
            continue
        head = str((pull.get("head") or {}).get("sha") or "")
        if not head:
            raise RuntimeError(f"PR #{number} has no head SHA")
        files = client.pull_files(number)
        runs = client.workflow_runs(head)
        result = evaluate(files, runs, head)
        body = render_comment(number, head, files, result)
        action = client.upsert_gate_comment(number, body)
        print(f"PR #{number}: {result.state}; comment={action}; head={head}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
