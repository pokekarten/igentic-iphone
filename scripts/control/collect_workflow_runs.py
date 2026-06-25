#!/usr/bin/env python3
"""Collect read-only GitHub Actions workflow-run data."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

from _gh import parse_json, run

OUT = Path("reports/latest-ci-runs.json")


def main() -> int:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    runs = run([
        "gh", "run", "list", "--limit", "30", "--json",
        "databaseId,workflowName,status,conclusion,headBranch,headSha,event,createdAt,updatedAt,url",
    ])
    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "commands": {"workflow_runs": runs},
        "data": {"workflow_runs": parse_json(runs)},
        "safety": {
            "mode": "read-only",
            "mutations_allowed": False,
            "notes": ["This script lists workflow runs only.", "It never reruns, cancels or dispatches workflows."],
        },
    }
    OUT.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())