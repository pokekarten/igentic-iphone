import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from verify_open_weight_artifact import ArtifactRejected, verify


class OpenWeightArtifactVerificationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.directory = self.root / "models"
        self.directory.mkdir()
        self.model = self.directory / "synthetic.gguf"
        self.model.write_bytes(b"synthetic fixture only; not executable weights")
        self.manifest_path = self.root / "manifest.json"
        self.manifest = {
            "model_id": "fixture/local-model",
            "filename": self.model.name,
            "sha256": hashlib.sha256(self.model.read_bytes()).hexdigest(),
            "size_bytes": self.model.stat().st_size,
            "source_revision": "a" * 40,
            "license_reviewed": True,
        }
        self.save()

    def save(self):
        self.manifest_path.write_text(json.dumps(self.manifest))

    def check_rejected(self):
        self.save()
        with self.assertRaises(ArtifactRejected):
            verify(self.manifest_path, self.directory)

    def test_verified_fixture(self):
        self.assertTrue(verify(self.manifest_path, self.directory)["verified"])

    def test_rejects_modified_bytes_at_same_size(self):
        self.model.write_bytes(b"x" * self.model.stat().st_size)
        self.check_rejected()

    def test_rejects_wrong_size(self):
        self.manifest["size_bytes"] += 1
        self.check_rejected()

    def test_rejects_absolute_and_traversal_paths(self):
        for filename in ("../secret.gguf", "/tmp/foo.gguf", "subdir/file.gguf"):
            self.manifest["filename"] = filename
            self.check_rejected()

    def test_rejects_symlink_file(self):
        self.model.unlink()
        self.model.symlink_to(self.manifest_path)
        self.check_rejected()

    def test_rejects_unpinned_revision(self):
        self.manifest["source_revision"] = "main"
        self.check_rejected()

    def test_rejects_missing_license_review(self):
        self.manifest["license_reviewed"] = False
        self.check_rejected()

    def test_rejects_bool_size(self):
        self.manifest["size_bytes"] = True
        self.check_rejected()

    def test_rejects_duplicate_manifest_fields_even_if_values_match(self):
        # JSON allows duplicate object members syntactically, but a pinned
        # artifact manifest must not depend on the parser\'s last-key policy.
        encoded = json.dumps(self.manifest)
        duplicate = encoded.replace(
            '"license_reviewed": true',
            '"license_reviewed": true, "license_reviewed": true',
        )
        self.assertNotEqual(encoded, duplicate)
        self.manifest_path.write_text(duplicate)
        with self.assertRaisesRegex(ArtifactRejected, "duplicate manifest field"):
            verify(self.manifest_path, self.directory)

    def test_rejects_undeclared_manifest_fields(self):
        self.manifest["download_url"] = "https://example.org/evil"
        self.check_rejected()


if __name__ == "__main__":
    unittest.main()
