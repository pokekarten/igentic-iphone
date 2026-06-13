# iGentic Brand Asset Manifest

Last updated: 2026-06-13

## Purpose

This manifest is the source of truth for iGentic brand assets in the repository.

It prevents the project from drifting between one-off logo experiments, generated images and undocumented social files.

## Current brand state

The current preferred identity direction is **v3 responsive brand system**.

The v3 direction is preferred because it separates the brand into context-specific assets:

- transparent master symbol,
- social/profile avatar,
- dark surface mark,
- horizontal lockup,
- carousel template,
- monochrome fallback.

## Canonical assets

| Asset | Path | Role | Status |
| --- | --- | --- | --- |
| Transparent master symbol | `assets/brand/logo-symbol-v3.svg` | flexible mark for custom surfaces | preferred candidate |
| Instagram profile | `assets/social/instagram-profile-v3.svg` | public profile/avatar candidate | preferred candidate |
| Dark mark | `assets/brand/logo-mark-dark-v3.svg` | dark decks, social posts, dark UI sections | preferred candidate |
| Lockup | `assets/brand/logo-lockup-v3.svg` | README, website hero, social header | preferred candidate |
| Carousel template | `assets/social/instagram-carousel-template-v1.svg` | first repeatable Instagram carousel layout | active template candidate |
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

## Current recommendation

Use these for the next public-facing pass:

- Profile: `assets/social/instagram-profile-v3.svg`
- Master symbol: `assets/brand/logo-symbol-v3.svg`
- Header: `assets/brand/logo-lockup-v3.svg`
- Social post template: `assets/social/instagram-carousel-template-v1.svg`

## Next review checklist

- Render profile at 64 px, 120 px and 220 px.
- Compare v3 against original and v2 assets.
- Test the carousel template with three real posts.
- Decide whether README should switch to `logo-lockup-v3.svg`.
- Decide whether the GitHub/social avatar should use `instagram-profile-v3.svg`.
