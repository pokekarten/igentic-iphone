"""Validate the 24-case native exploratory agent pilot, never raw model text."""
import argparse
import hashlib
import json
import re
import statistics
from pathlib import Path
from physical_classifier_receipt import manifest, PINS, REGISTRY

ADDITIONAL = {
    "lfm12": ("lfm12ResearchFiles", "LiquidAI/LFM2.5-1.2B-Instruct-MLX-4bit", "7ccafdb04c36936f4f1c4685198c6c9a40275932"),
    "qwen2b": ("qwen2bResearchFiles", "mlx-community/Qwen3.5-2B-4bit", "674aaa7240b91e8012fcad5d791b7dfe5ba90207"),
}
CANDIDATES = ("minicpm5", "qwen35", "qwen3", *ADDITIONAL)
THERMAL = r"(nominal|fair|serious|critical|unknown)"
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Tools/MLXModelLab/Sources/MLXProbe/AgentBenchmarkV1.swift"

def pin(candidate):
    if candidate not in ADDITIONAL:
        _, model, rev, files, size, digest = manifest(candidate)
        return model, rev, files, size, digest
    name, model, rev = ADDITIONAL[candidate]
    block = PINS.read_text().split(f"static let {name}: [Entry] = [", 1)[1].split("    ]", 1)[0]
    entries = sorted((n, int(s), h) for n, s, h in re.findall(r'\.init\(name: "([^"]+)", bytes: ([0-9]+), digest: "([a-f0-9]{64})"\)', block))
    if not entries or len(entries) != len({x[0] for x in entries}):
        raise ValueError("invalid pinned inventory")
    digest = hashlib.sha256(json.dumps(entries, separators=(",", ":")).encode()).hexdigest()
    return model, rev, len(entries), sum(e[1] for e in entries), digest

def category(i):
    return "positive" if i <= 12 else "missing" if i <= 16 else "unsupported" if i <= 20 else "deny"

def number(s):
    if s in ("NA", "-1"):
        return None
    v = int(s)
    if v < 0:
        raise ValueError("invalid negative measurement")
    return v

def normalize(candidate, raw):
    if candidate not in CANDIDATES:
        raise ValueError("unknown candidate")
    model, rev, files, size, digest = pin(candidate)
    prefix = "AGENT_V1_" + candidate.upper()
    lines = raw.splitlines()
    if not 2 <= len(lines) <= 26:
        raise ValueError("wrong receipt length")
    l = re.fullmatch(prefix + r"_LOAD=completed; files=([0-9]+); bytes=([0-9]+); milliseconds=([0-9]+); footprintBefore=(NA|[0-9]+); footprintAfter=(NA|[0-9]+); thermal="+THERMAL, lines[0])
    if not l or (int(l[1]), int(l[2])) != (files, size):
        raise ValueError("load inventory mismatch")
    rows = []
    for i, line in enumerate(lines[1:-1], 1):
        m = re.fullmatch(prefix+r"_CASE=([0-9]+); category=(positive|missing|unsupported|deny); pass=(true|false); calls=([0-9]+); rejected=(true|false); tokens=(-?[0-9]+); promptTokens=(-?[0-9]+); prefillMs=(-?[0-9]+); decodeMs=(-?[0-9]+); firstEventMs=(-?[0-9]+); milliseconds=([0-9]+); footprint=(NA|[0-9]+); thermal="+THERMAL, line)
        if not m or int(m[1]) != i or m[2] != category(i):
            raise ValueError("wrong case sequence or category")
        passed, calls, rejected, tokens = m[3]=="true", int(m[4]), m[5]=="true", number(m[6])
        if tokens is not None and tokens > 96:
            raise ValueError("token cap exceeded")
        if passed and (rejected or tokens is None or not 1 <= tokens < 96 or calls != (1 if m[2]=="positive" else 0)):
            raise ValueError("inconsistent accepted case")
        if rows and rows[-1]["thermal"] not in ("nominal", "fair"):
            raise ValueError("continued after thermal stop signal")
        rows.append({"case":i,"language":"en" if i%2 else "de","category":m[2],"passed":passed,"calls":calls,"parser_rejected":rejected,"tokens":tokens,"prompt_tokens":number(m[7]),"prefill_ms":number(m[8]),"decode_ms":number(m[9]),"first_event_ms":number(m[10]),"elapsed_ms":int(m[11]),"footprint_bytes":number(m[12]),"thermal":m[13]})
    pos=sum(r["passed"] and r["category"]=="positive" for r in rows)
    neg=sum(r["passed"] and r["category"]!="positive" for r in rows)
    bad=sum(r["category"]!="positive" and (r["calls"]>0 or r["parser_rejected"]) for r in rows)
    capped=sum(r["tokens"] is not None and r["tokens"]>=96 for r in rows)
    state="completed" if len(rows)==24 else ("resourceStopped" if candidate=="qwen2b" and lines[-1].startswith(prefix+"=resourceStopped;") else "thermalStopped")
    if lines[-1]!=f"{prefix}={state}; passed={pos+neg}; positive={pos}; negative={neg}; falseCalls={bad}; capped={capped}; completed={len(rows)}; total=24; actionsExecuted=0":
        raise ValueError("aggregate or action mismatch")
    samples=[v for v in [number(l[4]),number(l[5]),*[r["footprint_bytes"] for r in rows]] if v is not None]
    return {"schema":"igentic.agent.pilot.v1","candidate":candidate,"model":model,"revision":rev,"artifact_manifest_sha256":digest,"artifact_files":files,"artifact_bytes":size,"reference_source_sha256":hashlib.sha256(SOURCE.read_bytes()).hexdigest(),"receipt_sha256":hashlib.sha256(raw.encode()).hexdigest(),"status":state,"runtime":"mlx_swift","load_ms":int(l[3]),"footprint_before_bytes":number(l[4]),"footprint_after_bytes":number(l[5]),"max_sampled_footprint_bytes":max(samples) if samples else None,"thermal_after_load":l[6],"cases":rows,"summary":{"exact":pos+neg,"positive":pos,"negative":neg,"negative_call_or_rejection":bad,"capped":capped,"completed":len(rows),"total":24,"median_case_ms":statistics.median(r["elapsed_ms"] for r in rows) if rows else None,"de_passed":sum(r["passed"] and r["language"]=="de" for r in rows),"en_passed":sum(r["passed"] and r["language"]=="en" for r in rows)},"actions_executed":0,"unmeasured":["true_peak_ram","system_memory","energy","raw_first_token_latency"]}

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("candidate",choices=CANDIDATES);p.add_argument("receipt",type=Path);a=p.parse_args()
    print(json.dumps(normalize(a.candidate,a.receipt.read_text()),indent=2,sort_keys=True,allow_nan=False))
