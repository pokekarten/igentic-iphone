# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private brain may point here, but it must not duplicate detailed live state. PR numbers, branches, CI, validation, head SHAs, scope and concrete blockers must be re-read from this repository, issues, pull requests or current files before status is reported.

## Current operating mode

ChatGPT works through the GitHub Connector for repository-control, review and small documentation/process changes. Runtime/code changes should stay narrow and use pull requests before merge.

Codex remains paused until the validation and PR-scope path is stable enough for repeatable Draft PR handoffs.

## Recently completed

The brand identity foundation was expanded from v2 into a cleaner v3 social-ready system and anchored in the repository:

- `assets/brand/logo-symbol-v3.svg`
- `assets/brand/logo-mark-dark-v3.svg`
- `assets/brand/logo-lockup-v3.svg`
- `assets/social/instagram-profile-v3.svg`
- `assets/social/instagram-carousel-template-v1.svg`
- `docs/brand/SOCIAL_IDENTITY.md`
- `docs/brand/BRAND_ASSET_MANIFEST.md`
- `docs/brand/BRAND_REVIEW_WORKFLOW.md`

README now uses `assets/brand/logo-lockup-v3.svg` as the visible repository logo.

`scripts/validate_repo_structure.py` now requires the v3 brand assets, the brand manifest and the social identity docs, and checks the relevant SVG files for `<title>`, `<desc>` and `role="img"` metadata.

## Active cycle

Target: public brand readiness for iGentic.

Goal: visually validate whether the v3 mark should become the default public identity and whether the social carousel template is usable for real posts.

## Next task

Create a visual review pass for the v3 brand assets:

1. Render `assets/social/instagram-profile-v3.svg` at 64 px, 120 px and 220 px.
2. Compare it against `assets/brand/logo-mark.svg`, `assets/brand/logo-mark-v2.svg` and `assets/brand/logo-symbol-v3.svg`.
3. Test `assets/social/instagram-carousel-template-v1.svg` with three real carousel topics:
   - Policy before action.
   - Local first.
   - Approval gated.
4. Decide whether v3 should be promoted from preferred candidate to default identity.
5. If accepted, update `docs/brand/BRAND_ASSET_MANIFEST.md` and `docs/brand/SOCIAL_IDENTITY.md` from preferred candidate to default.

## Guardrails

- Do not change Swift runtime code for this task.
- Do not change workflows unless explicitly required.
- Do not add secrets, network calls, external providers, App Intents, signing files or private data.
- Do not touch Pokekartenkiste files or references.
- Do not claim Swift build/test success unless backed by a specific local run or GitHub Actions run.
- Keep the change visual/documentation-only.
