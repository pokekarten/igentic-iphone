from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "check_commit_email_privacy.py"
WORKFLOW = ROOT / ".github" / "workflows" / "commit-email-privacy.yml"


def run_git(repo: Path, *args: str, env: dict[str, str] | None = None) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=repo,
        env=env,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def commit_file(
    repo: Path,
    path: str,
    content: str,
    *,
    author_email: str = "dev@users.noreply.github.com",
    committer_email: str = "dev@users.noreply.github.com",
) -> str:
    target = repo / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")
    run_git(repo, "add", path)
    env = os.environ.copy()
    env.update(
        {
            "GIT_AUTHOR_NAME": "Test Author",
            "GIT_AUTHOR_EMAIL": author_email,
            "GIT_COMMITTER_NAME": "Test Committer",
            "GIT_COMMITTER_EMAIL": committer_email,
        }
    )
    run_git(repo, "commit", "-m", f"add {path}", env=env)
    return run_git(repo, "rev-parse", "HEAD")


class CommitEmailPrivacyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.repo = Path(self.tempdir.name)
        run_git(self.repo, "init", "-q")
        self.base = commit_file(self.repo, "base.txt", "base\n")

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def check(self, head: str, *, base: str | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), base or self.base, head],
            cwd=self.repo,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    def test_clean_noreply_metadata_passes(self) -> None:
        head = commit_file(self.repo, "clean.txt", "ok\n")
        result = self.check(head)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS", result.stdout)

    def test_gmail_author_is_blocked_without_reprinting_address(self) -> None:
        blocked = "person@gmail.com"
        head = commit_file(self.repo, "author.txt", "bad\n", author_email=blocked)
        result = self.check(head)
        self.assertEqual(result.returncode, 1)
        self.assertIn("author.email uses a blocked personal mail domain", result.stderr)
        self.assertNotIn(blocked, result.stderr)

    def test_googlemail_committer_is_blocked_without_reprinting_address(self) -> None:
        blocked = "person@googlemail.com"
        head = commit_file(self.repo, "committer.txt", "bad\n", committer_email=blocked)
        result = self.check(head)
        self.assertEqual(result.returncode, 1)
        self.assertIn("committer.email uses a blocked personal mail domain", result.stderr)
        self.assertNotIn(blocked, result.stderr)

    def test_domain_match_is_case_insensitive(self) -> None:
        head = commit_file(self.repo, "mixed.txt", "bad\n", author_email="person@GMAIL.COM")
        self.assertEqual(self.check(head).returncode, 1)

    def test_malformed_base_fails_closed(self) -> None:
        head = commit_file(self.repo, "head.txt", "ok\n")
        result = self.check(head, base="not-a-sha")
        self.assertEqual(result.returncode, 2)
        self.assertIn("failed closed", result.stderr)

    def test_workflow_uses_base_trusted_pull_request_target_boundary(self) -> None:
        text = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("pull_request_target:", text)
        self.assertNotIn("\n  pull_request:\n", text)
        self.assertIn("contents: read", text)
        self.assertIn("github.event.pull_request.base.ref", text)
        self.assertIn("github.event.pull_request.base.sha", text)
        self.assertIn("github.event.pull_request.head.sha", text)
        self.assertIn("github.event.pull_request.number", text)
        self.assertIn("refs/pull/${PR_NUMBER}/head", text)
        self.assertIn('rev-parse refs/remotes/origin/privacy-base)" = "${BASE_SHA}', text)
        self.assertIn('rev-parse refs/remotes/origin/privacy-head)" = "${HEAD_SHA}', text)
        self.assertIn('git checkout --detach "${BASE_SHA}"', text)
        self.assertNotIn('git checkout --detach "${HEAD_SHA}"', text)
        self.assertNotIn("actions/checkout", text)
        self.assertIn("python3 scripts/check_commit_email_privacy.py", text)


if __name__ == "__main__":
    unittest.main()
