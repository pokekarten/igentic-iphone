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

    def test_invalid_unicode_and_nonstandard_json(self):
        for raw in ("\ud800", '{"decision":"propose","relation":"supported","citations":[NaN]}'):
            self.assertEqual(ev.classify(raw, self.case)["status"], "invalid_format")

    def test_malformed_capped_generation_is_counted(self):
        row = ev.classify("{", self.case, capped=True)
        self.assertEqual(row["status"], "invalid_format")
        self.assertTrue(row["generation_capped"])
        summary = ev.summarize([dict(row, language="de")])
        self.assertEqual(summary["all"]["generation_capped"], 1)

    def test_fixture_validation_rejects_duplicate_sources_and_identity(self):
        import copy
        for kind in ("source", "language", "id"):
            cases = copy.deepcopy(self.cases)
            if kind == "source":
                cases[0]["evidence"].append(cases[0]["evidence"][0])
            elif kind == "language":
                cases[0]["language"] = "fr"
            else:
                cases[0]["id"] = cases[1]["id"]
            with self.assertRaises(ValueError):
                ev.validate_cases(cases)

    def test_candidate_pins_and_weight_validation(self):
        import hashlib
        import tempfile
        from pathlib import Path
        self.assertEqual(set(ev.CANDIDATES), set(ev.WEIGHT_PINS))
        self.assertEqual(len(ev.CANDIDATES), 3)
        for size, digest in ev.WEIGHT_PINS.values():
            self.assertGreater(size, 0)
            self.assertRegex(digest, r"^[0-9a-f]{64}$")
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "model.safetensors"
            pin = (3, hashlib.sha256(b"abc").hexdigest())
            with self.assertRaises(RuntimeError):
                ev.verify_weights(path, pin)
            path.write_bytes(b"abc")
            self.assertEqual(ev.verify_weights(path, pin), pin[1])
            path.write_bytes(b"abd")
            with self.assertRaises(RuntimeError):
                ev.verify_weights(path, pin)
            path.write_bytes(b"abcd")
            with self.assertRaises(RuntimeError):
                ev.verify_weights(path, pin)

    def test_candidate_selection_does_not_implicitly_infer(self):
        for candidate in ev.CANDIDATES:
            with patch("sys.argv", ["eval", "--candidate", candidate]), patch.object(ev, "run_mlx") as run:
                self.assertEqual(ev.main(), 0)
                run.assert_not_called()

    def test_default_does_not_infer(self):
        with patch("sys.argv", ["eval"]), patch.object(ev, "run_mlx") as run:
            self.assertEqual(ev.main(), 0)
            run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
