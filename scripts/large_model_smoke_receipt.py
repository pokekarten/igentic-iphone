"""Validate the bounded Qwen3 4B text smoke metadata, not hardware identity."""
import argparse
import hashlib
import json
import re
from pathlib import Path

PREFIX = "QWEN3TEXT4B_SMOKE"
ROOT = Path(__file__).resolve().parents[1]
MODEL = "mlx-community/Qwen3-4B-Instruct-2507-4bit"
REVISION = "50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b"
FILES = 14
BYTES = 2278990177
WEIGHTS = 2263022417
RESERVE = 1073741824

def normalize(raw):
    lines = raw.splitlines()
    result = {"schema": "igentic.large_model_smoke.v1", "model": MODEL, "revision": REVISION,
              "receipt_sha256": hashlib.sha256(raw.encode()).hexdigest(),
              "reference_source_sha256": hashlib.sha256((ROOT/"Tools/MLXModelLab/Sources/MLXProbe/LargeModelSmoke.swift").read_bytes()).hexdigest(),
              "hardware_attestation": False, "actions_executed": 0}
    if len(lines) == 1:
        m = re.fullmatch(PREFIX+r"=memoryOrThermalBlocked; available=([0-9]+); actionsExecuted=0", lines[0])
        if m:
            return dict(result, status="memoryOrThermalBlocked", available_bytes=int(m[1]), load_completed=False, completed=0, passed=None)
        if lines[0] == PREFIX+"=integrityRejected; actionsExecuted=0":
            return dict(result, status="integrityRejected", load_completed=False, completed=0, passed=None)
        if lines[0] == PREFIX+"=failed; actionsExecuted=0":
            return dict(result, status="failed", load_completed=None, completed=None, passed=None)
        raise ValueError("unrecognized terminal receipt")
    if not 2 <= len(lines) <= 5:
        raise ValueError("wrong receipt length")
    l = re.fullmatch(PREFIX+r"_LOAD=completed; files=([0-9]+); bytes=([0-9]+); milliseconds=([0-9]+); availableBefore=([0-9]+); availableAfter=([0-9]+)",lines[0])
    if not l or (int(l[1]),int(l[2])) != (FILES,BYTES) or int(l[4]) < WEIGHTS+RESERVE:
        raise ValueError("load inventory or memory gate mismatch")
    rows=[]
    for i,line in enumerate(lines[1:-1],1):
        m=re.fullmatch(PREFIX+r"_CASE=([1-3]); pass=(true|false); tokens=(-?[0-9]+); milliseconds=([0-9]+); available=([0-9]+); nominal=(true|false)",line)
        if not m or int(m[1])!=i:
            raise ValueError("case sequence mismatch")
        if rows and (not rows[-1]["nominal"] or rows[-1]["available_bytes"]<536870912):
            raise ValueError("continued after resource warning")
        n=int(m[3]);passed=m[2]=="true"
        if not -1<=n<=32 or (passed and not 1<=n<32):
            raise ValueError("invalid token count")
        rows.append({"case":i,"passed":passed,"tokens":None if n==-1 else n,"elapsed_ms":int(m[4]),"available_bytes":int(m[5]),"nominal":m[6]=="true"})
    passed=sum(r["passed"] for r in rows)
    status="completed" if len(rows)==3 else "resourceStopped"
    if lines[-1]!=f"{PREFIX}={status}; passed={passed}; completed={len(rows)}; total=3; actionsExecuted=0":
        if lines[-1]==PREFIX+"=failed; actionsExecuted=0":
            status="failed"
        else:
            raise ValueError("summary mismatch")
    return dict(result,status=status,load_completed=True,load_ms=int(l[3]),available_before_bytes=int(l[4]),available_after_bytes=int(l[5]),cases=rows,completed=len(rows),passed=passed,total=3)

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("receipt",type=Path);a=p.parse_args()
    print(json.dumps(normalize(a.receipt.read_text()),sort_keys=True,indent=2,allow_nan=False))
