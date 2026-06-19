# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-19

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, current `main`, workflow evidence, review threads and issue acceptance criteria.

## Current operating mode

Mode: `IGENTIC_AUDIT_METADATA_QUERIES`.

- iGentic is the only active repository context.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions remain the independent validation environment.
- Codex and all recurring slot automations remain paused.
- Exactly one active implementation candidate is allowed.

## Recently completed

- PR #47 added metadata-only `DiagnosticSnapshot`.
- PR #48 `Add typed PolicyDecision reason codes` was squash-merged into `main` as `4a4579bb2b099a0e5b718940ff76e3b4635e80cc`.
- Issue #13 is closed with acceptance evidence.
- Issue #29 remains open for physical-device validation.

## Active target

PR #50 `Add metadata-only AuditLog query helpers` is the single active candidate and implements Issue #12.

Declared scope:

- `ios/Sources/AgentCore/AuditLog.swift`
- `ios/Tests/AgentCoreTests/AuditLogQueryTests.swift`
- `PROJECT_STATE.md`
- `docs/CHATGPT_NEXT_TASK.md`

## Goal

Add deterministic audit queries without exposing raw messages:

1. preserve `record(_:)` and `allEvents()`,
2. add `AuditEventMetadata` without message or UUID,
3. return stable metadata snapshots in recording order,
4. filter snapshots by event type,
5. filter snapshots by minimum sensitivity,
6. count events by type and minimum sensitivity,
7. keep every read and write within the existing lock boundary,
8. verify concurrent recording remains complete and queryable.

## Merge gate

Before PR #50 can merge:

- base must remain `main`,
- head SHA must remain stable during the final gate,
- changed files must match the four-file declared scope,
- PR Change Scope, Pull Request Quality, Docs Consistency, Repo Audit and Workflow Lint must pass,
- macOS and Linux Swift package build/tests must pass,
- tests must prove metadata-only output, deterministic filtering and unchanged raw-event behavior,
- thread-safety must not be weakened,
- no unresolved review thread or source-backed blocker may remain.

Inspect exact workflow logs before changing code. Do not make speculative fixes while a runner is queued or running.

## Required validation

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

## Safety rules

Do not add:

- databases, files or persistence,
- networking, external providers or model calls,
- app actions or real tool execution,
- raw private data or secrets,
- SwiftUI or app-route changes,
- signing or hardware behavior,
- physical-device success claims without direct observation.

Metadata query helpers must never return raw audit messages or event identifiers.

## Evidence boundary

A successful PR #50 proves only that audit metadata can be queried deterministically under the existing lock boundary.

It does not prove signing, physical-device behavior, accessibility, performance or production readiness. Issue #29 remains open.

## After PR #50

If the PR is validated and merged:

1. close Issue #12 with source-backed acceptance evidence,
2. keep Issue #29 open,
3. synchronize project state,
4. select at most one additional deterministic or simulator-verifiable safety slice.

## Expected terminal result

One of:

- `FIX_NEEDED`
- `WAITING_RUNNER`
- `READY_MARKED`
- `MERGED`
- `ISSUE_CLOSED`
- `OWNER_DEVICE_STEP`
