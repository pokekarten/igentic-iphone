# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

ChatGPT works through the GitHub Connector for repository-control, review and small documentation/process changes. Runtime/code changes should stay narrow and use pull requests before merge.

Codex remains paused until the validation and PR-scope path is stable enough for repeatable Draft PR handoffs.

## Recently completed

The brand identity foundation was expanded from v2 into a cleaner v3 social-ready system:

- `assets/brand/logo-symbol-v3.svg`
- `assets/brand/logo-mark-dark-v3.svg`
- `assets/brand/logo-lockup-v3.svg`
- `assets/social/instagram-profile-v3.svg`
- `assets/social/instagram-carousel-template-v1.svg`
- `docs/brand/SOCIAL_IDENTITY.md`

The v3 direction is stronger because it separates the identity into a responsive system: transparent symbol, profile avatar, lockup, dark mark and social carousel template.

## Active cycle

Target: public brand readiness for iGentic.

Goal: validate whether the v3 mark is strong enough to become the default public avatar and README/logo baseline.

## Next task

Create a visual review pass for the v3 brand assets:

1. Render `assets/social/instagram-profile-v3.svg` at 64 px, 120 px and 220 px.
2. Compare it against `assets/brand/logo-mark.svg`, `assets/brand/logo-mark-v2.svg` and `assets/brand/logo-symbol-v3.svg`.
3. Decide whether v3 should become the default public mark.
4. If accepted, update README/logo references to prefer `logo-lockup-v3.svg` and `instagram-profile-v3.svg`.
5. Test `assets/social/instagram-carousel-template-v1.svg` with three real carousel topics.

## Guardrails

- Do not change Swift runtime code for this task.
- Do not change workflows unless explicitly required.
- Do not add secrets, network calls, external providers, App Intents, signing files or private data.
- Do not touch Pokekartenkiste files or references.
- Do not claim Swift build/test success unless backed by a specific local run or GitHub Actions run.
- Keep the change visual/documentation-only.
