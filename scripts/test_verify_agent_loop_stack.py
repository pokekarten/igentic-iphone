"""Pure local validation tests; no GitHub network, device or deployment."""
import json
import tempfile
import unittest
from pathlib import Path
from verify_agent_loop_stack import OfflineStackError, manifest_entries


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


if __name__ == "__main__":
    unittest.main()
