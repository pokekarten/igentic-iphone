#!/usr/bin/env python3
"""Execute the pinned Qwen3 0.6B Benchmark V0 baseline from a local snapshot."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import sys
from typing import Any

from qwen3_baseline_adapter import (
    BASELINE_SEEDS,
    MODEL_ID,
    MODEL_REVISION,
    NON_THINKING_GENERATION_KWARGS,
    TOOL_CALL_CLOSE,
    TOOL_CALL_OPEN,
    build_request,
)
from validate_action_benchmark import DEFAULT_BENCHMARK, ValidationError, validate_benchmark

PROFILES = {
    "Router-small": {"input_limit_tokens": 512, "max_new_tokens": 32},
    "Router-normal": {"input_limit_tokens": 1024, "max_new_tokens": 64},
}
MIN_TRANSFORMERS_VERSION = (4, 51, 0)
PROMPT_TEMPLATE_ID = "qwen3-tokenizer-chat-template"


def _version_tuple(value: str) -> tuple[int, int, int]:
    match = re.match(r"^(\d+)\.(\d+)\.(\d+)", value)
    if match is None:
        raise ValidationError(f"cannot interpret Transformers version: {value}")
    return tuple(int(part) for part in match.groups())


def validate_snapshot_dir(path: Path) -> Path:
    try:
        resolved = path.expanduser().resolve(strict=True)
    except OSError as exc:
        raise ValidationError(f"cannot resolve local model snapshot {path}: {exc}") from exc
    if not resolved.is_dir():
        raise ValidationError("model snapshot must be a local directory")
    if resolved.name != MODEL_REVISION:
        raise ValidationError(
            f"model snapshot directory must end in pinned revision {MODEL_REVISION}"
        )
    return resolved


def runtime_load_options() -> tuple[dict[str, bool], dict[str, bool | str]]:
    tokenizer_options: dict[str, bool] = {
        "local_files_only": True,
        "trust_remote_code": False,
    }
    model_options: dict[str, bool | str] = {
        **tokenizer_options,
        "torch_dtype": "auto",
    }
    return tokenizer_options, model_options


def host_environment() -> dict[str, str]:
    values = {
        "os": f"{platform.system()} {platform.release()}".strip(),
        "architecture": platform.machine(),
        "python_version": platform.python_version(),
    }
    if not all(values.values()):
        raise ValidationError("host environment provenance must be non-empty")
    return values


def tokenizer_chat_template_sha256(tokenizer: Any) -> str:
    """Hash the exact tokenizer chat-template object used by apply_chat_template."""
    template = getattr(tokenizer, "chat_template", None)
    if isinstance(template, str):
        if not template:
            raise ValidationError("tokenizer chat template must be non-empty")
        payload = template.encode("utf-8")
    elif isinstance(template, dict):
        if (
            not template
            or not all(
                isinstance(key, str)
                and key
                and isinstance(value, str)
                and value
                for key, value in template.items()
            )
        ):
            raise ValidationError(
                "tokenizer chat-template mapping must contain non-empty string templates"
            )
        payload = json.dumps(
            template,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        ).encode("utf-8")
    else:
        raise ValidationError(
            "tokenizer must expose a string or mapping chat_template for provenance"
        )
    return hashlib.sha256(payload).hexdigest()


def model_context_limit(model: Any) -> int:
    """Read the model's configured positional context capacity fail-closed."""
    config = getattr(model, "config", None)
    value = getattr(config, "max_position_embeddings", None)
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise ValidationError(
            "model config must expose a positive integer max_position_embeddings"
        )
    return value


def profile_config(profile: str) -> dict[str, int]:
    try:
        return dict(PROFILES[profile])
    except KeyError as exc:
        raise ValidationError(f"unsupported Benchmark V0 profile: {profile}") from exc


def plan_run_dirs(output_dir: Path, profile: str) -> dict[int, Path]:
    """Fail before execution when any target seed directory already exists."""
    profile_config(profile)
    run_dirs = {
        seed: output_dir / profile / f"seed-{seed}"
        for seed in BASELINE_SEEDS
    }
    existing = [path for path in run_dirs.values() if path.exists()]
    if existing:
        joined = ", ".join(str(path) for path in existing)
        raise ValidationError(
            f"refusing to start because seed run directories already exist: {joined}"
        )
    return run_dirs


def build_requests() -> list[dict[str, Any]]:
    return [build_request(record) for record in validate_benchmark(DEFAULT_BENCHMARK)]


def applied_generation_config(profile: str) -> dict[str, bool | float | int]:
    config = dict(NON_THINKING_GENERATION_KWARGS)
    config["max_new_tokens"] = profile_config(profile)["max_new_tokens"]
    return config


def effective_generation_config(
    model_generation_config: dict[str, Any], profile: str
) -> dict[str, Any]:
    """Bind inherited model defaults together with the exact runner overrides."""
    if not isinstance(model_generation_config, dict):
        raise ValidationError("model generation_config must serialize to an object")
    effective = dict(model_generation_config)
    effective.update(applied_generation_config(profile))
    return effective


def _token_count(input_ids: Any) -> int:
    shape = getattr(input_ids, "shape", None)
    if shape is not None and len(shape) >= 1:
        return int(shape[-1])
    if isinstance(input_ids, list):
        if input_ids and isinstance(input_ids[0], list):
            return len(input_ids[0])
        return len(input_ids)
    raise ValidationError("tokenizer input_ids do not expose a measurable sequence length")


def generation_cap_reached(generated_ids: Any, max_new_tokens: int) -> bool:
    """Conservatively flag output that consumed the full generation budget."""
    if isinstance(max_new_tokens, bool) or not isinstance(max_new_tokens, int) or max_new_tokens <= 0:
        raise ValidationError("max_new_tokens must be a positive integer")
    return _token_count(generated_ids) >= max_new_tokens


