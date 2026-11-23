#!/usr/bin/env python3
"""Verify a pinned iGentic agent-loop PR stack only in a disposable clone.

No main changes, PR writes, device operations, Apple transports or Site deploy.
The manifest intentionally goes stale whenever other chats update its PRs.
That must FAIL CLOSED until a human explicitly reviews and re-pins each SHA.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "scripts/agent_loop_stack_manifest.json"
HEX40 = re.compile(r"^[0-9a-f]{40}$")
GIT_REF = re.compile(r"^[a-z0-9][a-z0-9_./-]{3,120}$")


class OfflineStackError(Exception):
    """A trustworthy exact-head composition cannot be demonstrated."""


def checked(argv: list[str], *, cwd: Path | None = None,
            timeout_seconds: int = 90) -> str:
    # Avoid shell=True. GitHub prompts must never block a CI/offline audit.
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0",
               GIT_CONFIG_NOSYSTEM="1")
    p = subprocess.run(argv, cwd=cwd, env=env, text=True,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                       check=False, timeout=timeout_seconds)
    if p.returncode != 0:
        # Do not leak origin URLs, credentials or tool output into logs.
        raise OfflineStackError(
            "command failed (exit {}): {}".format(
                p.returncode, " ".join(argv[:2])
            )
        )
    return p.stdout.strip()


def manifest_entries(path: Path) -> list[dict]:
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise OfflineStackError("manifest unavailable or malformed") from exc
    if not isinstance(doc, dict) or doc.get("schema") != 1:
        raise OfflineStackError("unknown manifest schema")
    entries = doc.get("branches")
    if not isinstance(entries, list) or not 2 <= len(entries) <= 12:
        raise OfflineStackError("expected 2..12 pinned PR branches")
    seen_pr, seen_ref, seen_sha = set(), set(), set()
    for item in entries:
        if not isinstance(item, dict) or set(item) != {"pr", "ref", "sha"}:
            raise OfflineStackError("unexpected manifest branch fields")
        pr, ref, sha = item["pr"], item["ref"], item["sha"]
        if type(pr) is not int or pr < 1 or pr > 100_000:
            raise OfflineStackError("invalid PR number")
        if not isinstance(ref, str) or not GIT_REF.fullmatch(ref) \
                or ".." in ref or ref.endswith(("/", ".", ".lock")) \
                or "/." in ref or ref.startswith("-"):
            raise OfflineStackError("invalid PR branch ref")
        if not isinstance(sha, str) or not HEX40.fullmatch(sha):
            raise OfflineStackError("unverified PR SHA format")
        if pr in seen_pr or ref in seen_ref or sha in seen_sha:
            raise OfflineStackError("duplicate PR/ref/commit in manifest")
        seen_pr.add(pr)
        seen_ref.add(ref)
        seen_sha.add(sha)
    return entries


def git_clone_url() -> str:
    # Remote is read only. This tool will not push or force-update branches.
    url = checked(["git", "remote", "get-url", "origin"], cwd=ROOT)
    if not url or url.startswith("-") or "\n" in url:
        raise OfflineStackError("repository origin missing")
    return url



def audit_pins(entries: list[dict], *, url: str) -> None:
    """Check *all* remote PR heads before any clone or merge.

    This never rewrites the manifest. A clean preflight is not a guarantee
    against a subsequent ref move: compose() rechecks each fetched head.
    """
    failures = 0
    for item in entries:
        ref = "refs/heads/" + item["ref"]
        try:
            output = checked(["git", "ls-remote", "--heads", url, ref],
                             timeout_seconds=45)
        except (OfflineStackError, subprocess.TimeoutExpired):
            print("PIN UNVERIFIED PR #{}: remote head unavailable".format(
                item["pr"]), file=sys.stderr, flush=True)
            failures += 1
            continue
        lines = output.splitlines()
        if len(lines) != 1 or "\t" not in lines[0]:
            print("PIN UNVERIFIED PR #{}: missing or ambiguous head".format(
                item["pr"]), file=sys.stderr, flush=True)
            failures += 1
            continue
        sha, actual_ref = lines[0].split("\t", 1)
        if actual_ref != ref or not HEX40.fullmatch(sha):
            print("PIN UNVERIFIED PR #{}: invalid remote head".format(
                item["pr"]), file=sys.stderr, flush=True)
            failures += 1
        elif sha != item["sha"]:
            print("PIN DRIFT PR #{}: pinned {} -> observed {}".format(
                item["pr"], item["sha"][:12], sha[:12]
            ), file=sys.stderr, flush=True)
            failures += 1
        else:
            print("PIN OK PR #{}: {}".format(
                item["pr"], sha[:12]), flush=True)
    if failures:
        raise OfflineStackError(
            "{} of {} pinned PR heads changed or could not be verified; "
            "review changes before manually re-pinning; no merge performed."
            .format(failures, len(entries))
        )


def compose(entries: list[dict], destination: Path, *, url: str) -> str:
    work = destination / "repo"
    # Clone only the first branch and fetch each other named ref. The clone
    # and its merge commits are intentionally outside the caller checkout.
    checked([
        "git", "clone", "--quiet", "--no-checkout", "--single-branch",
        "--filter=blob:none", "--branch", entries[0]["ref"], url, str(work)
    ])
    checked(["git", "checkout", "--quiet", "-B", "isolated-agent-loop",
             "origin/" + entries[0]["ref"]], cwd=work)
    checked(["git", "config", "user.name", "iGentic Offline Acceptance"], cwd=work)
    checked(["git", "config", "user.email",
             "igentic@users.noreply.github.com"], cwd=work)
    for i, item in enumerate(entries):
        ref = item["ref"]
        if i:
            checked(["git", "fetch", "--quiet", "--no-tags", "origin",
                     "+refs/heads/" + ref + ":refs/remotes/origin/" + ref], cwd=work)
        actual = checked(["git", "rev-parse", "refs/remotes/origin/" + ref], cwd=work)
        if actual != item["sha"]:
            raise OfflineStackError(
                "PR #{} drift: expected {} but observed {}. "
                "Review new code before changing the manifest.".format(
                    item["pr"], item["sha"][:12], actual[:12]
                )
            )
        print("Pinned PR #{}: {}".format(item["pr"], actual[:12]), flush=True)
        if i:
            try:
                checked(["git", "merge", "--quiet", "--no-edit", "--no-ff",
                         "refs/remotes/origin/" + ref], cwd=work)
            except OfflineStackError as exc:
                paths = checked(["git", "diff", "--name-only",
                                 "--diff-filter=U"], cwd=work)
                raise OfflineStackError(
                    "PR #{} offline merge conflict: {}".format(
                        item["pr"], paths or "(unclassified)"
                    )
                ) from exc
            print("  conflict-free isolated merge", flush=True)
    checked(["git", "diff", "--check", "HEAD~1", "HEAD"], cwd=work)
    if checked(["git", "status", "--porcelain"], cwd=work):
        raise OfflineStackError("integration clone unexpectedly dirty")
    final = checked(["git", "rev-parse", "HEAD"], cwd=work)
    print("TEST-ONLY local composition: " + final[:12], flush=True)
    return final


def verify(work: Path, mode: str) -> None:
    checked(["python3", "scripts/validate_repo_structure.py"], cwd=work)
    print("Repository structure PASS", flush=True)
    if mode == "merge":
        return
    # These test files are real sources, not fake status flags. They do not
    # trigger a phone, network listener or deployed Site.
    scripts = [
        "test/agent-loop-offline-integration.test.mjs",
        "test/delivery-marker-key-seal.test.mjs",
        "test/ios-owner-task-parity.test.mjs",
        "test/ios-receipt-parity.test.mjs",
        "test/sites-operator-console.test.mjs",
    ]
    checked(["node", "--test", *scripts], cwd=work / "plugins/iphone-connect")
    print("Focused cross-PR Node admission, marker, receipt and Site PASS",
          flush=True)
    if mode != "full":
        return
    # Serial runs avoid overloading an 8GB Mac. No simulator or physical
    # iPhone command; Swift package unit tests use local synthetic keys.
    checked(["npm", "ci", "--ignore-scripts", "--no-audit", "--no-fund"],
            cwd=work / "plugins/iphone-connect", timeout_seconds=180)
    test_files = sorted(str(p.relative_to(work / "plugins/iphone-connect"))
                        for p in (work / "plugins/iphone-connect/test").glob("*.test.mjs"))
    if not test_files:
        raise OfflineStackError("no plugin tests found")
    checked(["node", "--test", "--test-concurrency=1", *test_files],
            cwd=work / "plugins/iphone-connect", timeout_seconds=300)
    print("Full Node plugin tests PASS", flush=True)
    checked(["swift", "test", "--package-path", "ios", "--scratch-path",
             str(work.parent / "swift-build"), "-j", "1"], cwd=work,
            timeout_seconds=300)
    print("Full Swift package tests PASS", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--mode", choices=("heads", "merge", "quick", "full"),
                        default="quick")
    args = parser.parse_args()
    try:
        entries = manifest_entries(args.manifest)
        url = git_clone_url()
        audit_pins(entries, url=url)
        if args.mode == "heads":
            print("PASS: all pinned PR heads verified; no clone or merge.", flush=True)
            return 0
        with tempfile.TemporaryDirectory(prefix="igentic-pinned-stack-") as directory:
            root = Path(directory)
            compose(entries, root, url=url)
            verify(root / "repo", args.mode)
        print("PASS: isolated stack acceptance; temporary clone removed.", flush=True)
        print("No real iPhone, Site deployment or execution verified.", flush=True)
    except subprocess.TimeoutExpired:
        print("FAIL-CLOSED: offline integration command timed out; "
              "no evidence of successful execution.", file=sys.stderr)
        return 1
    except (OfflineStackError, FileNotFoundError) as exc:
        print("FAIL-CLOSED: {}".format(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
