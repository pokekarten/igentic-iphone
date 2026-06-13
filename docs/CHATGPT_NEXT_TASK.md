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
- Swift build/test evidence is green in the PR checks.
- Repo Audit and Phase 0 repo-structure validation failed because `PROJECT_STATE.md` does not mention the exact status markers expected by the validator.
- The required marker fix is documented in `docs/status/2026-06-13-project-state-marker-fix.md`.

## Next task

Apply the marker-only docs fix:

1. Update the existing Brand/community bullet in `PROJECT_STATE.md` so it explicitly mentions:
   - `docs/brand/BRAND.md`
   - `docs/community/COMMUNITY_STRATEGY.md`
2. Rerun or re-check Repo Audit and Phase 0 CI Validation for PR #31.
3. Keep PR #31 as draft until those checks are green.
4. Only after green validation: mark PR #31 ready for review, perform final review, then merge if still clean.

## Deferred task

Issue #1 can still be closed as completed, but it is not the active first step while PR #31 is open and awaiting validation cleanup.

## Guardrails

- Do not change ApprovalReceipt code as part of the marker fix.
- Do not change workflows or package files.
- Do not broaden the scope beyond the exact validation marker repair.
- One small validation-oriented step per cycle.
