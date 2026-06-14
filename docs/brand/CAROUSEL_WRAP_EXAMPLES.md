# Carousel Wrap Example Copy Notes

Last updated: 2026-06-14

## Purpose

This note is the first small wrap/example pass for `assets/social/instagram-carousel-template-v1.svg`.

It does not promote the carousel template to default or locked. It only records short cover-copy candidates that fit the current 1080 x 1350 template direction better than long single-line subtitles.

## Source template constraints

The current template uses:

- headline at `x=76`, `y=360`, `font-size=92`,
- subtitle at `x=76`, `y=470`, `font-size=40`,
- one white principle card at `x=76`, `y=690`, `width=928`, `height=360`,
- footer at `y=1260`.

Because the subtitle is currently a single SVG `<text>` line, each cover should use a short subtitle until a wrapped text variant is added.

## Example cover copy candidates

### 1. Policy before action

```text
Headline: Policy before action.
Subtitle: Every tool call should pass a visible rule first.
Card title: The rule comes first
Bullets:
- inspect the boundary
- ask before risk
- log the decision
```

Fit note: headline matches the existing template text. The subtitle is shorter than the current placeholder sentence and should be safer for one-line rendering.

### 2. Local first

```text
Headline: Local first.
Subtitle: Start on the trusted device before delegating out.
Card title: Keep control close
Bullets:
- local by default
- delegate only with checks
- no hidden network path
```

Fit note: headline is short. Subtitle stays concise and avoids long compound clauses.

### 3. Approval gated

```text
Headline: Approval gated.
Subtitle: Risky actions wait for a human yes.
Card title: Approval is the gate
Bullets:
- classify the risk
- request confirmation
- record metadata only
```

Fit note: headline is shorter than the policy headline. Subtitle should fit comfortably as a single line at the current size.

## Decision from this pass

The carousel template can support the three current social pillars if the copy stays compact. It should remain an active template candidate until one of these follow-up steps happens:

1. committed SVG example covers are added for the three variants, or
2. the template gains an explicit wrapped-subtitle layout.

Do not mark the carousel template as locked from this note alone.

## Guardrails

- Brand/documentation only.
- No Swift runtime changes.
- No workflow changes.
- No Apple marks, iPhone outlines, robot heads, sparkle icons or generic AI magic motifs.
- No private data, credentials, screenshots or external providers.
