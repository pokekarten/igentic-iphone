from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REGISTRY = ROOT / "models" / "registry.json"
sys.path.insert(0, str(ROOT / "scripts"))
import validate_model_pack_against_acquisition  # noqa: E402


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def find_model(registry: dict[str, Any], model_id: str) -> dict[str, Any]:
    models = registry.get("models")
    if not isinstance(models, list):
        raise ValueError("registry models must be a list")
    matches = [item for item in models if isinstance(item, dict) and item.get("id") == model_id]
    if len(matches) != 1:
        raise ValueError(f"registry must contain exactly one model with id {model_id!r}")
    return matches[0]


def verify(
    registry: dict[str, Any],
    receipt: dict[str, Any],
    pack: dict[str, Any],
    acquisition_spec: dict[str, Any] | None = None,
) -> dict[str, Any]:
    model_id = receipt.get("model_id")
    if not isinstance(model_id, str) or not model_id:
        raise ValueError("receipt is missing model_id")
    model = find_model(registry, model_id)

    if receipt.get("upstream_repo") != model.get("upstream_repo"):
        raise ValueError("receipt upstream_repo does not match registry candidate")
    revision = receipt.get("upstream_revision")
    if not isinstance(revision, str) or len(revision) < 7 or revision == "main":
        raise ValueError("receipt requires an immutable upstream revision, not main")
    pinned_revision = model.get("upstream_revision")
    if pinned_revision is not None and revision != pinned_revision:
        raise ValueError("receipt upstream_revision does not match the pinned registry revision")
    pinned_tokenizer_revision = model.get("tokenizer_revision")
    receipt_tokenizer_revision = receipt.get("tokenizer_revision", revision)
    if pinned_tokenizer_revision is not None and receipt_tokenizer_revision != pinned_tokenizer_revision:
        raise ValueError("receipt tokenizer_revision does not match the pinned registry revision")

    expected_spec_path = model.get("acquisition_manifest")
    if expected_spec_path is not None and acquisition_spec is None:
        raise ValueError("registry model requires its pinned acquisition manifest")
    pack_validation: dict[str, Any] | None = None
    if acquisition_spec is not None:
        if acquisition_spec.get("model_id") != model_id:
            raise ValueError("acquisition manifest model_id does not match receipt")
        if acquisition_spec.get("upstream_repo") != receipt.get("upstream_repo"):
            raise ValueError("acquisition manifest upstream_repo does not match receipt")
        if acquisition_spec.get("upstream_revision") != revision:
            raise ValueError("acquisition manifest upstream_revision does not match receipt")
        if acquisition_spec.get("tokenizer_revision") != receipt_tokenizer_revision:
            raise ValueError("acquisition manifest tokenizer_revision does not match receipt")
        if acquisition_spec.get("license_claim") != receipt.get("upstream_license_claim"):
            raise ValueError("acquisition manifest license claim does not match receipt")
        pack_validation = validate_model_pack_against_acquisition.validate(acquisition_spec, pack)

    if receipt.get("local_pack_sha256") != pack.get("pack_sha256"):
        raise ValueError("receipt local_pack_sha256 does not match inspected pack")
    if receipt.get("pack_kind") != pack.get("pack_kind"):
        raise ValueError("receipt pack_kind does not match inspected pack")
    if receipt.get("upstream_license_claim") != model.get("upstream_license_claim"):
        raise ValueError("receipt license claim does not match planned upstream claim")

    load_test = receipt.get("offline_load_test")
    if not isinstance(load_test, dict) or load_test.get("passed") is not True:
        raise ValueError("offline load test must pass before verification")

    custom_code = pack.get("custom_code_files")
    if not isinstance(custom_code, list):
        raise ValueError("pack manifest is missing custom_code_files")
    if custom_code and receipt.get("custom_code_reviewed") is not True:
        raise ValueError("custom model code requires explicit review before verification")

    if model.get("trainer_compatibility", "").startswith("multimodal_not_supported"):
        verified_status = "verified_separate_lane"
    else:
        verified_status = "verified"

    return {
        "schema_version": "0.2",
        "receipt_type": "model_acquisition_verification",
        "model_id": model_id,
        "status": verified_status,
        "upstream_repo": receipt["upstream_repo"],
        "upstream_revision": revision,
        "tokenizer_revision": receipt_tokenizer_revision,
        "license": receipt["upstream_license_claim"],
        "pack_sha256": pack["pack_sha256"],
        "pack_kind": pack["pack_kind"],
        "file_count": pack.get("file_count"),
        "total_bytes": pack.get("total_bytes"),
        "config_summary": pack.get("config_summary", {}),
        "custom_code_files": custom_code,
        "offline_load_runtime": load_test.get("runtime"),
        "offline_load_notes": load_test.get("notes", ""),
        "acquisition_allowlist_validation": pack_validation,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify a locally acquired model pack against the lab registry and pinned allowlist.")
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--pack-manifest", type=Path, required=True)
    parser.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    registry = load_json(args.registry)
    receipt = load_json(args.receipt)
    model_id = receipt.get("model_id")
    if not isinstance(model_id, str) or not model_id:
        raise ValueError("receipt is missing model_id")
    model = find_model(registry, model_id)
    acquisition_path_value = model.get("acquisition_manifest")
    acquisition_spec = None
    if acquisition_path_value is not None:
        if not isinstance(acquisition_path_value, str) or not acquisition_path_value:
            raise ValueError("registry acquisition_manifest path is invalid")
        acquisition_path = (ROOT / acquisition_path_value).resolve()
        if ROOT.resolve() not in acquisition_path.parents:
            raise ValueError("registry acquisition_manifest escapes repository root")
        if not acquisition_path.is_file():
            raise ValueError(f"pinned acquisition manifest not found: {acquisition_path_value}")
        acquisition_spec = load_json(acquisition_path)

    result = verify(registry, receipt, load_json(args.pack_manifest), acquisition_spec)
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
