#!/usr/bin/env python3
"""Collect read-only GitHub Actions workflow-run data."""

from __future__ import annotations

import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

OUT = Path("reports/latest-ci-runs.json")


def run(command: list[str]) -> dict[str, Any]:
    try:
        result = subprocess.run(
            command,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=30,
        )
        return {
            "command": command,
            "ok": result.returncode == 0,
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        }
    except FileNotFoundError as exc:
        return {"command": command, "ok": False, "returncode": None, "stdout": "", "stderr": str(exc)}
    except subprocess.TimeoutExpired as exc:
        return {
            "command": command,
            "ok": False,
            "returncode": None,
            "stdout": exc.stdout or "",
            "stderr": exc.stderr or "Timed out after 30 seconds.",
        }


def parse_json(result: dict[str, Any]) -> Any:
    text = str(result.get("stdout") or "").strip()
    if not text:
        return None
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        result["json_warning"] = str(exc)
        return None


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
