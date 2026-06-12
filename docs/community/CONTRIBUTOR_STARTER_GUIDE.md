# Contributor Starter Guide

Last updated: 2026-06-12

## Welcome

iGentic is an experimental, privacy-first personal AI control layer. The current research track starts on iPhone, but the long-term project identity is broader: local-first personal AI with explicit approval, auditability and controlled delegation.

This guide helps new contributors find a safe first contribution.

## Start here

Read these files first:

1. `README.md` — project thesis, architecture and current direction.
2. `ROADMAP.md` — phases and next milestones.
3. `CONTRIBUTING.md` — contribution workflow and privacy rules.
4. `SECURITY.md` — what not to post publicly.
5. `docs/community/COMMUNITY_STRATEGY.md` — how the community is organized.
6. `docs/brand/BRAND.md` — what the project should feel like.

## Choose a contribution lane

### Lane 1 — Documentation

Good if you want to improve clarity without touching runtime code.

Examples:

- clarify README sections,
- improve architecture diagrams,
- add source notes,
- improve glossary language,
- simplify onboarding docs.

### Lane 2 — Design and brand

Good if you want to help make the project look serious and understandable.

Examples:

- propose a logo refinement,
- improve SVG assets,
- create social card variants,
- design an approval-flow mock,
- make diagrams easier to understand.

Use the design feedback issue template and follow `docs/brand/LOGO_USAGE.md`.

### Lane 3 — Tests and validation

Good if you want to strengthen trust without adding risky behavior.

Examples:

- add smoke tests,
- improve `scripts/validate_repo_structure.py`,
- test policy edge cases,
- make audit behavior easier to verify.

### Lane 4 — Safe runtime stubs

Good if you write Swift and understand that this project is safety-first.

Examples:

- small in-memory stubs,
- metadata-only components,
- explicit policy decisions,
- no real private-data access,
- no external network or model calls.

### Lane 5 — Research

Good if you want to review platform APIs or local runtime candidates.

Examples:

- Apple API notes,
- local model runtime comparisons,
- device test reports,
- privacy threat model notes,
- App Intents safety analysis.

## What not to do first

Avoid first contributions that add:

- real private user data,
- secrets or credentials,
- external AI provider integrations,
- model weights,
- persistence for memory,
- real App Store/signing configuration,
- broad architecture rewrites,
- unsafe autonomy claims.

## How to open a good issue

A good issue answers:

1. What is the goal?
2. Which file or component is affected?
3. What privacy or safety rule matters?
4. What is out of scope?
5. How can it be validated?

## How to open a good PR

A good PR is:

- small,
- reviewable,
- linked to a clear goal,
- tested or manually validated,
- explicit about privacy impact,
- explicit about approval/delegation behavior,
- free of secrets and private data.

Use `.github/PULL_REQUEST_TEMPLATE.md`.

## Design contribution checklist

Before proposing visuals, check:

- Does it communicate local control?
- Does it show approval or policy boundaries?
- Does it avoid Apple trade dress and third-party marks?
- Does it work in monochrome?
- Is it understandable at small sizes?
- Is it useful for GitHub, website and social assets?

## First contribution ideas

See `docs/community/GOOD_FIRST_ISSUES.md` for curated starter tasks.

## Maintainer expectation

Maintainers may ask for smaller scope, stronger privacy notes or better validation. This is normal. iGentic grows by making the safe path easy, not by accepting broad risky changes quickly.
