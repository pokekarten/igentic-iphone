#!/usr/bin/env python3
"""Explicitly launch the already-installed isolated 4B research lab; no install."""
import argparse
import json
import os
import select
import subprocess
import time
from pathlib import Path
from large_model_smoke_receipt import normalize,PREFIX

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device",required=True)
    parser.add_argument("--output",required=True,type=Path)
    a=parser.parse_args()
    a.output.mkdir(mode=0o700,parents=True,exist_ok=False)
    cmd=["xcrun","devicectl","device","process","launch","--device",a.device,
         "--timeout","20","--terminate-existing","--console","de.bos.igentic.diagnostics",
         "--","--qwen3-text4b-smoke","qwen3text4b"]
    start=time.monotonic();end=start+90
    proc=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);buf=b"";lines=[]
    try:
        while time.monotonic()<end:
            if select.select([proc.stdout],[],[],1)[0]:
                data=os.read(proc.stdout.fileno(),4096)
                if not data:break
                buf+=data
                while b"\n" in buf:
                    line,buf=buf.split(b"\n",1)
                    line=line.rstrip(b"\r")
                    if len(line)>65536:raise ValueError("oversized transport line")
                    if line.startswith((PREFIX+"_").encode()) or line.startswith((PREFIX+"=").encode()):
                        lines.append(line.decode("ascii"))
                        if len(lines)>5:raise ValueError("unexpected extra receipt")
                if len(buf)>65536:raise ValueError("oversized transport buffer")
                if any(x.startswith(PREFIX+"=") for x in lines):break
            elif proc.poll() is not None:break
    finally:
        if proc.poll() is None:proc.terminate()
        try:proc.wait(timeout=5)
        except subprocess.TimeoutExpired:proc.kill();proc.wait()
    raw="\n".join(lines)+"\n"
    try:r=normalize(raw)
    except ValueError:
        print(json.dumps({"status":"receiptRejected","completed":None}));return 2
    r["launch_and_cleanup_ms"]=round((time.monotonic()-start)*1000)
    (a.output/"smoke.receipt.txt").write_text(raw)
    (a.output/"smoke.json").write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
    print(json.dumps(r,sort_keys=True))
    return 0 if r["status"]=="completed" else 2
if __name__=="__main__":raise SystemExit(main())
