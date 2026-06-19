# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-19

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, current `main`, workflow evidence, review threads and issue acceptance criteria.

## Current operating mode

Mode: `IGENTIC_DIAGNOSTIC_SNAPSHOT`.

- iGentic is the only active repository context.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions remain the independent validation environment.
- Codex and all recurring slot automations remain paused.
- Exactly one active implementation candidate is allowed.

## Recently completed

- PR #45 added automated simulator runtime smoke evidence.
- PR #46 `Complete synthetic safety scenario catalog` was squash-merged into `main` as `efdcd79692dccaae7444d8606c6f7581b8cb872e`.
- Issue #16 is closed with acceptance evidence.
- Issue #29 remains open for physical-device validation.

## Active target

PR #47 `Add metadata-only DiagnosticSnapshot` is the single active candidate and implements Issue #10.

Declared scope:

- `ios/Sources/AgentCore/DiagnosticSnapshot.swift`
- `ios/Tests/AgentCoreTests/DiagnosticSnapshotTests.swift`
- `scripts/validate_repo_structure.py`
- `PROJECT_STATE.md`
- `docs/CHATGPT_NEXT_TASK.md`

## Goal

Add a safe Phase 2 readiness building block without coupling UI to runtime internals:

1. represent generated time and privacy mode,
2. summarize policy allow/approval state,
3. summarize approval status,
4. summarize audit count and highest sensitivity,
5. summarize delegation using a typed outcome,
6. summarize numeric risk metadata,
7. emit deterministic metadata lines,
8. prove raw policy, approval, audit, delegation and risk reason strings cannot appear in output.

## Merge gate

Before PR #47 can merge:

- base must remain `main`,
- head SHA must remain stable during the final gate,
- changed files must match the five-file declared scope,
- PR Change Scope, Pull Request Quality, Docs Consistency, Repo Audit and Workflow Lint must pass,
- macOS and Linux Swift package build/tests must pass,
- repository structure validation must pass,
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

- SwiftUI or app-route changes,
- App Intents or real tool execution,
- persistence or private-data storage,
- networking, external providers or model calls,
- real private data,
- screenshots, signing or hardware behavior,
- physical-device success claims without direct observation.

The snapshot must not retain or emit runtime reason text, audit messages, approval identifiers or private raw values.

## Evidence boundary

A successful PR #47 proves only that safe diagnostic state can be represented as deterministic metadata in AgentCore.

It does not prove signing, physical-device behavior, accessibility, performance or production readiness. Issue #29 remains open.

## After PR #47

If the PR is validated and merged:

1. close Issue #10 with source-backed acceptance evidence,
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
