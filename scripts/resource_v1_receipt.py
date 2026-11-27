"""Normalize native short resource-pilot receipts; app footprint is not system RAM."""
import argparse
import hashlib
import json
import re
from pathlib import Path

CANDIDATES = ("apple","qwen3text4b","qwen2b","qwen35","qwen3","lfm12","minicpm5","lfm","granite350","smol135","falcon90")
SOURCE = Path(__file__).resolve().parents[1]/"Tools/MLXModelLab/Sources/MLXProbe/ResourcePilot.swift"
FIELDS = ("tokens","elapsedMs","loadMs","baseline","loaded","sampledPeak","availableStart","availableMin","availableEnd","mlxPeak","thermalStart","thermalMax","thermalEnd","samples")
THERMAL = ("nominal","fair","serious","critical","unknown")

def normalize(candidate, raw):
    if candidate not in CANDIDATES: raise ValueError("unknown candidate")
    prefix = "RESOURCE_V1_"+candidate.upper()
    result = {"schema":"igentic.resource.pilot.v1","candidate":candidate,
              "reference_source_sha256":hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              "receipt_sha256":hashlib.sha256(raw.encode()).hexdigest(),
              "hardware_attestation":False,"actions_executed":0}
    blocked = re.fullmatch(prefix+r"=(integrityRejected|resourceBlocked|unavailable); actionsExecuted=0\n",raw)
    if blocked: return dict(result,status=blocked[1],completed=0,total=3)
    pattern = prefix+r"=(completed|resourceStopped|failed); cases=([0-3]); total=3"
    optional = {"tokens","loadMs","baseline","loaded","sampledPeak","mlxPeak"}
    for field in FIELDS: pattern+=r"; "+field+r"="+(r"(NA|[0-9]+)" if field in optional else r"([0-9]+)")
    m=re.fullmatch(pattern+r"; actionsExecuted=0\n",raw)
    if not m: raise ValueError("invalid receipt")
    d={k:None if v=="NA" else int(v) for k,v in zip(FIELDS,m.groups()[2:])}
    n=int(m[2]);status=m[1]
    if (status=="completed")!=(n==3) or d["samples"]<2 or d["samples"]>1520: raise ValueError("invalid completion or sample count")
    if any(not 0<=d[k]<=4 for k in ("thermalStart","thermalMax","thermalEnd")) or d["thermalMax"]<max(d["thermalStart"],d["thermalEnd"]): raise ValueError("thermal mismatch")
    if d["availableMin"]>min(d["availableStart"],d["availableEnd"]): raise ValueError("inconsistent sampled allowance")
    if d["sampledPeak"] is not None and any(v is not None and v>d["sampledPeak"] for v in (d["baseline"],d["loaded"])): raise ValueError("inconsistent sampled peak")
    if candidate=="apple":
        if any(d[k] is not None for k in ("tokens","loadMs","loaded","mlxPeak")): raise ValueError("invented Apple telemetry")
    else:
        if d["tokens"] is None or d["tokens"]>n*64 or d["mlxPeak"] is None: raise ValueError("invalid MLX telemetry")
        if status=="completed" and d["loadMs"] is None: raise ValueError("missing load time")
    return dict(result,status=status,completed=n,total=3,generated_tokens=d["tokens"],
        elapsed_ms=d["elapsedMs"],load_ms=d["loadMs"],baseline_app_footprint_bytes=d["baseline"],
        loaded_app_footprint_bytes=d["loaded"],max_sampled_app_footprint_bytes=d["sampledPeak"],
        available_process_start_bytes=d["availableStart"],min_sampled_available_process_bytes=d["availableMin"],
        available_process_end_bytes=d["availableEnd"],mlx_peak_active_bytes=d["mlxPeak"],
        thermal_start=THERMAL[d["thermalStart"]],thermal_max=THERMAL[d["thermalMax"]],
        thermal_end=THERMAL[d["thermalEnd"]],sample_count=d["samples"],
        unmeasured=["actual_temperature_celsius","true_peak_app_ram","total_system_model_ram","energy","sustained_thermal_performance"])

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("candidate",choices=CANDIDATES);p.add_argument("receipt",type=Path);a=p.parse_args()
    print(json.dumps(normalize(a.candidate,a.receipt.read_text()),sort_keys=True,indent=2,allow_nan=False))
