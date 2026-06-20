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
- Issues #25, #29, #58 and #59 are closed completed for their documented scope.

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

PR #49 `chore(deps): bump actions/checkout from 6 to 7` is the single current gate target because an existing open PR takes priority over new work.

Current source state:

- one-file workflow dependency change in `.github/workflows/unpack-bootstrap-zip.yml`,
- head `60a1821c975d18fe9a4b466891276c3340462f65`,
- open and not Draft,
- one commit ahead and 39 commits behind current `main`,
- current-head workflow evidence includes successful scope, quality, docs, audit, lint, Phase 0 and Swift runs,
- GitHub currently reports the PR as not mergeable.

The current task is to resolve branch freshness or conflict state without creating a duplicate dependency PR. No merge is allowed while mergeability remains unresolved.

## Queued next target

Issue #6 `Research: Add App Intents safety notes for draft-first action patterns` remains the next documentation-only candidate after PR #49 is merged, closed or explicitly blocked.

Issue #6 must:

1. explain draft-before-execute and approval-before-critical-action patterns,
2. use synthetic examples only,
3. cite current official Apple sources for platform-dependent claims,
4. state clearly that App Intents and real actions are not implemented,
5. preserve privacy, policy and audit boundaries.

## Validation contract

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

For PR #49, current-head GitHub Actions are the primary evidence because the change is a workflow dependency reference. For future Issue #6 documentation work, repository-structure validation is required when links or required files change; Swift validation is required only if Swift source changes.

## Evidence boundary

The repository proves deterministic software contracts and simulator-tested behavior. It does not yet prove actual model compatibility, memory use, latency, battery, thermal behavior, signing, App Intents execution or physical-device readiness. Those observations remain owner/device evidence.

## Next sequence

1. Re-read PR #49 head, mergeability, review threads and current-head workflows.
2. Refresh or resolve the existing Dependabot branch in place without expanding the one-file scope.
3. Independently review and merge only after stable-head evidence and mergeability are clean.
4. Then return to Issue #6 as the next documentation candidate.
5. Keep signing, entitlements, real actions and physical-device execution outside autonomous claims.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.
