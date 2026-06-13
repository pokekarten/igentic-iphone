# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

ChatGPT works through the GitHub Connector for repository-control, review and small documentation/process changes. Runtime/code changes should stay narrow and use pull requests before merge.

Codex remains paused until the validation and PR-scope path is stable enough for repeatable Draft PR handoffs.

## Recently completed

The brand identity foundation was expanded with a v2 visual direction:

- `docs/brand/CORPORATE_IDENTITY.md`
- `docs/brand/DESIGN_SYSTEM_V2_NOTES.md`
- `assets/brand/logo-mark-v2.svg`
- `assets/brand/logo-mark-dark.svg`
- `assets/brand/logo-mark-social.svg`
- `assets/brand/logo-mark-mono.svg`
- `assets/brand/logo-lockup-v2.svg`
- `assets/social/instagram-profile.svg`

The v2 direction is cleaner and more usable for public profiles than the first exploratory logo because it removes tiny details and improves small-size readability.

## Active cycle

Target: public brand readiness for iGentic.

Goal: validate whether the v2 mark is strong enough to become the default public avatar and README/logo baseline.

## Next task

Create a visual review pass for the v2 brand assets:

1. Render `assets/social/instagram-profile.svg` at 64 px, 120 px and 220 px.
2. Compare it against `assets/brand/logo-mark.svg` and `assets/brand/logo-mark-v2.svg`.
3. Decide whether `logo-mark-v2.svg` should replace `logo-mark.svg` as the default mark or remain a candidate.
4. If accepted, update README/logo references to prefer the v2 assets.
5. Keep the first pass as documentation and SVG-only unless explicit runtime work is requested.

## Guardrails

- Do not change Swift runtime code for this task.
- Do not change workflows unless explicitly required.
- Do not add secrets, network calls, external providers, App Intents, signing files or private data.
- Do not touch Pokekartenkiste files or references.
- Do not claim Swift build/test success unless backed by a specific local run or GitHub Actions run.
- Keep the change visual/documentation-only.
