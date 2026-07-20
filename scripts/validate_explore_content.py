#!/usr/bin/env python3
"""Validate the docs/explore discovery content.

This script is intentionally dependency-free. It reads only repository files
under docs/explore, checks simple front matter structure, and verifies that
references stay internally consistent. It does not execute Swift, access the
network, or write files.
"""
from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]

TOPIC_REQUIRED_KEYS = ("title", "slug", "summary", "tags")
COLLECTION_REQUIRED_KEYS = ("title", "slug", "description", "topics")


@dataclass(frozen=True)
class ContentFile:
    path: Path
    kind: str
    front_matter: dict[str, Any]


def rel(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def parse_scalar(value: str) -> Any:
    value = value.strip()
    lowered = value.lower()
    if lowered == "true":
        return True
    if lowered == "false":
        return False
    if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
        return value[1:-1]
    return value


def parse_simple_yaml_lines(lines: list[str], *, source: Path, root: Path) -> dict[str, Any]:
    data: dict[str, Any] = {}
    current_list_key: str | None = None

    for raw_line in lines:
        if not raw_line.strip():
            continue

        stripped = raw_line.lstrip()
        if stripped.startswith("- "):
            if current_list_key is None:
                raise ValueError(f"{rel(source, root)}: unexpected list item outside a list: {raw_line!r}")
            item = stripped[2:].strip()
            if not item:
                raise ValueError(f"{rel(source, root)}: empty list item in key '{current_list_key}'")
            data[current_list_key].append(parse_scalar(item))
            continue

        match = re.match(r"^([A-Za-z0-9_-]+):(?:\s+(.*))?$", raw_line)
        if not match:
            raise ValueError(f"{rel(source, root)}: unsupported YAML line: {raw_line!r}")

        key, value = match.group(1), match.group(2)
        if value is None or value == "":
            data[key] = []
            current_list_key = key
        else:
            data[key] = parse_scalar(value)
            current_list_key = None

    return data


def parse_front_matter(text: str, *, source: Path, root: Path) -> dict[str, Any]:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        raise ValueError(f"{rel(source, root)}: missing front matter start delimiter '---'")

    fm_lines: list[str] = []
    closing_index = None
    for index, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            closing_index = index
            break
        fm_lines.append(line)

    if closing_index is None:
        raise ValueError(f"{rel(source, root)}: missing front matter end delimiter '---'")

    return parse_simple_yaml_lines(fm_lines, source=source, root=root)


def read_markdown_file(path: Path, *, root: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    return parse_front_matter(text, source=path, root=root)


def read_yaml_file(path: Path, *, root: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    return parse_simple_yaml_lines(text.splitlines(), source=path, root=root)


def validate_required_keys(front_matter: dict[str, Any], required: tuple[str, ...], *, source: Path, root: Path) -> list[str]:
    missing = [key for key in required if key not in front_matter]
    if missing:
        return [f"{rel(source, root)} is missing required front matter keys: {', '.join(missing)}"]
    return []


def validate_string_field(front_matter: dict[str, Any], key: str, *, source: Path, root: Path) -> list[str]:
    value = front_matter.get(key)
    if not isinstance(value, str) or not value.strip():
        return [f"{rel(source, root)}: '{key}' must be a non-empty string"]
    return []


def validate_bool_field(front_matter: dict[str, Any], key: str, *, source: Path, root: Path, optional: bool = True) -> list[str]:
    if key not in front_matter:
        return [] if optional else [f"{rel(source, root)}: '{key}' is required"]
    if not isinstance(front_matter[key], bool):
        return [f"{rel(source, root)}: '{key}' must be true or false"]
    return []


def validate_string_list_field(front_matter: dict[str, Any], key: str, *, source: Path, root: Path, min_items: int = 1) -> list[str]:
    value = front_matter.get(key)
    if not isinstance(value, list):
        return [f"{rel(source, root)}: '{key}' must be a list"]
    errors: list[str] = []
    if len(value) < min_items:
        errors.append(f"{rel(source, root)}: '{key}' must contain at least {min_items} item(s)")
    for item in value:
        if not isinstance(item, str) or not item.strip():
            errors.append(f"{rel(source, root)}: '{key}' list items must be non-empty strings")
            break
    return errors


def validate_topic_file(path: Path, *, root: Path) -> tuple[ContentFile | None, list[str]]:
    errors: list[str] = []
    try:
        front_matter = read_markdown_file(path, root=root)
    except ValueError as exc:
        return None, [str(exc)]

    errors.extend(validate_required_keys(front_matter, TOPIC_REQUIRED_KEYS, source=path, root=root))
    errors.extend(validate_string_field(front_matter, "title", source=path, root=root))
    errors.extend(validate_string_field(front_matter, "slug", source=path, root=root))
    errors.extend(validate_string_field(front_matter, "summary", source=path, root=root))
    errors.extend(validate_string_list_field(front_matter, "tags", source=path, root=root))
    errors.extend(validate_bool_field(front_matter, "featured", source=path, root=root))
    if "difficulty" in front_matter and front_matter["difficulty"] not in {"beginner", "intermediate", "advanced"}:
        errors.append(f"{rel(path, root)}: 'difficulty' must be one of beginner, intermediate, advanced")
    if "icon" in front_matter and (not isinstance(front_matter["icon"], str) or not front_matter["icon"].strip()):
        errors.append(f"{rel(path, root)}: 'icon' must be a non-empty string")

    slug = front_matter.get("slug")
    dirname = path.parent.name
    if isinstance(slug, str) and slug != dirname:
        errors.append(f"{rel(path, root)}: slug '{slug}' does not match directory name '{dirname}'")

    return ContentFile(path=path, kind="topic", front_matter=front_matter), errors


def validate_collection_file(path: Path, *, root: Path) -> tuple[ContentFile | None, list[str]]:
    errors: list[str] = []
    try:
        front_matter = read_markdown_file(path, root=root)
    except ValueError as exc:
        return None, [str(exc)]

    errors.extend(validate_required_keys(front_matter, COLLECTION_REQUIRED_KEYS, source=path, root=root))
    errors.extend(validate_string_field(front_matter, "title", source=path, root=root))
    errors.extend(validate_string_field(front_matter, "slug", source=path, root=root))
    errors.extend(validate_string_field(front_matter, "description", source=path, root=root))
    errors.extend(validate_string_list_field(front_matter, "topics", source=path, root=root))
    errors.extend(validate_bool_field(front_matter, "featured", source=path, root=root))

    slug = front_matter.get("slug")
    dirname = path.parent.name
    if isinstance(slug, str) and slug != dirname:
        errors.append(f"{rel(path, root)}: slug '{slug}' does not match directory name '{dirname}'")

    return ContentFile(path=path, kind="collection", front_matter=front_matter), errors


def validate_featured_file(featured_file: Path, *, root: Path, existing_slugs: set[str]) -> list[str]:
    try:
        front_matter = read_yaml_file(featured_file, root=root)
    except ValueError as exc:
        return [str(exc)]

    errors: list[str] = []
    unknown_keys = sorted(set(front_matter) - {"featured"})
    if unknown_keys:
        errors.append(
            f"{rel(featured_file, root)}: only the 'featured' key is allowed in this file (found: {', '.join(unknown_keys)})"
        )

    errors.extend(validate_string_list_field(front_matter, "featured", source=featured_file, root=root))
    featured = front_matter.get("featured")
    if isinstance(featured, list):
        seen: set[str] = set()
        for slug in featured:
            if slug in seen:
                errors.append(f"{rel(featured_file, root)}: duplicate featured slug '{slug}'")
            seen.add(slug)
            if slug not in existing_slugs:
                errors.append(f"{rel(featured_file, root)}: featured slug '{slug}' does not match any topic or collection")
    return errors


def validate_references(collections: list[ContentFile], topic_slugs: set[str], *, root: Path) -> list[str]:
    errors: list[str] = []
    for collection in collections:
        topics = collection.front_matter.get("topics", [])
        if not isinstance(topics, list):
            continue
        for topic_slug in topics:
            if topic_slug not in topic_slugs:
                errors.append(f"{rel(collection.path, root)}: references unknown topic slug '{topic_slug}'")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate docs/explore content.")
    parser.add_argument(
        "--root",
        type=Path,
        default=ROOT,
        help="Repository root directory (defaults to the repository root containing this script).",
    )
    args = parser.parse_args()

    repo_root = args.root.resolve()
    topics_dir = repo_root / "docs" / "explore" / "topics"
    collections_dir = repo_root / "docs" / "explore" / "collections"
    featured_file = repo_root / "docs" / "explore" / "featured" / "featured.yml"

    errors: list[str] = []
    warnings: list[str] = []

    topic_files = sorted(topics_dir.glob("*/index.md")) if topics_dir.exists() else []
    collection_files = sorted(collections_dir.glob("*/index.md")) if collections_dir.exists() else []

    if not topic_files:
        errors.append("No topic files found under docs/explore/topics/*/index.md")
    if not collection_files:
        errors.append("No collection files found under docs/explore/collections/*/index.md")
    if not featured_file.exists():
        errors.append("Missing docs/explore/featured/featured.yml")

    topics: list[ContentFile] = []
    collections: list[ContentFile] = []
    topic_slugs: set[str] = set()
    collection_slugs: set[str] = set()

    for path in topic_files:
        content, file_errors = validate_topic_file(path, root=repo_root)
        errors.extend(file_errors)
        if content is not None:
            topics.append(content)
            slug = content.front_matter["slug"]
            if slug in topic_slugs or slug in collection_slugs:
                errors.append(f"{rel(path, repo_root)}: duplicate slug '{slug}'")
            topic_slugs.add(slug)
    for path in collection_files:
        content, file_errors = validate_collection_file(path, root=repo_root)
        errors.extend(file_errors)
        if content is not None:
            collections.append(content)
            slug = content.front_matter["slug"]
            if slug in topic_slugs or slug in collection_slugs:
                errors.append(f"{rel(path, repo_root)}: duplicate slug '{slug}'")
            collection_slugs.add(slug)

    all_slugs = topic_slugs | collection_slugs

    errors.extend(validate_references(collections, topic_slugs, root=repo_root))

    if featured_file.exists():
        errors.extend(validate_featured_file(featured_file, root=repo_root, existing_slugs=all_slugs))

    explore_root = repo_root / "docs" / "explore"
    allowed = {path.resolve() for path in topic_files + collection_files + ([featured_file] if featured_file.exists() else [])}
    for md in sorted(explore_root.rglob("*.md")):
        if md.resolve() not in allowed:
            warnings.append(f"{rel(md, repo_root)}: not validated by this script")

    if warnings:
        print("Warnings:")
        for warning in warnings:
            print(f"- {warning}")
        print()

    if errors:
        print("Explore content validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Explore content looks good.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
