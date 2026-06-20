# Project State

Last updated: 2026-06-20

## Current status

`iGentic iPhone` is an open-source, privacy-first iPhone AI Runtime Layer research repository.

- Repository: `pokekarten/igentic-iphone`
- Visibility: public
- Validation: GitHub Actions on macOS and Linux
- Primary target device: iPhone Air as trust/control plane
- Current phase: diagnostic shell and safe local-model boundary design

## Recently completed

- PR #52 added metadata-only RuntimeBudget planning.
- PR #56 corrected AuditLog privacy documentation.
- PR #60 removed raw task text from task-received audit events.
- PR #61 added the metadata-only `LocalModelRuntime` contract and deterministic pre-invocation rejection tests; merge commit `a7ff62463a27e707b2fd5f1b431cbb426ffba35d`.
- Issues #58 and #59 are closed as completed.

## Current baseline

`main` includes:

- AgentCore policy, approval, audit, routing, risk, memory and delegation components,
- lock-protected AuditLog storage and metadata projections,
- task-received events that do not retain raw task text,
- metadata-only RuntimeBudget, ApprovalReceipt, DiagnosticSnapshot and LocalModelRuntime contracts,
- deterministic runtime rejection before model invocation,
- synthetic scenario and diagnostic UI support,
- an unsigned simulator wrapper and automated validation workflows.

## Current safety posture

- Policy and approval remain authoritative before action.
- Diagnostic and runtime contracts remain metadata-only.
- Restricted sensitive data remains blocked before automatic external delegation.
- No real model loading, networking, persistence, provider call or tool execution exists.
- RuntimeBudget and LocalModelRuntime are software contracts, not device-performance evidence.

## Current active target

Issue #29 `MVP-04: Prepare real-device validation report for iPhone Air readiness` is the current verification/state-sync target.

The repository already contains:

- `docs/device-test-checklist.md`,
- `docs/reports/iphone-air-validation-template.md`.

The next autonomous cycle must verify Issue #29 acceptance criteria against current files. If the preparation scope is fully satisfied, close/synchronize the issue accurately. If not, apply only the smallest missing documentation fix. Do not claim that a physical-device run occurred.

## Validation contract

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

For docs-only Issue #29 verification, current source inspection may establish document existence and scope. Any code or app-wrapper change still requires current-head workflows.

## Evidence boundary

The repository proves deterministic software contracts and simulator-tested behavior. It does not yet prove actual model compatibility, memory use, latency, battery, thermal behavior, signing or physical-device readiness. Those observations remain owner/device evidence.

## Next sequence

1. Verify Issue #29 preparation artifacts and acceptance criteria.
2. Close or minimally repair the preparation scope using source evidence only.
3. Select exactly one next unblocked issue.
4. Keep actual signing and physical-device execution outside autonomous claims.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.