import copy
import stat
import tempfile
from pathlib import Path
import plistlib
import unittest
from status_loop_factory import ADVANCE, START, check_metadata, workflow, write_private_candidate


def primitive(kind):
    return {"primitive": {"wrapper": {"typeIdentifier": kind}}}


def param(name):
    return {"name": name, "isOptional": False,
            "valueType": primitive(1 if name == "finishAfterRead" else 0)}


def fixture():
    common = {"isDiscoverable": True, "outputType": primitive(0), "supportedModes": 1}
    return {"actions": {
        START: {**common, "identifier": START, "parameters": []},
        ADVANCE: {**copy.deepcopy(common), "identifier": ADVANCE,
                  "parameters": [param(n) for n in ("taskID", "modelReply", "finishAfterRead")]},
    }}


class FactoryTests(unittest.TestCase):
    def test_missing_stale_intent(self):
        data = fixture()
        del data["actions"][START]
        with self.assertRaisesRegex(ValueError, "Missing intent"):
            check_metadata(data)

    def test_schema_drift_or_duplicate(self):
        for names in (["taskID", "modelReply"], ["taskID", "modelReply", "finishAfterRead", "taskID"]):
            data = fixture()
            data["actions"][ADVANCE]["parameters"] = [param(n) for n in names]
            with self.assertRaisesRegex(ValueError, "Parameter contract"):
                check_metadata(data)

    def test_discoverability(self):
        data = fixture()
        data["actions"][START]["isDiscoverable"] = False
        with self.assertRaisesRegex(ValueError, "not discoverable"):
            check_metadata(data)

    def test_exact_two_turns_and_same_task(self):
        result = workflow(fixture(), "example.test", "AAAAAAAAAA")
        actions = plistlib.loads(plistlib.dumps(result, fmt=plistlib.FMT_BINARY))["WFWorkflowActions"]
        self.assertEqual(len(actions), 5)
        p = [a["WFWorkflowActionParameters"] for a in actions]
        self.assertEqual(p[2]["WFDictionaryKey"], "taskId")
        self.assertEqual(p[3]["taskID"], p[4]["taskID"])
        self.assertEqual(p[3]["taskID"]["Value"]["OutputUUID"], p[2]["UUID"])
        self.assertEqual(p[3]["modelReply"], '{"action":"status.read"}')
        self.assertEqual(p[4]["modelReply"], '{"action":"finish"}')
        self.assertIs(p[3]["finishAfterRead"], False)
        self.assertEqual([a["WFWorkflowActionIdentifier"] for a in actions],
                         ["example.test."+START, "is.workflow.actions.detect.dictionary",
                          "is.workflow.actions.getvalueforkey", "example.test."+ADVANCE,
                          "example.test."+ADVANCE])
        self.assertEqual(result, workflow(fixture(), "example.test", "AAAAAAAAAA"))

    def test_type_mode_and_optional_drift(self):
        for mutate in (
            lambda d: d[START].update(outputType=primitive(1)),
            lambda d: d[START].update(supportedModes=2),
            lambda d: d[ADVANCE]["parameters"][0].update(valueType=primitive(1)),
            lambda d: d[ADVANCE]["parameters"][1].update(isOptional=True),
            lambda d: d[ADVANCE]["parameters"][2].update(valueType=primitive(True)),
        ):
            data = fixture()
            mutate(data["actions"])
            with self.assertRaisesRegex(ValueError, "Invalid"):
                check_metadata(data)

    def test_private_exclusive_output(self):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / "candidate.shortcut"
            write_private_candidate(p, b"candidate")
            self.assertEqual(stat.S_IMODE(p.stat().st_mode), 0o600)
            with self.assertRaises(FileExistsError):
                write_private_candidate(p, b"overwrite")
            self.assertEqual(p.read_bytes(), b"candidate")
            symlink = Path(directory) / "link.shortcut"
            symlink.symlink_to(p)
            with self.assertRaises(FileExistsError):
                write_private_candidate(symlink, b"overwrite")
            self.assertEqual(p.read_bytes(), b"candidate")

    def test_no_unsigned_identity(self):
        with self.assertRaisesRegex(ValueError, "signing identity"):
            workflow(fixture(), "example.test", "not-signed")


if __name__ == "__main__":
    unittest.main()
