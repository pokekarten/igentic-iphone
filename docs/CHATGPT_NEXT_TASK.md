# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-19

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, current `main`, workflow evidence, review threads and issue acceptance criteria.

## Current operating mode

Mode: `IGENTIC_RUNTIME_BUDGET_METADATA`.

- iGentic is the only active repository context.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions remain the independent validation environment.
- Codex and all recurring slot automations remain paused.
- Exactly one active implementation candidate is allowed.

## Recently completed

- PR #50 added lock-protected AuditLog metadata query helpers.
- PR #51 `Add ToolRegistry contract validation` was squash-merged into `main` as `8730b302ef2a30175d4bd6d330ef15d741e29964`.
- Issue #15 is closed with acceptance evidence.
- Issue #29 remains open for physical-device validation.

## Active target

PR #52 `Add metadata-only RuntimeBudget model` is the single active candidate and implements Issue #14.

Declared scope:

- `ios/Sources/AgentCore/RuntimeBudget.swift`
- `ios/Tests/AgentCoreTests/RuntimeBudgetTests.swift`
- `PROJECT_STATE.md`
- `docs/CHATGPT_NEXT_TASK.md`

## Goal

Represent future local-device capability planning without measuring real hardware:

1. define typed execution classes (`tiny`, `small`, `large`),
2. define typed expected locality (`local-only`, `trusted-device`, `external-required`),
3. define typed estimated-memory classes (`low`, `moderate`, `high`),
4. preserve stable ordering for execution and memory classes,
5. expose deterministic metadata lines for diagnostic display,
6. preserve caller-supplied synthetic reasons in input order,
7. make external-runtime requirements explicit,
8. keep the model independent from routing, hardware and model-loading APIs.

## Merge gate

Before PR #52 can merge:

- base must remain `main`,
- head SHA must remain stable during the final gate,
- changed files must match the four-file declared scope,
- PR Change Scope, Pull Request Quality, Docs Consistency, Repo Audit and Workflow Lint must pass,
- macOS and Linux Swift package build/tests must pass,
- tests must cover deterministic construction, metadata output, class ordering and explicit external-runtime behavior,
- no actual hardware probing, runtime measurement, CoreML, MLX or model loading may be added,
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

- hardware probing or real performance measurements,
- CoreML, MLX, model weights or model loading,
- routing behavior or automatic delegation changes,
- file access, databases or persistence,
- networking, external providers or model calls,
- secrets or real private data,
- SwiftUI or app-route changes,
- App Intents, signing or physical-device success claims.

## Evidence boundary

A successful PR #52 proves only that runtime capability assumptions can be represented as typed, deterministic metadata.

It does not prove actual iPhone capacity, memory use, latency, model compatibility, signing, physical-device behavior, accessibility or production readiness. Issue #29 remains open.

## After PR #52

If the PR is validated and merged:

1. close Issue #14 with source-backed acceptance evidence,
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
