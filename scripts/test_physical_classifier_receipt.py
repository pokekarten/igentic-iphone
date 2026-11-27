import unittest
from physical_classifier_receipt import REGISTRY, manifest, normalize

def fixture(candidate="qwen35"):
    p, _, _, n, size, _ = manifest(candidate)
    return "\n".join([f"{p}_INTEGRITY=verified; files={n}; bytes={size}",
        f"{p}_LOAD=completed; milliseconds=100"] +
        [f"{p}_CASE={i}; outcome=pass; tokens=2; milliseconds=80" for i in range(1,13)] +
        [f"{p}_RESEARCH=completed; passed=12; total=12; holdout=6; actionsExecuted=0"])

class ReceiptTests(unittest.TestCase):
    def test_all_candidates(self):
        for candidate in REGISTRY:
            r = normalize(candidate, fixture(candidate))
            self.assertEqual(r["summary"]["passed"], 12)
            self.assertEqual(r["summary"]["de_passed"], 6)
            self.assertEqual(r["summary"]["en_passed"], 6)
            self.assertEqual(len(r["artifact_manifest_sha256"]), 64)

    def test_reject_incomplete_duplicate_order_and_wrong_candidate(self):
        s = fixture()
        lines = s.splitlines()
        for bad in ["\n".join(lines[:-1]), s+"\n"+lines[2], s.replace("_CASE=3;", "_CASE=2;"), s.replace("files=12;", "files=11;")]:
            with self.assertRaises(ValueError):
                normalize("qwen35", bad)
        with self.assertRaises(ValueError):
            normalize("qwen3", s)

    def test_reject_wrong_aggregates_and_unsafe(self):
        for bad in [fixture().replace("passed=12;", "passed=11;"), fixture().replace("holdout=6;", "holdout=5;"), fixture().replace("actionsExecuted=0","actionsExecuted=1"), fixture().replace("tokens=2;", "tokens=16;"), fixture().replace("tokens=2;", "tokens=-1;")]:
            with self.assertRaises(ValueError):
                normalize("qwen35", bad)

    def test_caps_and_no_raw_transport(self):
        s = fixture().replace("outcome=pass; tokens=2;", "outcome=reject; tokens=16;").replace("passed=12;", "passed=0;").replace("holdout=6;", "holdout=0;")
        r = normalize("qwen35", "untrusted unrelated transport text\n"+s)
        self.assertEqual(r["summary"]["token_caps"], 12)
        self.assertEqual(r["summary"]["passed"], 0)
        self.assertNotIn("untrusted", str(r))

if __name__ == "__main__":
    unittest.main()
