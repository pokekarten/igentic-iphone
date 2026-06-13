# PROJECT_STATE marker fix

Date: 2026-06-13

## Problem

PR #31 has a small code scope, but Repo Audit and Phase 0 repo-structure validation fail before the ApprovalReceipt tests matter.

The validator expects two explicit markers in `PROJECT_STATE.md`:

- `docs/brand/BRAND.md`
- `docs/community/COMMUNITY_STRATEGY.md`

## Cause

`PROJECT_STATE.md` was shortened and now says only that brand and community docs exist. The validator still checks for the two exact paths.

## Smallest safe fix

In `PROJECT_STATE.md`, update the existing Brand/community bullet so it explicitly mentions both paths:

```md
- Brand/community docs and initial SVG assets, including `docs/brand/BRAND.md` and `docs/community/COMMUNITY_STRATEGY.md`
```

## Required follow-up

After the marker-only docs fix:

1. Rerun Repo Audit.
2. Rerun Phase 0 CI Validation.
3. Keep PR #31 as draft until those checks are green.

## Scope guard

Do not change ApprovalReceipt code, workflows, package files, Swift runtime behavior, persistence, network behavior, or model behavior as part of this marker fix.
