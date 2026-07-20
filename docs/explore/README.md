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

This directory is documentation-first for now. A future validator or loader can consume the schema files and generate UI-ready discovery data.