def repeated_proposal_envelope_detected(assistant_text: str) -> bool:
    """Detect repeated Qwen tool-call envelopes without semantic repair."""
    if not isinstance(assistant_text, str):
        raise ValidationError("decoded assistant output must be text")
    return (
        assistant_text.count(TOOL_CALL_OPEN) > 1
        or assistant_text.count(TOOL_CALL_CLOSE) > 1
    )


def render_and_preflight(
    tokenizer: Any, profile: str
) -> tuple[list[tuple[dict[str, Any], Any, int]], dict[str, int]]:
    limit = profile_config(profile)["input_limit_tokens"]
    rendered: list[tuple[dict[str, Any], Any, int]] = []
    counts: dict[str, int] = {}
    for request in build_requests():
        batch = tokenizer.apply_chat_template(
            request["messages"],
            tools=request["tools"],
            tokenize=True,
            return_dict=True,
            return_tensors="pt",
            **request["chat_template_kwargs"],
        )
        count = _token_count(batch["input_ids"])
        if count > limit:
            raise ValidationError(
                f"{request['case_id']} renders to {count} tokens; {profile} limit is {limit}"
            )
        rendered.append((request, batch, count))
        counts[request["case_id"]] = count
    return rendered, counts


def _write_json(path: Path, value: Any) -> None:
    path.write_text(
        json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False) + "\n",
        encoding="utf-8",
    )


def _write_jsonl(path: Path, values: list[dict[str, Any]]) -> None:
    path.write_text(
        "".join(
            json.dumps(value, ensure_ascii=False, sort_keys=True, allow_nan=False) + "\n"
            for value in values
        ),
        encoding="utf-8",
    )


def _load_runtime(snapshot: Path, device: str) -> tuple[Any, Any, Any, Any, str, str]:
    os.environ["HF_HUB_OFFLINE"] = "1"
    os.environ["TRANSFORMERS_OFFLINE"] = "1"
    try:
        import torch
        import transformers
    except ImportError as exc:
        raise ValidationError(
            "external host execution requires locally installed Transformers and PyTorch"
        ) from exc

    if _version_tuple(transformers.__version__) < MIN_TRANSFORMERS_VERSION:
        raise ValidationError("Qwen3 requires Transformers >= 4.51.0")

    tokenizer_options, model_options = runtime_load_options()
    tokenizer = transformers.AutoTokenizer.from_pretrained(str(snapshot), **tokenizer_options)
    model = transformers.AutoModelForCausalLM.from_pretrained(str(snapshot), **model_options)
    model.to(device)
    model.eval()
    return tokenizer, model, transformers.set_seed, torch, transformers.__version__, torch.__version__


def run(snapshot: Path, profile: str, output_dir: Path, device: str) -> None:
    snapshot = validate_snapshot_dir(snapshot)
    run_dirs = plan_run_dirs(output_dir, profile)
    tokenizer, model, set_seed, torch, transformers_version, torch_version = _load_runtime(
        snapshot, device
    )
    prompt_template_sha256 = tokenizer_chat_template_sha256(tokenizer)
    context_limit_tokens = model_context_limit(model)
    profile_values = profile_config(profile)
    if (
        profile_values["input_limit_tokens"] + profile_values["max_new_tokens"]
        > context_limit_tokens
    ):
        raise ValidationError(
            "selected Benchmark V0 profile exceeds the model context capacity"
        )
    rendered, token_counts = render_and_preflight(tokenizer, profile)
    generation = applied_generation_config(profile)
    effective_generation = effective_generation_config(
        model.generation_config.to_dict(), profile
    )
    environment = host_environment()

    for seed in BASELINE_SEEDS:
        run_dir = run_dirs[seed]
        run_dir.mkdir(parents=True)
        set_seed(seed)
        outputs: list[dict[str, Any]] = []
        with torch.inference_mode():
            for request, batch, input_tokens in rendered:
                model_batch = batch.to(device) if hasattr(batch, "to") else batch
                generated = model.generate(**model_batch, **generation)
                generated_ids = generated[0][input_tokens:]
                assistant_text = tokenizer.decode(
                    generated_ids, skip_special_tokens=True
                )
                outputs.append(
                    {
                        "case_id": request["case_id"],
                        "assistant_text": assistant_text,
                        "repetitionDetected": repeated_proposal_envelope_detected(
                            assistant_text
                        ),
                        "truncationDetected": generation_cap_reached(
                            generated_ids,
                            generation["max_new_tokens"],
                        ),
                    }
                )

        _write_json(run_dir / "token-counts.json", token_counts)
        _write_json(run_dir / "applied-generation-config.json", effective_generation)
        _write_jsonl(run_dir / "raw-outputs.jsonl", outputs)
        _write_json(
            run_dir / "run-metadata.json",
            {
                "model_id": MODEL_ID,
                "model_revision": MODEL_REVISION,
                "profile": profile,
                "seed": seed,
                "case_count": len(outputs),
                "device": device,
                "model_dtype": str(model.dtype),
                "transformers_version": transformers_version,
                "torch_version": torch_version,
                "evidence_class": "host",
                "physical_device_run": False,
                "context_limit_tokens": context_limit_tokens,
                "prompt_template_id": PROMPT_TEMPLATE_ID,
                "prompt_template_sha256": prompt_template_sha256,
                **environment,
            },
        )


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--snapshot", type=Path, required=True)
    parser.add_argument("--profile", choices=sorted(PROFILES), required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--device", default="cpu")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        run(args.snapshot, args.profile, args.output_dir, args.device)
    except ValidationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
