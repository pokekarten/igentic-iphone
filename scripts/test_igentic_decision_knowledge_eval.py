import json
import unittest
from unittest.mock import patch
import igentic_decision_knowledge_eval as ev


class DecisionKnowledgeTests(unittest.TestCase):
    def setUp(self):
        self.cases = ev.load_cases()
        self.case = next(c for c in self.cases if c["id"] == "contradiction-de")

    def test_all_expected(self):
        for c in self.cases:
            self.assertEqual(ev.classify(json.dumps(c["expected"]), c)["status"], "exact")

    def test_bilingual_families(self):
        self.assertEqual(len({c["family"] for c in self.cases}), 8)
        for c in self.cases:
            peer = next(p for p in self.cases if p["family"] == c["family"] and p["language"] != c["language"])
            self.assertEqual(c["expected"], peer["expected"])

    def test_answer_not_in_prompt(self):
        for c in self.cases:
            self.assertEqual(set(json.loads(ev.prompt_for(c))), {"query", "evidence"})

    def test_duplicate_fields(self):
        raw = '{"decision":"abstain","decision":"propose","relation":"contradicted","citations":["s1"]}'
        self.assertEqual(ev.classify(raw, self.case)["status"], "invalid_format")

    def test_unknown_citation(self):
        value = dict(self.case["expected"], citations=["s99"])
        self.assertEqual(ev.classify(json.dumps(value), self.case)["status"], "invalid_format")

    def test_duplicate_citation(self):
        value = dict(self.case["expected"], citations=["s1", "s1"])
        self.assertEqual(ev.classify(json.dumps(value), self.case)["status"], "invalid_format")

    def test_unsafe_proposal(self):
        value = dict(self.case["expected"], decision="propose")
        result = ev.classify(json.dumps(value), self.case)
        self.assertTrue(result["unsafe_proposal"])
        self.assertEqual(result["status"], "inconsistent")

    def test_extra_authority(self):
        value = dict(self.case["expected"], approved=True)
        self.assertEqual(ev.classify(json.dumps(value), self.case)["status"], "invalid_format")

    def test_no_repair(self):
        raw = json.dumps(self.case["expected"])
        self.assertEqual(ev.classify("text " + raw, self.case)["status"], "invalid_format")

    def test_capped(self):
        self.assertEqual(ev.classify(json.dumps(self.case["expected"]), self.case, capped=True)["status"], "capped")

    def test_default_does_not_infer(self):
        with patch("sys.argv", ["eval"]), patch.object(ev, "run_mlx") as run:
            self.assertEqual(ev.main(), 0)
            run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
