# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-20

## Source-of-truth contract

Current GitHub source overrides this file, Brain and remembered context. A merged PR or closed issue may never be selected again because this file is stale.

## Current operating mode

Mode: `IGENTIC_VERIFY_DEVICE_PREPARATION_SCOPE`.

- iGentic is handled by the first half of the continuous ten-slot hourly cycle.
- Exactly one ACTIVE target is allowed.
- Public GitHub Actions remain the independent code-validation environment.
- Pokekartenkiste remains outside this task.

## Recently completed

- PR #60 removed raw task text from AuditLog and merged as `ba562376fdb019ab20af19d2d8f68a1e6d626c90`.
- PR #61 added the two-file metadata-only LocalModelRuntime contract and merged as `a7ff62463a27e707b2fd5f1b431cbb426ffba35d`.
- Issues #58 and #59 are closed completed.

## Active target

Issue #29 `MVP-04: Prepare real-device validation report for iPhone Air readiness`.

Current repository artifacts already include:

- `docs/device-test-checklist.md`,
- `docs/reports/iphone-air-validation-template.md`.

The next cycle must independently verify the issue acceptance criteria against current source.

## Allowed autonomous result

Exactly one of:

1. `ISSUE_CLOSED` when the preparation acceptance criteria are fully satisfied by current files;
2. `DOC_FIX_APPLIED` for one smallest missing preparation detail;
3. `STATE_SYNCED` when only project control files are stale;
4. `OWNER_DEVICE_STEP` when the remaining work is actual signing, installation or physical-device observation;
5. `WRITE_SKIPPED` when the same-cycle parent/write gate is missing.

## Verification checklist

- The report template exists and separates observed facts, automated evidence, assumptions, unavailable prerequisites and failures.
- The checklist covers repository baseline, app-wrapper prerequisite, device/toolchain, build/install/launch, diagnostic UI, synthetic scenarios, privacy boundaries and qualitative performance.
- No private identifiers, secrets, signing material or unsupported device claim is requested.
- Current project state says real-device validation remains pending.
- No physical-device success is claimed without direct dated evidence.

## Safety rules

Do not add or claim:

- CoreML, MLX, Foundation Models or real model invocation,
- model weights, downloads or network calls,
- persistence, external providers or real tool execution,
- signing material, device identifiers or private data,
- benchmark, battery, memory, thermal or readiness results not directly observed,
- Pokekartenkiste changes.

## Merge/state gate

- Current GitHub issue/file state must be re-read immediately before acting.
- Reviewer decision must be same-cycle and write-confirmed.
- Closer may mutate only after `READY_FOR_CLOSE` or `STATE_SYNC_READY`.
- At most one repository mutation.
- After completion, select no new implementation target in the same closer slot.

## Expected terminal result

- `ISSUE_CLOSED`
- `DOC_FIX_APPLIED`
- `STATE_SYNCED`
- `OWNER_DEVICE_STEP`
- `REVIEW_BLOCKER_FOUND`
- `WRITE_SKIPPED`