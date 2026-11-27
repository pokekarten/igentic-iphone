import unittest
from resource_v1_receipt import normalize
S="RESOURCE_V1_QWEN3=completed; cases=3; total=3; tokens=120; elapsedMs=2000; loadMs=300; baseline=100; loaded=300; sampledPeak=500; availableStart=1000; availableMin=600; availableEnd=700; mlxPeak=400; thermalStart=0; thermalMax=1; thermalEnd=1; samples=25; actionsExecuted=0\n"
class ReceiptTests(unittest.TestCase):
    def test_complete(self):
        r=normalize("qwen3",S);self.assertEqual(r["max_sampled_app_footprint_bytes"],500);self.assertEqual(r["thermal_max"],"fair")
    def test_blocked(self):
        self.assertEqual(normalize("apple","RESOURCE_V1_APPLE=resourceBlocked; actionsExecuted=0\n")["completed"],0)
    def test_apple(self):
        s=S.replace("QWEN3","APPLE").replace("tokens=120","tokens=NA").replace("loadMs=300","loadMs=NA").replace("loaded=300","loaded=NA").replace("mlxPeak=400","mlxPeak=NA")
        self.assertIsNone(normalize("apple",s)["mlx_peak_active_bytes"])
        with self.assertRaises(ValueError):normalize("apple",S.replace("QWEN3","APPLE"))
    def test_reject(self):
        for s in [S.replace("actionsExecuted=0","actionsExecuted=1"),S.replace("cases=3","cases=2"),S.replace("tokens=120","tokens=193"),S.replace("sampledPeak=500","sampledPeak=200"),S.replace("thermalMax=1","thermalMax=0")]:
            with self.assertRaises(ValueError):normalize("qwen3",s)
if __name__=="__main__":unittest.main()
