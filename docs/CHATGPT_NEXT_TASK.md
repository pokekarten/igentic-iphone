# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-20

## Source-of-truth contract

Current GitHub source overrides this file, Brain and memory. A merged PR or closed issue may never be selected again from stale control text.

## Current operating mode

Mode: `HYBRID_PERSISTENT_LANE_V5`.

- iGentic uses Brain issue #25 as its persistent lane bus.
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

Current source review shows its planning acceptance criteria are satisfied:

- `PROJECT_STATE.md` describes the MVP as a local-only diagnostic and trust/control layer rather than a finished personal agent.
- `ROADMAP.md` documents the Phase 0-4 sequence and keeps device/model evidence separate from current software claims.
- This file names exactly one target.
- The documented MVP requires no secrets, external service, real private data or network dependency.
- Validation commands are documented.
- Physical-device signing and observation remain owner/device boundaries.

## Allowed autonomous result

The current V5 lane should independently review this evidence and, if unchanged, close Issue #25 as completed planning/state synchronization.

Do not select the next implementation target in the same closer step. After completion, a later context run must re-read current open issues and choose exactly one source-backed unblocked target.

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
- Reviewer decision must be current-source and write-confirmed.
- Closer may mutate only after `STATE_SYNC_READY`.
- At most one repository mutation.
- After completion, select no new implementation target in the same closer step.

## Expected terminal result

```text
ISSUE_CLOSED
STATE_SYNCED
REVIEW_BLOCKER_FOUND
WRITE_SKIPPED
```
