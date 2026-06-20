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
- Issue #29 preparation scope is closed as completed: the repeatable real-device checklist and report template exist, while actual physical-device evidence remains pending and is not claimed.

## Current baseline

`main` includes:

- AgentCore policy, approval, audit, routing, risk, memory and delegation components,
- lock-protected AuditLog storage and metadata projections,
- task-received events that do not retain raw task text,
- metadata-only RuntimeBudget, ApprovalReceipt, DiagnosticSnapshot and LocalModelRuntime contracts,
- deterministic runtime rejection before model invocation,
- synthetic scenario and diagnostic UI support,
- an unsigned simulator wrapper and automated validation workflows,
- a privacy-safe physical-device checklist and report template.

## Current safety posture

- Policy and approval remain authoritative before action.
- Diagnostic and runtime contracts remain metadata-only.
- Restricted sensitive data remains blocked before automatic external delegation.
- No real model loading, networking, persistence, provider call or tool execution exists.
- RuntimeBudget and LocalModelRuntime are software contracts, not device-performance evidence.
- No signing, installation, launch or physical-device result is claimed.

## Current active target

Issue #25 `MVP Masterplan: Local-only iPhone diagnostic app` is the current verification and state-synchronization target.

The next autonomous cycle must verify the masterplan acceptance criteria against current source:

1. `PROJECT_STATE.md` accurately describes the local-only diagnostic MVP.
2. Roadmap material reflects the current Phase 0-4 sequence.
3. `docs/CHATGPT_NEXT_TASK.md` names exactly one unblocked next step.
4. The MVP remains usable without secrets, external services, real private data or network dependency.

If the criteria are already satisfied, close or synchronize Issue #25 accurately. If one detail is missing, apply only the smallest documentation fix. Do not open a parallel implementation PR.

## Validation contract

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

Docs-only state verification may use current source inspection. Any Swift, app-wrapper or workflow change still requires current-head validation.

## Evidence boundary

The repository proves deterministic software contracts and simulator-tested behavior. It does not yet prove actual model compatibility, memory use, latency, battery, thermal behavior, signing or physical-device readiness. Those observations remain owner/device evidence.

## Next sequence

1. Verify and synchronize Issue #25 against current source.
2. Close it if its planning acceptance criteria are already met, or apply one smallest missing documentation fix.
3. Select exactly one next unblocked product or safety issue.
4. Keep signing and physical-device execution outside autonomous claims.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.