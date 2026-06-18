# iGentic Social Identity

Last updated: 2026-06-18

## Purpose

This file defines the first social identity baseline for iGentic.

The goal is to make iGentic recognizable on public surfaces without turning the brand into generic AI hype.

## Current social asset system

| Asset | Use |
| --- | --- |
| `assets/social/instagram-profile-v3.svg` | Default public profile/avatar recommendation |
| `assets/social/instagram-profile.svg` | Earlier profile candidate, kept for comparison |
| `assets/social/instagram-carousel-template-v1.svg` | Preferred carousel cover/content template candidate |
| `assets/social/carousel-policy-before-action.svg` | Wrapped-copy proof cover for Policy before action |
| `assets/social/carousel-local-first.svg` | Wrapped-copy proof cover for Local first |
| `assets/social/carousel-approval-gated.svg` | Wrapped-copy proof cover for Approval gated |
| `assets/brand/logo-symbol-v3.svg` | Default transparent master symbol for flexible layouts |
| `assets/brand/logo-mark-dark-v3.svg` | Preferred dark social and slide surface candidate |
| `assets/brand/logo-lockup-v3.svg` | Default social header, website hero and README lockup |

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

Carousel cover copy should use two subtitle lines for realistic public copy instead of one long subtitle line. The first proof covers use the documented rows around `y=470` and `y=520` for:

- Policy before action,
- Local first,
- Approval gated.

The committed proof covers make the carousel direction stronger, but the template is not locked until the SVGs are rendered/reviewed at 1080 x 1350.

## Current judgement

The v3 direction is now the default public identity recommendation for the profile/avatar, transparent master symbol and README/header lockup.

The v3 profile asset is preferred over v2 for public identity because the committed SVG remains clear at 64 px, 120 px and 220 px, avoids text, removes the original connector-line detail and stays visually aligned with the transparent v3 master symbol.

The current best public profile candidate is:

```text
assets/social/instagram-profile-v3.svg
```

The carousel template direction is now a preferred candidate with committed wrapped-copy proof covers. The remaining gate is visual rendering/review of those covers before treating the carousel as the default public social template.

## Next checks

Before final public lock:

- Render/review `assets/social/carousel-policy-before-action.svg`, `assets/social/carousel-local-first.svg` and `assets/social/carousel-approval-gated.svg` at 1080 x 1350.
- Check circular crop readability after applying the profile asset on the actual public profile surface.
- Keep the old original and v2 marks as comparison assets until maintainer approval.
- Do not change Swift runtime code for brand-only work.
