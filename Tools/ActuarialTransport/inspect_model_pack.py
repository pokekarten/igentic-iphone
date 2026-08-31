from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

WEIGHT_SUFFIXES = {".safetensors", ".bin", ".gguf", ".pt", ".pth"}
TRAINABLE_SUFFIXES = {".safetensors", ".bin"}
TOKENIZER_NAMES = {
    "tokenizer.json",
    "tokenizer.model",
    "tokenizer_config.json",
    "special_tokens_map.json",
    "vocab.json",
    "merges.txt",
}
DISALLOWED_NAMES = {
    ".env",
    "credentials.json",
    "secrets.json",
    "token",
    "token.txt",
    "api_key",
    "api_key.txt",
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def stable_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def inspect_pack(pack_path: Path) -> dict[str, Any]:
    root = pack_path.expanduser().resolve()
    if not root.is_dir():
        raise ValueError(f"model pack must be an existing directory: {root}")

    config_path = root / "config.json"
    if not config_path.is_file():
        raise ValueError("model pack is missing config.json")

    files: list[dict[str, Any]] = []
    weight_files: list[str] = []
    tokenizer_files: list[str] = []
    custom_code_files: list[str] = []
    total_bytes = 0

    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            raise ValueError(f"symlinks are not allowed in model packs: {path}")
        if not path.is_file():
            continue
        relative = path.relative_to(root).as_posix()
        if path.name.casefold() in DISALLOWED_NAMES:
            raise ValueError(f"disallowed credential-like file in model pack: {relative}")
        size = path.stat().st_size
        digest = sha256_file(path)
        files.append({"path": relative, "bytes": size, "sha256": digest})
        total_bytes += size
        if path.suffix.casefold() in WEIGHT_SUFFIXES:
            weight_files.append(relative)
        if path.name in TOKENIZER_NAMES or path.name.startswith("tokenizer"):
            tokenizer_files.append(relative)
        if path.suffix.casefold() == ".py":
            custom_code_files.append(relative)

    if not weight_files:
        raise ValueError("model pack contains no recognized weight file")
    if not tokenizer_files:
        raise ValueError("model pack contains no recognized tokenizer files")

    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError("config.json is not valid UTF-8 JSON") from exc
    if not isinstance(config, dict):
        raise ValueError("config.json must contain a JSON object")

    trainable_weights = [name for name in weight_files if Path(name).suffix.casefold() in TRAINABLE_SUFFIXES]
    gguf_weights = [name for name in weight_files if Path(name).suffix.casefold() == ".gguf"]
    if trainable_weights and gguf_weights:
        pack_kind = "mixed_training_and_inference"
    elif trainable_weights:
        pack_kind = "huggingface_trainable"
    elif gguf_weights:
        pack_kind = "gguf_inference_only"
    else:
        pack_kind = "unsupported_training_weights"

    identity_payload = "\n".join(
        f"{entry['sha256']}  {entry['bytes']}  {entry['path']}" for entry in files
    ) + "\n"
    pack_sha256 = hashlib.sha256(identity_payload.encode("utf-8")).hexdigest()

    return {
        "schema_version": "0.1",
        "pack_kind": pack_kind,
        "pack_sha256": pack_sha256,
        "file_count": len(files),
        "total_bytes": total_bytes,
        "weight_files": weight_files,
        "trainable_weight_files": trainable_weights,
        "gguf_weight_files": gguf_weights,
        "tokenizer_files": tokenizer_files,
        "custom_code_files": custom_code_files,
        "requires_explicit_trust_local_code": bool(custom_code_files),
        "config_summary": {
            "model_type": config.get("model_type"),
            "architectures": config.get("architectures"),
            "hidden_size": config.get("hidden_size"),
            "num_hidden_layers": config.get("num_hidden_layers"),
            "vocab_size": config.get("vocab_size"),
            "torch_dtype": config.get("torch_dtype"),
        },
        "files": files,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspect and hash an offline local model pack.")
    parser.add_argument("pack", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    manifest = inspect_pack(args.pack)
    rendered = json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
