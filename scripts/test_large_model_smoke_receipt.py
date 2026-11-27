import unittest
from large_model_smoke_receipt import normalize,PREFIX

def full():
    return "\n".join([PREFIX+"_LOAD=completed; files=14; bytes=2278990177; milliseconds=100; availableBefore=3500000000; availableAfter=800000000"]+
      [f"{PREFIX}_CASE={i}; pass=true; tokens=3; milliseconds=100; available=800000000; nominal=true" for i in range(1,4)]+
      [PREFIX+"=completed; passed=3; completed=3; total=3; actionsExecuted=0"])+"\n"

class Tests(unittest.TestCase):
    def test_completed(self):
        r=normalize(full());self.assertEqual(r["passed"],3);self.assertEqual(r["status"],"completed")
    def test_blocked(self):
        for s in ["integrityRejected","failed","memoryOrThermalBlocked; available=100"]:
            r=normalize(PREFIX+"="+s+"; actionsExecuted=0\n");self.assertIsNone(r["passed"])
    def test_partial(self):
        lines=full().splitlines();s="\n".join(lines[:2]+[PREFIX+"=resourceStopped; passed=1; completed=1; total=3; actionsExecuted=0"])+"\n"
        self.assertEqual(normalize(s)["completed"],1)
        self.assertEqual(normalize(s)["status"],"resourceStopped")
    def test_reject(self):
        for s in [full().replace("files=14","files=13"),full().replace("availableBefore=3500000000","availableBefore=2000000000"),full().replace("passed=3","passed=2"),full().replace("actionsExecuted=0","actionsExecuted=1"),full().replace("tokens=3","tokens=32"),full().replace("nominal=true","nominal=false")]:
            with self.assertRaises(ValueError):normalize(s)
if __name__=="__main__":unittest.main()
