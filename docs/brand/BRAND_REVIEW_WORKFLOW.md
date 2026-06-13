# iGentic Brand Review Workflow

Last updated: 2026-06-13

## Purpose

This workflow keeps iGentic brand work focused and reviewable.

It prevents loops where a new logo is generated, liked visually, but not anchored into the repository as a reusable asset system.

## Scope

This workflow applies to:

- logo marks,
- lockups,
- social avatars,
- social templates,
- brand colors,
- brand docs,
- README / website brand presentation.

It does not apply to Swift runtime behavior.

## Working rule

Brand work should always move in this order:

1. Explore visually.
2. Judge honestly against the brand principles.
3. Convert good concepts into editable SVG.
4. Commit assets to `assets/brand/` or `assets/social/`.
5. List them in `docs/brand/BRAND_ASSET_MANIFEST.md`.
6. Update `docs/brand/SOCIAL_IDENTITY.md` or `docs/brand/CORPORATE_IDENTITY.md` when the system changes.
7. Add the next visual review task to `docs/CHATGPT_NEXT_TASK.md`.

## Do not skip the manifest

Every official or candidate asset must be listed in:

```text
docs/brand/BRAND_ASSET_MANIFEST.md
```

If an asset is not listed there, it is not part of the current brand system.

## Review criteria

A brand asset is acceptable only when it passes these checks:

- It is committed as editable SVG.
- It includes `<title>`, `<desc>` and `role="img"`.
- It remains legible at 64 px.
- It works inside a circular social crop if used as an avatar.
- It has enough contrast on its intended background.
- It does not rely on a tagline to explain the mark.
- It avoids Apple-owned visual language.
- It avoids robot, sparkle, magic and generic AI tropes.
- It communicates control, privacy and trust.

## Promotion states

| State | Meaning | Required evidence |
| --- | --- | --- |
| Experiment | rough direction, generated image or sketch | visual judgement only |
| Candidate | committed SVG asset | SVG metadata and manifest entry |
| Preferred candidate | best current option | manifest lists it as preferred |
| Default | actively used in README/profile/site | references updated |
| Locked | final approved identity | maintainer approval and status note |

## Current preferred track

The current preferred track is v3:

- `assets/brand/logo-symbol-v3.svg`
- `assets/social/instagram-profile-v3.svg`
- `assets/brand/logo-mark-dark-v3.svg`
- `assets/brand/logo-lockup-v3.svg`
- `assets/social/instagram-carousel-template-v1.svg`

## Next high-value brand tasks

1. Render v3 profile at 64 px, 120 px and 220 px.
2. Compare against original and v2 assets.
3. Test the carousel template with three real topics.
4. If v3 passes, switch README and public-facing docs to v3.
5. Keep old assets as legacy comparison until final lock.
