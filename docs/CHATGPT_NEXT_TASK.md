# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-20

## Source-of-truth contract

Current GitHub source overrides this file, Brain and memory. A merged PR or closed issue may never be selected again from stale control text.

## Current operating mode

Mode: `IGENTIC_VERIFY_MVP_MASTERPLAN_STATE`.

- iGentic is handled by the first half of the continuous V4 ten-slot cycle.
- Exactly one ACTIVE target is allowed.
- Public GitHub Actions remain the independent code-validation environment.
- Pokekartenkiste remains outside this task.

## Recently completed

- PR #60 removed raw task text from AuditLog and merged as `ba562376fdb019ab20af19d2d8f68a1e6d626c90`.
- PR #61 added the metadata-only LocalModelRuntime contract and merged as `a7ff62463a27e707b2fd5f1b431cbb426ffba35d`.
- Issues #58 and #59 are closed completed.
- Issue #29 is closed completed for preparation scope. The device checklist and report template exist; no physical-device result is claimed.

## ACTIVE target

Issue #25 `MVP Masterplan: Local-only iPhone diagnostic app`.

The next cycle must independently verify its planning acceptance criteria against current source.

## Verification checklist

- `PROJECT_STATE.md` describes the MVP as a local-only diagnostic and trust/control layer rather than a finished personal agent.
- Roadmap material places current work in the Phase 0-4 sequence.
- This file names exactly one next unblocked target.
- The documented MVP requires no secrets, external service, real private data or network dependency.
- Completed child work and closed issues are not still presented as active.
- Physical-device signing and observation remain an owner/device boundary.

## Allowed autonomous result

Exactly one of:

1. `ISSUE_CLOSED` when Issue #25 planning acceptance criteria are fully satisfied;
2. `DOC_FIX_APPLIED` for one smallest missing state or roadmap detail;
3. `STATE_SYNCED` when only control files or issue text are stale;
4. `REVIEW_BLOCKER_FOUND` when current source contradicts the masterplan;
5. `WRITE_SKIPPED` when the same-cycle parent or bus write gate is missing.

## Safety rules

Do not add or claim:

- CoreML, MLX, Foundation Models or real model invocation,
- model weights, downloads or network calls,
- persistence, external providers or real tool execution,
- App Intents or real actions,
- signing material, device identifiers or private data,
- benchmark, battery, memory, thermal or physical-device readiness results,
- Pokekartenkiste changes.

## Merge/state gate

- Re-read Issue #25 and relevant files immediately before acting.
- Reviewer decision must be same-cycle and write-confirmed.
- Closer may mutate only after `READY_FOR_CLOSE` or `STATE_SYNC_READY`.
- At most one repository mutation.
- After completion, select no new implementation target in the same closer slot.

## Expected terminal result

```text
ISSUE_CLOSED
DOC_FIX_APPLIED
STATE_SYNCED
REVIEW_BLOCKER_FOUND
WRITE_SKIPPED
```