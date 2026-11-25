#!/usr/bin/env python3
"""Opt-in Mac MLX native tool-format smoke; never executes an action.

The quantized community snapshot is not the canonical upstream Benchmark V0
artifact. This is a two-case synthetic runtime smoke, not a quality benchmark.
"""
from __future__ import annotations

import argparse
import importlib.metadata
import json
import os
from pathlib import Path
import time

from ollama_local_output_probe import classify_generated_text
from qwen3_baseline_adapter import normalize_record

MODEL_ID = "mlx-community/Qwen3-0.6B-4bit"
REVISION = "73e3e38d981303bc594367cd910ea6eb48349da8"
MAX_TOKENS = 64
PROMPTS = (
    ("en", "Propose a read-only diagnostics check."),
    ("de", "Schlage eine rein lesende Diagnose vor."),
)
SYSTEM = "Call igentic_propose_action exactly once. Set approved to false. No prose."
TOOLS = [{
    "type": "function",
    "function": {
        "name": "igentic_propose_action",
        "description": "Propose a read-only synthetic diagnostic preview; never approve or execute.",
        "parameters": {
            "type": "object",
            "properties": {
                "action": {"type": "string", "enum": ["diagnostics.read"]},
                "approved": {"type": "boolean", "enum": [False]},
            },
            "required": ["action", "approved"],
            "additionalProperties": False,
        },
    },
}]


def classify_native_output(raw: object, tokens: int) -> str:
    if type(tokens) is not int or not 0 <= tokens < MAX_TOKENS:
        return "invalid_or_capped_generation"
    if not isinstance(raw, str) or len(raw.encode("utf-8")) > 2048:
        return "invalid_output"
    normalized = normalize_record({"case_id": "synthetic", "assistant_text": raw})
    if "normalizerError" in normalized:
        return "invalid_native_envelope"
    if set(normalized) != {"case_id", "action", "approved"}:
        return "invalid_schema"
    return classify_generated_text(json.dumps({
        "action": normalized["action"], "approved": normalized["approved"],
    }))


def run_smoke() -> dict:
    # Set before importing MLX/HF; do not download or run remote custom code.
    os.environ["HF_HUB_OFFLINE"] = "1"
    os.environ["TRANSFORMERS_OFFLINE"] = "1"
    snapshot = (Path.home() / ".cache/huggingface/hub" /
                "models--mlx-community--Qwen3-0.6B-4bit" / "snapshots" / REVISION)
    if not snapshot.is_dir():
        return {"status": "local_snapshot_missing"}
    from mlx_lm import load, stream_generate
    from mlx_lm.sample_utils import make_sampler

    start = time.monotonic()
    model, tokenizer = load(str(snapshot), tokenizer_config={"trust_remote_code": False})
    evidence = {
        "model_id": MODEL_ID, "snapshot_revision": REVISION,
        "mlx_lm": importlib.metadata.version("mlx-lm"),
        "mlx": importlib.metadata.version("mlx"),
        "load_seconds": round(time.monotonic() - start, 3),
        "cases": [],
    }
    for language, prompt in PROMPTS:
        start = time.monotonic()
        rendered = tokenizer.apply_chat_template(
            [{"role": "system", "content": SYSTEM}, {"role": "user", "content": prompt}],
            tools=TOOLS, tokenize=False, add_generation_prompt=True, enable_thinking=False,
        )
        raw, tokens = "", 0
        for part in stream_generate(model, tokenizer, prompt=rendered,
                                    max_tokens=MAX_TOKENS, sampler=make_sampler(temp=0)):
            raw += part.text
            tokens = part.generation_tokens
        evidence["cases"].append({
            "language": language, "output_tokens": tokens,
            "seconds": round(time.monotonic() - start, 3),
            "disposition": classify_native_output(raw, tokens),
        })
    evidence["status"] = ("synthetic_preview_only"
                          if all(c["disposition"] == "synthetic_preview_only"
                                 for c in evidence["cases"])
                          else "output_rejected")
    return evidence


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true", help="explicit local inference opt-in")
    args = parser.parse_args()
    if not args.run:
        print(json.dumps({"status": "skipped_opt_in_required"}))
        return 0
    try:
        evidence = run_smoke()
    except Exception:
        # Never leak a path, generated output or provider exception details.
        evidence = {"status": "local_runtime_unavailable"}
    print(json.dumps(evidence, sort_keys=True))
    return 0 if evidence["status"] == "synthetic_preview_only" else 1


if __name__ == "__main__":
    raise SystemExit(main())
