import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from setup_manager import stage, next_gate, manifest_for, inspect, read_artifact, UNSIGNED, SIGNED, MANIFEST
from test_status_loop_factory import fixture


class SetupTests(unittest.TestCase):
    def test_read_artifact_rejects_symlink_fifo_and_oversize(self):
        with tempfile.TemporaryDirectory() as d:
            base = Path(d)
            source = base / "source"
            source.write_bytes(b"abc")
            link = base / "link"
            link.symlink_to(source)
            with self.assertRaises((ValueError, OSError)):
                read_artifact(link)
            fifo = base / "fifo"
            os.mkfifo(fifo)
            with self.assertRaises(ValueError):
                read_artifact(fifo)
            with patch("setup_manager.MAX_BYTES", 2):
                with self.assertRaisesRegex(ValueError, "too large"):
                    read_artifact(source)

    @patch("setup_manager.library_status", return_value=False)
    @patch("setup_manager.app_identity", return_value=("example.test", "AAAAAAAAAA"))
    def test_empty_signed_artifact_cannot_publish(self, identity, library):
        import plistlib
        from status_loop_factory import workflow
        with tempfile.TemporaryDirectory() as d:
            base = Path(d)
            meta = base / "app/Metadata.appintents/extract.actionsdata"
            meta.parent.mkdir(parents=True)
            meta.write_text(json.dumps(fixture()))
            local = base / "local"
            local.mkdir(mode=0o700)
            unsigned = plistlib.dumps(workflow(fixture(), "example.test", "AAAAAAAAAA"), fmt=plistlib.FMT_BINARY)
            (local / UNSIGNED).write_bytes(unsigned)
            (local / SIGNED).write_bytes(b"")
            (local / MANIFEST).write_text(json.dumps(manifest_for(unsigned, b"")))
            with self.assertRaisesRegex(ValueError, "Empty signed artifact"):
                inspect(base / "app", local, base / "cloud", publish=True)
            self.assertFalse((base / "cloud").exists())

    def test_cloud_stage_idempotent_and_conflict(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / SIGNED
            self.assertTrue(stage(b"one", p))
            self.assertFalse(stage(b"one", p))
            with self.assertRaises(ValueError):
                stage(b"two", p)
            self.assertEqual(p.read_bytes(), b"one")

    def test_gate_requires_observation_not_assumption(self):
        r = dict(appMetadataReady=True, unsignedMatchesBuild=True,
                 signedArtifactPresent=True, cloudFileMatches=True,
                 cloudUploadVerified=None, macShortcutListed=False)
        self.assertEqual(next_gate(r), "verify_cloud_upload")
        r["cloudUploadVerified"] = True
        self.assertEqual(next_gate(r), "verify_system_import")
        r["macShortcutListed"] = True
        self.assertEqual(next_gate(r), "verify_physical_two_turn_loop")

    @patch("setup_manager.library_status", return_value=False)
    @patch("setup_manager.cloud_status", return_value=True)
    @patch("setup_manager.app_identity", return_value=("example.test", "AAAAAAAAAA"))
    @patch("setup_manager.subprocess.run")
    def test_prepare_publish_repeat_and_manifest(self, run, identity, cloud_status, library):
        with tempfile.TemporaryDirectory() as d:
            base = Path(d)
            app = base / "App.app"
            meta = app / "Metadata.appintents/extract.actionsdata"
            meta.parent.mkdir(parents=True)
            meta.write_text(json.dumps(fixture()))
            local = base / "local"
            cloud = base / "cloud"
            def sign(args, **kw):
                Path(args[-1]).write_bytes(b"synthetic signed")
                return type("Result", (), {"returncode": 0})()
            run.side_effect = sign
            r = inspect(app, local, cloud, prepare=True, publish=True)
            self.assertTrue(r["newUnsigned"] and r["newSigned"] and r["newCloudCopy"])
            self.assertTrue(r["signedArtifactRecorded"])
            self.assertEqual(r["nextGate"], "verify_system_import")
            r = inspect(app, local, cloud, prepare=True, publish=True)
            self.assertFalse(r["newUnsigned"] or r["newSigned"] or r["newCloudCopy"])
            self.assertEqual(run.call_count, 1)
            (local / MANIFEST).write_text("{}")
            with self.assertRaises(ValueError):
                inspect(app, local, cloud, publish=True)

    @patch("setup_manager.library_status", return_value=False)
    @patch("setup_manager.app_identity", return_value=("example.test", "AAAAAAAAAA"))
    def test_unrecorded_artifact_never_republished(self, identity, library):
        with tempfile.TemporaryDirectory() as d:
            base = Path(d)
            meta = base / "app/Metadata.appintents/extract.actionsdata"
            meta.parent.mkdir(parents=True)
            meta.write_text(json.dumps(fixture()))
            local = base / "local"
            cloud = base / "cloud"
            inspect(base / "app", local, cloud)
            local.mkdir(mode=0o700)
            from status_loop_factory import workflow
            import plistlib
            (local / UNSIGNED).write_bytes(plistlib.dumps(workflow(fixture(), "example.test", "AAAAAAAAAA"), fmt=plistlib.FMT_BINARY))
            (local / SIGNED).write_bytes(b"legacy")
            with self.assertRaises(ValueError):
                inspect(base / "app", local, cloud, publish=True)
            self.assertFalse(cloud.exists())


if __name__ == "__main__":
    unittest.main()
