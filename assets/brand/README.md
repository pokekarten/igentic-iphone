# iGentic Brand Assets

Last updated: 2026-06-13

This folder contains editable SVG assets for the iGentic open-source project identity.

The current direction is a clean, public-ready **candidate** corporate identity baseline. The v3 assets are preferred for social/profile usage because they introduce a transparent master symbol, stronger small-size readability and a reusable social system.

## Assets

| File | Use | Status |
| --- | --- | --- |
| `logo-mark.svg` | Original exploratory icon-only mark | Legacy candidate |
| `logo-lockup.svg` | Original README/website header lockup | Legacy candidate |
| `logo-mark-v2.svg` | Clean default brand mark for avatars and small placements | Candidate |
| `logo-mark-dark.svg` | Dark-surface variant for dark UI, slides and campaigns | Candidate |
| `logo-mark-social.svg` | High-contrast blue social/avatar tile | Candidate |
| `logo-mark-mono.svg` | One-color fallback for masks, print and neutral docs | Required fallback |
| `logo-lockup-v2.svg` | Cleaner README/website lockup candidate | Candidate |
| `logo-symbol-v3.svg` | Transparent master symbol for flexible usage | Preferred candidate |
| `logo-mark-dark-v3.svg` | Dark premium social/presentation mark | Preferred dark candidate |
| `logo-lockup-v3.svg` | README, website hero and social header lockup | Preferred lockup candidate |
| `social-card.svg` | GitHub/social preview card candidate | Existing candidate |

Related social assets:

| File | Use |
| --- | --- |
| `../social/instagram-profile.svg` | Earlier Instagram profile candidate |
| `../social/instagram-profile-v3.svg` | Preferred Instagram profile candidate |
| `../social/instagram-carousel-template-v1.svg` | First reusable Instagram carousel template |

## Design concept

The mark combines:

- a lowercase `i` for identity, user and local device trust,
- an open uppercase `G` for guardrails, governance and agent loop,
- calm blue/graphite contrast,
- rounded, minimal geometry.

The v3 system keeps the profile mark simple, adds a transparent master symbol, and separates avatar, lockup, dark-mode and social-carousel use cases.

## Recommended usage

| Context | Recommended asset |
| --- | --- |
| Instagram profile | `assets/social/instagram-profile-v3.svg` |
| Flexible mark on custom backgrounds | `assets/brand/logo-symbol-v3.svg` |
| README header | `assets/brand/logo-lockup-v3.svg` |
| Dark deck / dark website block | `assets/brand/logo-mark-dark-v3.svg` |
| First carousel template | `assets/social/instagram-carousel-template-v1.svg` |
| One-color usage | `assets/brand/logo-mark-mono.svg` |

## Usage rules

Follow:

- `docs/brand/BRAND.md`
- `docs/brand/CORPORATE_IDENTITY.md`
- `docs/brand/SOCIAL_IDENTITY.md`
- `docs/brand/DESIGN_SYSTEM.md`
- `docs/brand/DESIGN_SYSTEM_V2_NOTES.md`
- `docs/brand/LOGO_BRIEF.md`
- `docs/brand/LOGO_USAGE.md`

## Accessibility rules

Every SVG should include:

- `<title>`
- `<desc>`
- `role="img"`
- meaningful alt text wherever embedded in markdown or HTML.

## Review checklist

Before treating an asset as official, check:

- readable at small sizes,
- works in a circular profile crop,
- works in monochrome or has a monochrome variant,
- does not look like an Apple-owned mark,
- does not use an iPhone outline, Dynamic Island, camera bump or Apple logo,
- communicates control, privacy and trust rather than generic AI hype,
- can be understood by contributors from the README.

## Current status

The v3 assets are the current preferred candidate baseline, not final brand-lock assets. They are intended to make the repository look coherent while leaving room for community design feedback and further visual refinement.
