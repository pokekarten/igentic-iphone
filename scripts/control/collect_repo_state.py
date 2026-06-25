#!/usr/bin/env python3
"""Collect read-only repository state for the GitHub control dashboard."""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

from _gh import parse_json, run

OUT = Path("reports/latest-repo-state.json")
ENV_KEYS = [
    "GITHUB_REPOSITORY",
    "GITHUB_REF",
    "GITHUB_REF_NAME",
    "GITHUB_SHA",
    "GITHUB_RUN_ID",
    "GITHUB_RUN_NUMBER",
    "GITHUB_WORKFLOW",
    "GITHUB_EVENT_NAME",
    "GITHUB_ACTOR",
]


def main() -> int:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    env = {key: os.environ.get(key, "") for key in ENV_KEYS}

    git_log = run(["git", "log", "--oneline", "-20"])
    prs = run([
        "gh", "pr", "list", "--state", "open", "--limit", "20", "--json",
        "number,title,state,updatedAt,headRefName,baseRefName",
    ])
    issues = run([
        "gh", "issue", "list", "--state", "open", "--limit", "30", "--json",
        "number,title,state,labels,updatedAt",
    ])

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "environment": env,
        "current_commit": env.get("GITHUB_SHA", ""),
        "commands": {"git_log": git_log, "open_prs": prs, "open_issues": issues},
        "data": {
            "latest_commits_oneline": [line for line in git_log.get("stdout", "").splitlines() if line.strip()],
            "open_prs": parse_json(prs),
            "open_issues": parse_json(issues),
        },
        "safety": {
            "mode": "read-only",
            "mutations_allowed": False,
            "notes": [
                "No issue, PR, run, ref or repository-file mutation is performed.",
                "Issue and PR text is for review only, not automatic code generation.",
            ],
        },
    }
    OUT.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())