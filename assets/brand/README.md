# iGentic Brand Assets

Last updated: 2026-06-13

This folder contains editable SVG assets for the iGentic open-source project identity.

The current direction is a clean, public-ready **candidate** corporate identity baseline. The v2 assets are preferred for social/profile usage because they are simpler, more legible at small sizes and easier to reuse than the first exploratory mark.

## Assets

| File | Use | Status |
| --- | --- | --- |
| `logo-mark.svg` | Original exploratory icon-only mark | Legacy candidate |
| `logo-lockup.svg` | Original README/website header lockup | Legacy candidate |
| `logo-mark-v2.svg` | Clean default brand mark for avatars and small placements | Preferred candidate |
| `logo-mark-dark.svg` | Dark-surface variant for dark UI, slides and campaigns | Candidate |
| `logo-mark-social.svg` | High-contrast blue social/avatar tile | Candidate |
| `logo-mark-mono.svg` | One-color fallback for masks, print and neutral docs | Required fallback |
| `logo-lockup-v2.svg` | Cleaner README/website lockup candidate | Preferred candidate |
| `social-card.svg` | GitHub/social preview card candidate | Existing candidate |

Related social asset:

| File | Use |
| --- | --- |
| `../social/instagram-profile.svg` | Current Instagram profile candidate |

## Design concept

The mark combines:

- a lowercase `i` for identity, user and local device trust,
- an open uppercase `G` for guardrails, governance and agent loop,
- calm blue/graphite contrast,
- rounded, minimal geometry.

The v2 mark removes tiny decorative connector details from the first version because profile avatars and GitHub icons need a stronger silhouette.

## Recommended usage

| Context | Recommended asset |
| --- | --- |
| Instagram profile | `assets/social/instagram-profile.svg` |
| GitHub avatar / small mark | `assets/brand/logo-mark-v2.svg` |
| README header | `assets/brand/logo-lockup-v2.svg` |
| Dark deck / dark website block | `assets/brand/logo-mark-dark.svg` |
| High-contrast social experiment | `assets/brand/logo-mark-social.svg` |
| One-color usage | `assets/brand/logo-mark-mono.svg` |

## Usage rules

Follow:

- `docs/brand/BRAND.md`
- `docs/brand/CORPORATE_IDENTITY.md`
- `docs/brand/DESIGN_SYSTEM.md`
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

The v2 assets are the current preferred candidate baseline, not final brand-lock assets. They are intended to make the repository look coherent while leaving room for community design feedback and further visual refinement.
