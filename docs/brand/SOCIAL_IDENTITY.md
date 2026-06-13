# iGentic Social Identity

Last updated: 2026-06-13

## Purpose

This file defines the first social identity baseline for iGentic.

The goal is to make iGentic recognizable on public surfaces without turning the brand into generic AI hype.

## Current social asset system

| Asset | Use |
| --- | --- |
| `assets/social/instagram-profile-v3.svg` | Preferred Instagram profile candidate |
| `assets/social/instagram-profile.svg` | Earlier profile candidate |
| `assets/social/instagram-carousel-template-v1.svg` | First carousel cover/content template |
| `assets/brand/logo-symbol-v3.svg` | Transparent master symbol for flexible layouts |
| `assets/brand/logo-mark-dark-v3.svg` | Dark social and slide surfaces |
| `assets/brand/logo-lockup-v3.svg` | Social header, website hero and README candidate |

## Strategy

Use a responsive identity system instead of one logo for every context.

- Avatar: symbol only, no tagline.
- README / website header: lockup.
- Dark posts: dark mark.
- Carousel covers: large claim, small mark, one principle card.
- Long-form docs: lockup or symbol with text nearby.

## Social message pillars

1. **Policy before action** — AI should not act outside approved boundaries.
2. **Local first** — trusted device first, remote delegation only with checks.
3. **Approval gated** — risky actions require human approval.
4. **Audit ready** — decisions should leave inspectable metadata.
5. **Open source** — the control layer should be reviewable.

## Visual rules

- Keep profile images text-free.
- Use the symbol large enough to remain clear at 64 px.
- Avoid tiny decorative connector lines in avatar contexts.
- Prefer clean white/graphite/blue surfaces.
- Use dark/glow variants only for campaign or dark-mode surfaces.
- Do not use Apple marks, iPhone outlines or platform-owned visuals.
- Do not use robot heads, sparkle icons or generic AI magic motifs.

## Carousel template guidance

Use 1080 x 1350 for feed carousels.

Recommended structure:

1. Slide 1: strong claim.
2. Slide 2: small architecture diagram.
3. Slide 3: one policy rule.
4. Slide 4: example safe routing decision.
5. Slide 5: call for review, contribution or testing.

## Current judgement

The v3 direction is preferred over v2 for the public identity because it adds a transparent master symbol and a reusable social template while keeping the avatar mark simple.

The current best Instagram candidate is:

```text
assets/social/instagram-profile-v3.svg
```

## Next checks

Before final public lock:

- Render the profile asset at 64 px, 120 px and 220 px.
- Check circular crop readability.
- Compare against the original mark and v2 mark.
- Test the carousel template with three real posts.
- Decide whether README should switch to `logo-lockup-v3.svg`.
