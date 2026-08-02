#!/usr/bin/env python3
"""Build or verify the deterministic docs/explore discovery index."""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

from validate_explore_content import read_markdown_file, read_yaml_file

ROOT = Path(__file__).resolve().parents[1]
INDEX_SCHEMA_VERSION = 1


def repository_path(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def validate_source_content(root: Path) -> None:
    validator = root / "scripts" / "validate_explore_content.py"
    result = subprocess.run(
        [sys.executable, str(validator), "--root", str(root)],
        check=False,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        if result.stdout:
            print(result.stdout, end="", file=sys.stderr)
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        raise SystemExit(result.returncode)


def topic_record(path: Path, root: Path) -> dict[str, Any]:
    front_matter = read_markdown_file(path, root=root)
    return {
        "difficulty": front_matter.get("difficulty"),
        "featured": front_matter.get("featured", False),
        "icon": front_matter.get("icon"),
        "path": repository_path(path, root),
        "slug": front_matter["slug"],
        "summary": front_matter["summary"],
        "tags": front_matter["tags"],
        "title": front_matter["title"],
    }


def collection_record(path: Path, root: Path) -> dict[str, Any]:
    front_matter = read_markdown_file(path, root=root)
    return {
        "description": front_matter["description"],
        "featured": front_matter.get("featured", False),
        "path": repository_path(path, root),
        "slug": front_matter["slug"],
        "title": front_matter["title"],
        "topics": front_matter["topics"],
    }


def build_index(root: Path) -> dict[str, Any]:
    explore_root = root / "docs" / "explore"
    topic_paths = sorted((explore_root / "topics").glob("*/index.md"))
    collection_paths = sorted((explore_root / "collections").glob("*/index.md"))
    featured_path = explore_root / "featured" / "featured.yml"

    topics = sorted(
        (topic_record(path, root) for path in topic_paths),
        key=lambda item: item["slug"],
    )
    collections = sorted(
        (collection_record(path, root) for path in collection_paths),
        key=lambda item: item["slug"],
    )

    kinds_by_slug = {
        **{item["slug"]: "topic" for item in topics},
        **{item["slug"]: "collection" for item in collections},
    }
    featured_slugs = read_yaml_file(featured_path, root=root)["featured"]
    featured = [
        {"kind": kinds_by_slug[slug], "slug": slug}
        for slug in featured_slugs
    ]

    return {
        "schemaVersion": INDEX_SCHEMA_VERSION,
        "featured": featured,
        "topics": topics,
        "collections": collections,
    }


def encoded_index(index: dict[str, Any]) -> str:
    return json.dumps(index, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build or verify the deterministic docs/explore index."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=ROOT,
        help="Repository root directory.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Fail when docs/explore/index.json is missing or stale.",
    )
    args = parser.parse_args()

    root = args.root.resolve()
    validate_source_content(root)
    output_path = root / "docs" / "explore" / "index.json"
    expected = encoded_index(build_index(root))

    if args.check:
        if not output_path.exists():
            print(f"{repository_path(output_path, root)} is missing.", file=sys.stderr)
            return 1
        if output_path.read_text(encoding="utf-8") != expected:
            print(
                f"{repository_path(output_path, root)} is stale. "
                "Run python3 scripts/build_explore_index.py.",
                file=sys.stderr,
            )
            return 1
        print("Explore index is up to date.")
        return 0

    output_path.write_text(expected, encoding="utf-8")
    print(f"Wrote {repository_path(output_path, root)}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
