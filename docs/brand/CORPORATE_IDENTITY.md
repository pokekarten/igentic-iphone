# iGentic Corporate Identity

Last updated: 2026-06-13

## CI decision

The current public-facing identity direction is **clean technical trust**.

iGentic should look like a careful control layer for personal AI systems: calm, precise, local-first, approval-gated and audit-ready.

The brand should not look like:

- a generic chatbot,
- a robot assistant,
- an Apple clone,
- a neon AI toy,
- surveillance software,
- an uncontrolled automation platform.

## Master identity

| Element | Decision |
| --- | --- |
| Master brand | `iGentic` |
| Research track | `iGentic iPhone` |
| Core promise | Private AI that acts only within boundaries you control |
| Visual metaphor | Open control ring + local identity point |
| Primary public mark | `assets/brand/logo-mark-v2.svg` |
| Instagram candidate | `assets/social/instagram-profile.svg` |
| Dark surface mark | `assets/brand/logo-mark-dark.svg` |
| One-color fallback | `assets/brand/logo-mark-mono.svg` |
| Lockup candidate | `assets/brand/logo-lockup-v2.svg` |

## Logo strategy

The v2 mark intentionally removes small decorative details from the first mark.

Why:

- Instagram and GitHub avatars must work at very small sizes.
- The symbol should be recognizable before the wordmark is readable.
- The brand should feel ownable and technical, not like a screenshot or marketing mockup.
- Editable SVGs are preferred over raster-only generated images.

### Recommended hierarchy

1. **Default avatar:** `assets/social/instagram-profile.svg`
2. **Default brand mark:** `assets/brand/logo-mark-v2.svg`
3. **Dark UI / campaign surfaces:** `assets/brand/logo-mark-dark.svg`
4. **High-contrast social tile:** `assets/brand/logo-mark-social.svg`
5. **Neutral fallback:** `assets/brand/logo-mark-mono.svg`
6. **README / website header:** `assets/brand/logo-lockup-v2.svg`

## Visual principles

### 1. Control over hype

Use clean geometry, explicit states and calm surfaces. Avoid sparkles, magic or aggressive AI gradients.

### 2. Human at the center

The lowercase `i` is the identity point: user, local device and consent. The open `G` is the guardrail/control loop around it.

### 3. Open, not closed

The control ring should stay open. It signals inspectability, review and controlled delegation rather than a closed black box.

### 4. Premium but not Apple-owned

Use high-quality spacing, quiet gradients and system typography, but do not use Apple logos, iPhone silhouettes, Dynamic Island shapes, Apple UI chrome or Apple campaign styling.

### 5. Small-size first

A logo candidate is acceptable only if it remains recognizable at 64 px and still feels intentional inside a circular avatar crop.

## Color system

### Core palette

| Token | Hex | Role |
| --- | --- | --- |
| `brand.white` | `#F8FAFC` | main calm background |
| `brand.paper` | `#FFFFFF` | clean panels and logo surfaces |
| `brand.mist` | `#EEF6FF` | light blue-tinted surface |
| `brand.silver` | `#D8DEE9` | borders and quiet structure |
| `brand.signalBlue` | `#0B63F6` | primary mark blue |
| `brand.airBlue` | `#8EC5FF` | glow and secondary accent |
| `brand.deepBlue` | `#0647B8` | gradient depth |
| `brand.graphite` | `#111827` | text and identity stem |
| `brand.night` | `#020617` | dark-mode base |

### State palette

Keep state colors semantic and restrained:

| State | Hex | Meaning |
| --- | --- | --- |
| Local | `#22C55E` | safe local-only operation |
| Review | `#F59E0B` | approval or reviewer attention required |
| Blocked | `#EF4444` | denied or unsafe path |

## Typography

Use system fonts by default:

```css
font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", system-ui, sans-serif;
```

Guidance:

- Use medium weights for headings.
- Prefer short, precise sentences.
- Use monospace only for paths, commands and code.
- Do not over-brand with decorative fonts.

## Voice and tone

The iGentic voice is:

- calm,
- precise,
- safety-first,
- open-source friendly,
- technically honest,
- never hype-driven.

Preferred phrases:

- Local-first AI control layer.
- Approval-gated by design.
- Audit-ready decisions.
- Controlled delegation.
- Private by default.

Avoid:

- Autonomous magic.
- Fully hands-free AI.
- Replaces you.
- Unlimited delegation.
- Apple-style claims or platform endorsement language.

## Social identity

### Instagram profile

Use `assets/social/instagram-profile.svg` as the current candidate.

Rationale:

- no tiny tagline,
- strong icon silhouette,
- light premium surface,
- clear blue control ring,
- readable inside circular crop.

### Social post direction

Use simple carousels:

1. Problem: uncontrolled AI actions are unsafe.
2. Principle: policy before action.
3. Diagram: local identity inside control ring.
4. Concrete rule: approval required for risky delegation.
5. CTA: contribute, review or test the open-source runtime.

## Review rubric

Before promoting any asset to official locked status, check:

- Does it still work at 64 px?
- Does it work in a circular avatar crop?
- Is it readable on light and dark backgrounds?
- Is it still editable SVG?
- Does it avoid Apple-owned visual language?
- Does it communicate control, privacy and trust?
- Does it avoid generic AI hype?
- Can contributors understand the system from the mark and docs?

## Current status

The current v2 identity is a **candidate public baseline**, not a final legal brand lock.

Next visual review should compare:

- `logo-mark-v2.svg` against the original `logo-mark.svg`,
- `instagram-profile.svg` at 64 px, 120 px and 220 px,
- `logo-lockup-v2.svg` in the README header,
- dark logo contrast on near-black backgrounds.
