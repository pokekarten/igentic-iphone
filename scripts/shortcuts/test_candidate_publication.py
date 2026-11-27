"""Regression fixtures: private candidate publication, no signing or device access."""
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch

import status_loop_factory as factory


class CandidatePublicationTests(unittest.TestCase):
    def test_partial_write_failure_does_not_publish(self):
        real_fdopen = os.fdopen
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            target = parent / "candidate.shortcut"

            class InterruptedWriter:
                def __init__(self, fd, mode):
                    self.file = real_fdopen(fd, mode)

                def __enter__(self):
                    return self

                def __exit__(self, *exc):
                    self.file.close()

                def write(self, data):
                    self.file.write(data[:3])
                    self.file.flush()
                    raise OSError("synthetic disk failure")

            with patch.object(factory.os, "fdopen", InterruptedWriter):
                with self.assertRaisesRegex(OSError, "synthetic disk failure"):
                    factory.write_private_candidate(target, b"complete candidate")
            self.assertFalse(target.exists())
            self.assertEqual(list(parent.iterdir()), [])

    def test_publish_occurs_after_successful_sync(self):
        real_fsync = os.fsync
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            target = parent / "candidate.shortcut"
            observed = []

            def sync(fd):
                observed.append(not target.exists())
                real_fsync(fd)

            with patch.object(factory.os, "fsync", side_effect=sync):
                factory.write_private_candidate(target, b"complete candidate")
            self.assertEqual(observed, [True])
            self.assertEqual(target.read_bytes(), b"complete candidate")
            self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)
            self.assertEqual(list(parent.iterdir()), [target])

    def test_sync_failure_does_not_publish(self):
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            target = parent / "candidate.shortcut"
            with patch.object(factory.os, "fsync", side_effect=OSError("sync failed")):
                with self.assertRaisesRegex(OSError, "sync failed"):
                    factory.write_private_candidate(target, b"candidate")
            self.assertEqual(list(parent.iterdir()), [])

    def test_existing_file_and_symlink_are_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            target = parent / "candidate.shortcut"
            factory.write_private_candidate(target, b"first")
            link = parent / "link.shortcut"
            link.symlink_to(target)
            for output in (target, link):
                with self.assertRaises(FileExistsError):
                    factory.write_private_candidate(output, b"replacement")
            self.assertEqual(target.read_bytes(), b"first")
            self.assertTrue(link.is_symlink())
            self.assertEqual(set(parent.iterdir()), {target, link})


if __name__ == "__main__":
    unittest.main()
