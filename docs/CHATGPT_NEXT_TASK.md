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

A ChatGPT visual review pass on 2026-06-14 promoted the v3 profile, symbol and lockup from preferred candidates to the default public identity recommendation in the brand docs.

The first carousel copy wrap pass is recorded in `docs/brand/CAROUSEL_COPY_WRAP_PASS.md`. It confirms short two-line subtitles for the current social pillars and keeps the carousel as an active template candidate until committed SVG example covers or a wrapped-subtitle template revision confirms the layout visually.

## Active cycle

Target: public brand readiness for iGentic.

Goal: make the carousel template usable for real public posts without touching runtime code.

## Next task

Create the next visual-only carousel proof from `assets/social/instagram-carousel-template-v1.svg` and `docs/brand/CAROUSEL_COPY_WRAP_PASS.md`:

1. Add committed SVG example covers, or a wrapped-subtitle template revision, for these topics:
   - Policy before action.
   - Local first.
   - Approval gated.
2. Use two subtitle text rows for realistic public copy:
   - line 1 around `y=470`
   - line 2 around `y=520`
3. Re-check that headline, subtitle and card copy stay inside the 1080 x 1350 frame.
4. Keep the profile/avatar, master symbol and lockup status as v3 default unless new visual evidence contradicts it.
5. If the SVG proof succeeds, update `docs/brand/BRAND_ASSET_MANIFEST.md` and `docs/brand/SOCIAL_IDENTITY.md` from active template candidate toward default carousel template.

## Guardrails

- Do not change Swift runtime code for this task.
- Do not change workflows unless explicitly required.
- Do not add secrets, network calls, external providers, App Intents, signing files or private data.
- Do not touch Pokekartenkiste files or references.
- Do not claim Swift build/test success unless backed by a specific local run or GitHub Actions run.
- Keep the change visual/documentation-only.
