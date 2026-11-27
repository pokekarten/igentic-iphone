import unittest
from agent_v1_receipt import CANDIDATES,pin,normalize,category

def fixture(candidate="qwen35"):
    _,_,files,size,_=pin(candidate);p="AGENT_V1_"+candidate.upper()
    lines=[f"{p}_LOAD=completed; files={files}; bytes={size}; milliseconds=50; footprintBefore=100; footprintAfter=200; thermal=nominal"]
    for i in range(1,25):
        lines.append(f"{p}_CASE={i}; category={category(i)}; pass=true; calls={1 if i<=12 else 0}; rejected=false; tokens=5; promptTokens=100; prefillMs=10; decodeMs=20; firstEventMs=15; milliseconds=32; footprint=250; thermal=nominal")
    lines.append(f"{p}=completed; passed=24; positive=12; negative=12; falseCalls=0; capped=0; completed=24; total=24; actionsExecuted=0")
    return "\n".join(lines)+"\n"

class PilotTests(unittest.TestCase):
    def test_all_pins(self):
        for c in CANDIDATES:
            r=normalize(c,fixture(c));self.assertEqual(r["summary"]["exact"],24);self.assertEqual(r["max_sampled_footprint_bytes"],250)
    def test_wrong_category_and_action(self):
        for s in [fixture().replace("actionsExecuted=0","actionsExecuted=1"),fixture().replace("category=missing","category=positive"),fixture().replace("tokens=5;","tokens=96;"),fixture().replace("footprint=250; thermal=nominal","footprint=250; thermal=serious")]:
            with self.assertRaises(ValueError):normalize("qwen35",s)
    def test_missing_telemetry(self):
        r=normalize("qwen35",fixture().replace("footprintBefore=100","footprintBefore=NA").replace("firstEventMs=15","firstEventMs=-1"))
        self.assertIsNone(r["footprint_before_bytes"]);self.assertIsNone(r["cases"][0]["first_event_ms"])
    def test_partial(self):
        lines=fixture().splitlines();lines=lines[:7]+["AGENT_V1_QWEN35=thermalStopped; passed=6; positive=6; negative=0; falseCalls=0; capped=0; completed=6; total=24; actionsExecuted=0"]
        lines[-2]=lines[-2].replace("thermal=nominal","thermal=serious")
        r=normalize("qwen35","\n".join(lines)+"\n");self.assertEqual(r["status"],"thermalStopped");self.assertEqual(r["summary"]["completed"],6)
    def test_resource_stop_not_completed(self):
        lines=fixture("qwen2b").splitlines()
        lines=lines[:7]+["AGENT_V1_QWEN2B=resourceStopped; passed=6; positive=6; negative=0; falseCalls=0; capped=0; completed=6; total=24; actionsExecuted=0"]
        r=normalize("qwen2b","\n".join(lines)+"\n")
        self.assertEqual(r["status"],"resourceStopped")
        self.assertEqual(r["summary"]["completed"],6)
        with self.assertRaises(ValueError):
            normalize("qwen35","\n".join(line.replace("QWEN2B","QWEN35") for line in lines)+"\n")
if __name__=="__main__":unittest.main()
