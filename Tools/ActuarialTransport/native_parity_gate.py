from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any


def valid_sha(value: Any) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(char in "0123456789abcdef" for char in value)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("parity receipt must contain a JSON object")
    return value


def validate_parity_receipt(
    receipt: dict[str, Any],
    *,
    model_id: str,
    model_pack_sha256: str,
    base_revision: str,
    tokenizer_revision: str,
) -> None:
    if receipt.get("receipt_type") != "native_hf_model_parity":
        raise ValueError("wrong native parity receipt type")
    if receipt.get("status") != "parity_passed":
        raise ValueError("native parity has not passed")
    if receipt.get("model_id") != model_id:
        raise ValueError("native parity model_id mismatch")
    if receipt.get("model_pack_sha256") != model_pack_sha256:
        raise ValueError("native parity model-pack SHA mismatch")
    if receipt.get("base_revision") != base_revision:
        raise ValueError("native parity base revision mismatch")
    if receipt.get("tokenizer_revision") != tokenizer_revision:
        raise ValueError("native parity tokenizer revision mismatch")
    if receipt.get("prompt_count", 0) < 3:
        raise ValueError("native parity requires at least three prompt fixtures")
    if receipt.get("tokenizer_all_match") is not True:
        raise ValueError("native tokenizer parity did not pass")
    if receipt.get("argmax_all_match") is not True:
        raise ValueError("native model argmax parity did not pass")
    observed = receipt.get("observed_max_abs_logit_diff")
    threshold = receipt.get("max_abs_logit_diff_threshold")
    if not isinstance(observed, (int, float)) or not isinstance(threshold, (int, float)):
        raise ValueError("native parity receipt is missing logit-difference metrics")
    if observed > threshold:
        raise ValueError("native model logit parity exceeds its declared threshold")


def validate_parity_file(
    path: Path,
    *,
    model_id: str,
    model_pack_sha256: str,
    base_revision: str,
    tokenizer_revision: str,
) -> str:
    resolved = path.expanduser().resolve()
    if not resolved.is_file():
        raise ValueError(f"native parity receipt not found: {resolved}")
    validate_parity_receipt(
        load_json(resolved),
        model_id=model_id,
        model_pack_sha256=model_pack_sha256,
        base_revision=base_revision,
        tokenizer_revision=tokenizer_revision,
    )
    digest = sha256_file(resolved)
    if not valid_sha(digest):
        raise RuntimeError("internal parity receipt SHA-256 failure")
    return digest
