# iGentic Brand Asset Manifest

Last updated: 2026-06-18

## Purpose

This manifest is the source of truth for iGentic brand assets in the repository.

It prevents the project from drifting between one-off logo experiments, generated images and undocumented social files.

## Current brand state

The current default public identity direction is **v3 responsive brand system** for the master symbol, public profile/avatar and README/header lockup.

The carousel template is now a **preferred template candidate with committed proof covers** for the first three social pillars. It should not be treated as locked until the proof covers are visually rendered/reviewed and maintainer approval confirms the final public style.

The v3 direction is preferred because it separates the brand into context-specific assets:

- transparent master symbol,
- social/profile avatar,
- dark surface mark,
- horizontal lockup,
- carousel template,
- wrapped-copy proof covers,
- monochrome fallback.

## Canonical assets

| Asset | Path | Role | Status |
| --- | --- | --- | --- |
| Transparent master symbol | `assets/brand/logo-symbol-v3.svg` | flexible mark for custom surfaces | default |
| Instagram profile | `assets/social/instagram-profile-v3.svg` | public profile/avatar | default |
| Dark mark | `assets/brand/logo-mark-dark-v3.svg` | dark decks, social posts, dark UI sections | preferred candidate |
| Lockup | `assets/brand/logo-lockup-v3.svg` | README, website hero, social header | default |
| Carousel template | `assets/social/instagram-carousel-template-v1.svg` | first repeatable Instagram carousel layout | preferred template candidate |
| Policy proof cover | `assets/social/carousel-policy-before-action.svg` | wrapped-copy proof for the Policy before action pillar | proof candidate |
| Local-first proof cover | `assets/social/carousel-local-first.svg` | wrapped-copy proof for the Local first pillar | proof candidate |
| Approval-gated proof cover | `assets/social/carousel-approval-gated.svg` | wrapped-copy proof for the Approval gated pillar | proof candidate |
| Monochrome mark | `assets/brand/logo-mark-mono.svg` | one-color fallback, masks, print | required fallback |

## Legacy / comparison assets

| Asset | Path | Status |
| --- | --- | --- |
| Original mark | `assets/brand/logo-mark.svg` | legacy candidate, keep for comparison |
| Original lockup | `assets/brand/logo-lockup.svg` | legacy candidate, keep for comparison |
| v2 mark | `assets/brand/logo-mark-v2.svg` | previous preferred candidate |
| v2 Instagram profile | `assets/social/instagram-profile.svg` | previous profile candidate |
| v2 lockup | `assets/brand/logo-lockup-v2.svg` | previous lockup candidate |
| v2 dark mark | `assets/brand/logo-mark-dark.svg` | previous dark candidate |
| v2 social mark | `assets/brand/logo-mark-social.svg` | previous social tile candidate |

## Files that define the brand system

| File | Purpose |
| --- | --- |
| `docs/brand/BRAND.md` | master brand foundation |
| `docs/brand/CORPORATE_IDENTITY.md` | corporate identity strategy |
| `docs/brand/SOCIAL_IDENTITY.md` | social identity and content rules |
| `docs/brand/DESIGN_SYSTEM.md` | design system baseline |
| `docs/brand/DESIGN_SYSTEM_V2_NOTES.md` | v2/v3 visual notes until merged into the main design system |
| `docs/brand/LOGO_USAGE.md` | usage and trademark/confusion guardrails |
| `assets/brand/README.md` | asset inventory and usage recommendations |

## Source-of-truth rules

1. SVG assets in `assets/brand/` and `assets/social/` are canonical.
2. PNG files are preview/export artifacts only unless explicitly documented.
3. Generated images are not official unless translated into editable SVG and listed here.
4. Profile assets must work without text.
5. Public avatar assets must be checked at 64 px, 120 px and 220 px.
6. Dark/glow variants are secondary and should not replace the clean default mark.
7. No Apple marks, iPhone outlines, robot heads, sparkle icons or generic AI magic motifs.

## Promotion path

Assets move through these states:

1. **Experiment** — rough exploration or generated image.
2. **Candidate** — committed SVG with title/desc metadata.
3. **Preferred candidate** — listed in this manifest as current best option.
4. **Default** — used by README, website and social profile.
5. **Locked** — only after visual review and maintainer approval.

## Visual review result — 2026-06-14

The v3 profile asset was rendered from the committed SVG at 64 px, 120 px and 220 px for local visual review. The mark remains legible at all three sizes: the open G ring, local identity i and light profile surface remain distinct enough for avatar use.

Comparison against `assets/brand/logo-mark.svg`, `assets/brand/logo-mark-v2.svg` and `assets/brand/logo-symbol-v3.svg` supports promoting v3 as the default public direction:

- the original mark has extra connector-line detail that is less useful at small avatar sizes,
- the v2 mark is clean but less aligned with the transparent v3 master symbol,
- the v3 profile and v3 symbol are consistent with each other and avoid text, Apple-owned visual language, robots, sparkle icons and generic AI motifs.

## Carousel proof update — 2026-06-18

The carousel template now has committed SVG proof covers for the three current social pillars:

- `assets/social/carousel-policy-before-action.svg`,
- `assets/social/carousel-local-first.svg`,
- `assets/social/carousel-approval-gated.svg`.

Each proof uses the documented two-line subtitle rows at `y=470` and `y=520` instead of one long subtitle line. This removes the earlier single-line overflow risk at the source level. The next gate is visual rendering/review of those committed SVGs before promoting the carousel from preferred template candidate to default social carousel.

Decision: keep the v3 symbol, profile and lockup as **default**. Promote the carousel from active template candidate to **preferred template candidate with committed proof covers**. Do not mark the full identity as **locked** until maintainer approval and final visual review are complete.

## Current recommendation

Use these for the next public-facing pass:

- Profile/avatar: `assets/social/instagram-profile-v3.svg`
- Master symbol: `assets/brand/logo-symbol-v3.svg`
- Header/README: `assets/brand/logo-lockup-v3.svg`
- Social post template candidate: `assets/social/instagram-carousel-template-v1.svg`
- Social proof covers:
  - `assets/social/carousel-policy-before-action.svg`
  - `assets/social/carousel-local-first.svg`
  - `assets/social/carousel-approval-gated.svg`

## Next review checklist

- Render/review the three committed carousel proof covers at 1080 x 1350.
- Re-check GitHub/social avatar appearance after applying `instagram-profile-v3.svg` on the public profile surface.
- Keep old assets as legacy comparison until final maintainer lock.
