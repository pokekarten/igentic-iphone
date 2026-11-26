import copy
import plistlib
import unittest
from status_loop_factory import ADVANCE, START, check_metadata, workflow


def fixture():
    return {"actions": {
        START: {"identifier": START, "isDiscoverable": True, "parameters": []},
        ADVANCE: {"identifier": ADVANCE, "isDiscoverable": True,
                  "parameters": [{"name": n} for n in ("taskID", "modelReply", "finishAfterRead")]},
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
            data["actions"][ADVANCE]["parameters"] = [{"name": n} for n in names]
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

    def test_no_unsigned_identity(self):
        with self.assertRaisesRegex(ValueError, "signing identity"):
            workflow(fixture(), "example.test", "not-signed")


if __name__ == "__main__":
    unittest.main()
