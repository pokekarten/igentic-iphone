# Explore

This directory is the discovery layer for iGentic. It is intentionally content-first so topics and collections stay reviewable, portable, and easy to validate.

## Goals

- make iGentic knowledge easier to navigate
- keep discovery content separate from runtime code
- define a stable schema for topics, collections, and cards
- support small, independent contributions

## Directory layout

```text
explore/
├── README.md
├── index.json
├── schema/
│   ├── topic.schema.json
│   ├── collection.schema.json
│   └── card.schema.json
├── topics/
│   └── <slug>/index.md
├── collections/
│   └── <slug>/index.md
└── featured/
    └── featured.yml
```

## Content rules

- Use English file names and slugs.
- Keep each topic focused on one concept.
- Keep collection entries curated and short.
- Prefer synthetic examples over private data.
- Avoid runtime code inside this directory.

## Validation

Run the dependency-free content validator from the repository root:

```bash
python3 scripts/validate_explore_content.py
```

Use `--root <path>` when validating a checkout that is not the current working directory.

## Generated discovery index

`index.json` is the versioned, UI-ready projection of the topic, collection, and featured metadata. Topics and collections are sorted by slug. The order in `docs/explore/featured/featured.yml` is preserved exactly.

Regenerate the index after changing Explore content:

```bash
python3 scripts/build_explore_index.py
```

Verify that the committed index is current without writing files:

```bash
python3 scripts/build_explore_index.py --check
```

The builder runs the content validator first, so duplicate slugs, invalid front matter, and broken topic or featured references fail before an index is written.

## Expected minimum fields

Topics should define:

- `title`
- `slug`
- `summary`
- `tags`

Collections should define:

- `title`
- `slug`
- `description`
- `topics`

Cards should define:

- `title`
- `slug`
- `summary`
- `type`

This directory remains documentation-first. The generated index is intended for a later local discovery loader and does not add runtime or network behavior.
