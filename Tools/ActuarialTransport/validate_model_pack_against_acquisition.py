from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def validate(spec: dict[str, Any], pack: dict[str, Any]) -> dict[str, Any]:
    required = spec.get("required_files")
    if not isinstance(required, list) or not required or not all(isinstance(item, str) and item for item in required):
        raise ValueError("acquisition manifest requires a non-empty required_files list")
    if len(required) != len(set(required)):
        raise ValueError("acquisition required_files must be unique")

    files = pack.get("files")
    if not isinstance(files, list):
        raise ValueError("inspected pack is missing files inventory")
    inventory: dict[str, dict[str, Any]] = {}
    for item in files:
        if not isinstance(item, dict) or not isinstance(item.get("path"), str):
            raise ValueError("invalid inspected pack file entry")
        path = item["path"]
        if path in inventory:
            raise ValueError(f"duplicate inspected file path: {path}")
        inventory[path] = item

    required_set = set(required)
    actual_set = set(inventory)
    missing = sorted(required_set - actual_set)
    extra = sorted(actual_set - required_set)
    if missing or extra:
        raise ValueError(f"model pack file allowlist mismatch: missing={missing}, extra={extra}")

    if pack.get("pack_kind") != "huggingface_trainable":
        raise ValueError("first-lane acquisition manifest requires huggingface_trainable pack")
    if pack.get("custom_code_files") not in ([], None):
        raise ValueError("pinned first-lane runtime pack must not contain custom Python code")

    known_weight = spec.get("known_upstream_weight")
    if not isinstance(known_weight, dict):
        raise ValueError("acquisition manifest is missing known_upstream_weight")
    weight_path = known_weight.get("path")
    weight_sha = known_weight.get("sha256")
    if not isinstance(weight_path, str) or not isinstance(weight_sha, str) or len(weight_sha) != 64:
        raise ValueError("known upstream weight identity is invalid")
    observed_weight = inventory.get(weight_path)
    if observed_weight is None:
        raise ValueError(f"known upstream weight is missing: {weight_path}")
    if observed_weight.get("sha256") != weight_sha:
        raise ValueError("model weight SHA-256 does not match pinned upstream weight")

    config = pack.get("config_summary")
    if not isinstance(config, dict):
        raise ValueError("inspected pack is missing config_summary")
    expected_type = spec.get("expected_model_type")
    if expected_type is not None and config.get("model_type") != expected_type:
        raise ValueError("config model_type does not match acquisition manifest")
    expected_architecture = spec.get("expected_architecture")
    architectures = config.get("architectures")
    if expected_architecture is not None:
        if not isinstance(architectures, list) or expected_architecture not in architectures:
            raise ValueError("config architecture does not match acquisition manifest")

    pack_sha = pack.get("pack_sha256")
    if not isinstance(pack_sha, str) or len(pack_sha) != 64:
        raise ValueError("inspected pack is missing pack_sha256")

    return {
        "schema_version": "0.1",
        "status": "pack_matches_pinned_acquisition_manifest",
        "model_id": spec.get("model_id"),
        "upstream_repo": spec.get("upstream_repo"),
        "upstream_revision": spec.get("upstream_revision"),
        "pack_sha256": pack_sha,
        "file_count": len(actual_set),
        "weight_path": weight_path,
        "weight_sha256": weight_sha,
        "model_type": config.get("model_type"),
        "architectures": architectures,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate an inspected local model pack against its pinned acquisition allowlist.")
    parser.add_argument("--acquisition-manifest", type=Path, required=True)
    parser.add_argument("--pack-manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    result = validate(load_json(args.acquisition_manifest), load_json(args.pack_manifest))
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
