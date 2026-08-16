"""Fail closed when newly introduced Git commits expose personal Gmail metadata."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys

_SHA_RE = re.compile(r"^[0-9a-fA-F]{40,64}$")
_PERSONAL_EMAIL_RE = re.compile(r"@(gmail|googlemail)\.com$", re.IGNORECASE)


def _git(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def _require_commit(sha: str, label: str) -> None:
    if not _SHA_RE.fullmatch(sha):
        raise ValueError(f"{label} is not a full Git object id")
    result = _git("cat-file", "-e", f"{sha}^{{commit}}", check=False)
    if result.returncode != 0:
        raise ValueError(f"{label} does not resolve to a commit")


def _new_commits(base: str, head: str) -> list[str]:
    result = _git("rev-list", "--reverse", f"{base}..{head}")
    return [line for line in result.stdout.splitlines() if line]


def _metadata(commit: str) -> tuple[str, str, str]:
    result = _git("show", "-s", "--format=%H%x00%ae%x00%ce", commit)
    parts = result.stdout.rstrip("\n").split("\x00")
    if len(parts) != 3:
        raise ValueError(f"could not parse metadata for commit {commit}")
    return parts[0], parts[1].strip(), parts[2].strip()


def _is_personal_email(email: str) -> bool:
    return bool(_PERSONAL_EMAIL_RE.search(email.strip()))


def check_range(base: str, head: str) -> int:
    _require_commit(base, "base")
    _require_commit(head, "head")

    commits = _new_commits(base, head)
    violations: list[tuple[str, str]] = []

    for commit in commits:
        commit_sha, author_email, committer_email = _metadata(commit)
        if _is_personal_email(author_email):
            violations.append((commit_sha, "author"))
        if _is_personal_email(committer_email):
            violations.append((commit_sha, "committer"))

    if not violations:
        print(f"PASS: checked {len(commits)} new commit(s); no blocked personal mail domains found")
        return 0

    for commit_sha, field in violations:
        print(
            f"VIOLATION: {commit_sha} {field}.email uses a blocked personal mail domain",
            file=sys.stderr,
        )

    print(
        "BLOCKED: newly introduced commit metadata contains a Gmail/Googlemail address; "
        "use the repository-approved GitHub noreply address",
        file=sys.stderr,
    )
    return 1


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("base")
    parser.add_argument("head")
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    try:
        return check_range(args.base, args.head)
    except (OSError, subprocess.SubprocessError, ValueError) as exc:
        print(f"ERROR: commit-email privacy check failed closed: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
