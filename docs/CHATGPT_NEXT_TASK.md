# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-19

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, current `main`, workflow evidence, review threads and issue acceptance criteria.

## Current operating mode

Mode: `IGENTIC_TYPED_POLICY_REASONS`.

- iGentic is the only active repository context.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions remain the independent validation environment.
- Codex and all recurring slot automations remain paused.
- Exactly one active implementation candidate is allowed.

## Recently completed

- PR #46 completed the synthetic safety matrix.
- PR #47 `Add metadata-only DiagnosticSnapshot` was squash-merged into `main` as `ba351e8b3206108a14d5dae5849287b657a09e54`.
- Issue #10 is closed with acceptance evidence.
- Issue #29 remains open for physical-device validation.

## Active target

PR #48 `Add typed PolicyDecision reason codes` is the single active candidate and implements Issue #13.

Declared scope:

- `ios/Sources/AgentCore/PolicyEngine.swift`
- `ios/Tests/AgentCoreTests/PolicyDecisionReasonTests.swift`
- `PROJECT_STATE.md`
- `docs/CHATGPT_NEXT_TASK.md`

## Goal

Add stable metadata without loosening policy behavior:

1. add `PolicyDecisionReason`,
2. keep existing free-text explanations,
3. explicitly code local-only non-local delegation blocking,
4. explicitly code restricted-data automatic delegation blocking,
5. explicitly code low-risk allow,
6. distinguish data-only, action-only and combined approval requirements,
7. keep direct/manual `PolicyDecision` construction source-compatible,
8. verify existing allow/block/approval booleans for every coded engine path.

## Merge gate

Before PR #48 can merge:

- base must remain `main`,
- head SHA must remain stable during the final gate,
- changed files must match the four-file declared scope,
- PR Change Scope, Pull Request Quality, Docs Consistency, Repo Audit and Workflow Lint must pass,
- macOS and Linux Swift package build/tests must pass,
- tests must cover at least three typed policy paths,
- existing policy strictness must not be loosened,
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

- runtime execution or real app actions,
- networking, external providers or model calls,
- persistence or private-data storage,
- real private data or secrets,
- SwiftUI or app-route changes,
- signing or hardware behavior,
- physical-device success claims without direct observation.

Typed metadata may complement existing prose, but it must not change the existing policy outcome.

## Evidence boundary

A successful PR #48 proves only that PolicyEngine outcomes expose stable typed reason metadata and retain their existing strictness.

It does not prove signing, physical-device behavior, accessibility, performance or production readiness. Issue #29 remains open.

## After PR #48

If the PR is validated and merged:

1. close Issue #13 with source-backed acceptance evidence,
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
