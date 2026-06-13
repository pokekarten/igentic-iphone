# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

ChatGPT works directly through the GitHub Connector for small repository-control and documentation steps. Code PRs stay narrow and are reviewed before merge.

## Active cycle

Target: PR #31 validation cleanup before merge.

Current PR: #31 `Issue #18: add ApprovalReceipt metadata`

Status:

- PR #31 is open and still draft.
- The ApprovalReceipt code scope is small and acceptable.
- Swift build/test evidence was previously green in the PR checks.
- Repo Audit and Phase 0 repo-structure validation failed because `PROJECT_STATE.md` did not mention the exact status markers expected by the validator.
- The marker-only fix has now been applied on `main` in `PROJECT_STATE.md`.
- `PROJECT_STATE.md` now explicitly mentions `docs/brand/BRAND.md` and `docs/community/COMMUNITY_STRATEGY.md`.

## Next task

Re-check PR #31 after the base-branch marker fix:

1. Confirm that PR #31 has refreshed against the updated `main` branch.
2. Confirm that Repo Audit and Phase 0 CI Validation are green for PR #31 or its current merge ref.
3. Keep PR #31 as draft until those checks are green.
4. Only after green validation: mark PR #31 ready for review, perform final review, then merge if still clean.

## Deferred task

Issue #1 can still be closed as completed, but it is not the active first step while PR #31 is open and awaiting validation cleanup.

## Guardrails

- Do not change ApprovalReceipt code as part of the validation cleanup.
- Do not change workflows or package files.
- Do not broaden the scope beyond validation and review for PR #31.
- One small validation-oriented step per cycle.
