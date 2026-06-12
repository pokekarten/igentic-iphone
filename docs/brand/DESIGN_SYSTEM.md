# iGentic Design System

Last updated: 2026-06-12

## Design goal

The design system should make iGentic feel like a trustworthy system layer: calm, private, precise and open-source.

It should be compatible with premium Apple-platform expectations without copying Apple product visuals, Apple logos, Apple UI chrome or Apple marketing layouts.

## Core visual metaphor

**Control ring + local identity + policy line**

- The identity point represents the user and local device.
- The open ring represents policy boundaries and the agent loop.
- The connector line represents delegation that only happens after checks.
- Empty space represents restraint and privacy.

## Color tokens

| Token | Hex | Use |
| --- | --- | --- |
| `brand.white` | `#F8FAFC` | Main background |
| `brand.paper` | `#FFFFFF` | Cards, docs, panels |
| `brand.mist` | `#EEF2F7` | Soft sections |
| `brand.silver` | `#D8DEE9` | Borders, dividers, quiet surfaces |
| `brand.airBlue` | `#8EC5FF` | Primary accent, subtle glow |
| `brand.trustBlue` | `#3B82F6` | Links, CTAs, active states |
| `brand.graphite` | `#111827` | Main text |
| `brand.slate` | `#475569` | Secondary text |
| `state.local` | `#22C55E` | Local-only safe state |
| `state.review` | `#F59E0B` | Approval required |
| `state.blocked` | `#EF4444` | Blocked risk or policy denial |

## Gradients

Use gradients sparingly.

```css
--gradient-air: linear-gradient(135deg, #F8FAFC 0%, #EEF6FF 48%, #DCEBFF 100%);
--gradient-ring: linear-gradient(135deg, #C8D1DC 0%, #8EC5FF 52%, #3B82F6 100%);
--gradient-graphite: linear-gradient(135deg, #111827 0%, #334155 100%);
```

## Typography

Use system fonts by default:

```css
font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", system-ui, sans-serif;
```

Typography should be calm and readable:

- H1: large, light-to-medium weight, high whitespace.
- H2/H3: precise, not decorative.
- Body: short paragraphs, strong section labels.
- Code/docs: monospace only for code, paths and command snippets.

## Layout

### Website landing page

1. Hero with logo mark, one-line promise and three principle chips.
2. Architecture flow with policy gates.
3. Operating modes: Local Only, Trusted Devices, External AI.
4. Roadmap: current phase and next three milestones.
5. Community CTA: GitHub issues, discussions and contribution docs.

### Repository README

The README should work like a public front door:

- What is this?
- Why does it exist?
- What exists now?
- How can I contribute safely?
- What is explicitly out of scope?

### Social cards

Use a repeatable carousel structure:

1. Strong claim.
2. Small architecture diagram.
3. Concrete policy rule.
4. Open question or contribution CTA.

## Components

### Principle chips

- `Local First`
- `Approval Gated`
- `Audit Ready`
- `Controlled Delegation`

### Policy state badges

| Badge | Meaning |
| --- | --- |
| `LOCAL ONLY` | Runs on trusted local device only |
| `APPROVAL REQUIRED` | User must approve before action |
| `DELEGATION CHECK` | Task may move to a trusted worker after policy checks |
| `BLOCKED` | Data class or action risk is not allowed |

### Architecture cards

Each architecture card should include:

- one responsibility,
- one data boundary,
- one failure mode,
- one validation note.

## Motion direction

If animation is added later:

- Use slow, subtle ring movement.
- Show policy gates as discrete transitions.
- Never imply uncontrolled automation.
- Avoid flashy AI sparkles, particle storms or aggressive gradients.

## Accessibility

- Do not rely on color alone for policy states.
- Ensure strong contrast for text.
- Keep diagrams readable in grayscale.
- Provide alt text for all brand and architecture images.

## Design quality bar

A design is acceptable when it communicates:

1. The user remains in control.
2. Private data is not casually delegated.
3. The project is open-source and inspectable.
4. The system is experimental and safety-first.
5. The brand is ownable and not dependent on Apple trade dress.
