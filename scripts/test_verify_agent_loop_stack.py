"""Pure local validation tests; no GitHub network, device or deployment."""
import io
import json
import tempfile
from contextlib import redirect_stdout, redirect_stderr
from unittest.mock import patch
import unittest
from pathlib import Path
from verify_agent_loop_stack import OfflineStackError, manifest_entries, audit_pins


def sample():
    return {"schema": 1, "branches": [
        {"pr": 420, "ref": "fix/delivery-marker-key-rotation-20261123",
         "sha": "a" * 40},
        {"pr": 414, "ref": "fix/owner-relay-replay-integrity-20261123",
         "sha": "b" * 40},
    ]}


class PinnedStackManifestTests(unittest.TestCase):
    def parse(self, doc):
        with tempfile.TemporaryDirectory(prefix="igentic-stack-manifest-") as tmp:
            path = Path(tmp) / "manifest.json"
            path.write_text(json.dumps(doc), encoding="utf-8")
            return manifest_entries(path)

    def test_valid_explicit_sha_pinning(self):
        self.assertEqual([x["pr"] for x in self.parse(sample())], [420, 414])

    def test_deny_future_unknown_schema(self):
        m = sample()
        m["schema"] = 2
        with self.assertRaises(OfflineStackError):
            self.parse(m)

    def test_deny_duplicate_pr(self):
        m = sample()
        m["branches"][1]["pr"] = 420
        with self.assertRaises(OfflineStackError):
            self.parse(m)

    def test_deny_duplicate_commit(self):
        m = sample()
        m["branches"][1]["sha"] = "a" * 40
        with self.assertRaises(OfflineStackError):
            self.parse(m)

    def test_deny_non_sha_version(self):
        m = sample()
        m["branches"][0]["sha"] = "main"
        with self.assertRaises(OfflineStackError):
            self.parse(m)

    def test_deny_branch_path_traversal(self):
        for bad in ("../main", "some/../../main", "-cmd", "main.lock",
                    "feature//.secret", "a/../main"):
            m = sample()
            m["branches"][0]["ref"] = bad
            with self.subTest(ref=bad), self.assertRaises(OfflineStackError):
                self.parse(m)

    def test_deny_extra_fields(self):
        m = sample()
        m["branches"][0]["password"] = "unexpected"
        with self.assertRaises(OfflineStackError):
            self.parse(m)

    def test_deny_boolean_as_pr_number(self):
        m = sample()
        m["branches"][0]["pr"] = True
        with self.assertRaises(OfflineStackError):
            self.parse(m)

    def test_deny_missing_manifest(self):
        with self.assertRaises(OfflineStackError):
            manifest_entries(Path("/nonexistent/igentic-stack-missing-123.json"))


    def test_audit_reports_every_stale_pin_without_merging(self):
        m = sample()["branches"]
        seen = []
        def fake_checked(argv, **kwargs):
            self.assertEqual(argv[:3], ["git", "ls-remote", "--heads"])
            ref = argv[-1]
            seen.append(ref)
            changed = "c" * 40 if ref.endswith("delivery-marker-key-rotation-20261123") else "d" * 40
            return changed + "\t" + ref

        stderr = io.StringIO()
        with patch("verify_agent_loop_stack.checked", side_effect=fake_checked):
            with redirect_stderr(stderr), self.assertRaises(OfflineStackError) as raised:
                audit_pins(m, url="https://example.invalid/repo.git")
        self.assertEqual(len(seen), 2)
        self.assertEqual(stderr.getvalue().count("PIN DRIFT"), 2)
        self.assertIn("2 of 2", str(raised.exception))

    def test_audit_ok_for_exact_heads_and_fails_on_missing_head(self):
        m = sample()["branches"]
        def exact(argv, **kwargs):
            ref = argv[-1]
            item = next(x for x in m if ref.endswith(x["ref"]))
            return item["sha"] + "\t" + ref

        with patch("verify_agent_loop_stack.checked", side_effect=exact):
            with redirect_stdout(io.StringIO()) as stdout:
                audit_pins(m, url="https://example.invalid/repo.git")
        self.assertEqual(stdout.getvalue().count("PIN OK"), 2)

        calls = []
        def missing(argv, **kwargs):
            calls.append(argv[-1])
            return "" if len(calls) == 1 else exact(argv)
        with patch("verify_agent_loop_stack.checked", side_effect=missing):
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                with self.assertRaises(OfflineStackError):
                    audit_pins(m, url="https://example.invalid/repo.git")
        self.assertEqual(len(calls), 2)

    def test_audit_invalid_remote_ref_never_counts_as_success(self):
        m = sample()["branches"]
        def wrong_ref(argv, **kwargs):
            return m[0]["sha"] + "\trefs/heads/not-the-requested-branch"
        with patch("verify_agent_loop_stack.checked", side_effect=wrong_ref):
            with redirect_stderr(io.StringIO()), self.assertRaises(OfflineStackError):
                audit_pins(m, url="https://example.invalid/repo.git")



if __name__ == "__main__":
    unittest.main()
