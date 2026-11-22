import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import validate_repo_structure as validator


class ForbiddenPathsTest(unittest.TestCase):
    def test_local_cache_and_indexed_artifacts(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            (root / ".gitignore").write_text(".build/\n")
            artifact = Path("ios/.build/generated")
            (root / artifact.parent).mkdir(parents=True)
            (root / artifact).touch()
            (root / ".env").touch()
            (root / "other/.build").mkdir(parents=True)
            expected = {Path(".env"), Path("other/.build")}
            with patch.object(validator, "ROOT", root):
                self.assertEqual(set(validator.validate_no_forbidden_files()), expected)
                subprocess.run(["git", "add", "-f", str(artifact)], cwd=root, check=True)
                self.assertEqual(set(validator.validate_no_forbidden_files()), expected | {artifact})
