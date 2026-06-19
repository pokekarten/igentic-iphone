# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-19

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, current `main`, workflow evidence, review threads and issue acceptance criteria.

## Current operating mode

Mode: `IGENTIC_TOOL_CONTRACT_VALIDATION`.

- iGentic is the only active repository context.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions remain the independent validation environment.
- Codex and all recurring slot automations remain paused.
- Exactly one active implementation candidate is allowed.

## Recently completed

- PR #48 added typed policy reason metadata.
- PR #50 `Add metadata-only AuditLog query helpers` was squash-merged into `main` as `94f20aea5bd739339586af9ff9a0d66aab162e29`.
- Issue #12 is closed with acceptance evidence.
- Issue #29 remains open for physical-device validation.

## Active target

PR #51 `Add ToolRegistry contract validation` is the single active candidate and implements Issue #15.

Declared scope:

- `ios/Sources/AgentCore/ToolRegistry.swift`
- `ios/Tests/AgentCoreTests/ToolRegistryValidationTests.swift`
- `PROJECT_STATE.md`
- `docs/CHATGPT_NEXT_TASK.md`

## Goal

Validate metadata contracts without adding execution:

1. require a non-empty tool name,
2. keep required data level and action risk mandatory and typed,
3. normalize outer whitespace for valid names,
4. return explicit success, invalid-name or duplicate-name outcomes,
5. keep first valid registration on duplicates,
6. preserve deterministic sorted snapshots,
7. keep existing callers source-compatible,
8. verify initialization handles invalid and duplicate definitions deterministically.

## Merge gate

Before PR #51 can merge:

- base must remain `main`,
- head SHA must remain stable during the final gate,
- changed files must match the four-file declared scope,
- PR Change Scope, Pull Request Quality, Docs Consistency, Repo Audit and Workflow Lint must pass,
- macOS and Linux Swift package build/tests must pass,
- valid metadata, missing names, whitespace-only names, duplicates and sorted snapshots must be tested,
- no actual tool execution may be added,
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

- real tools, tool execution or App Intents,
- file access, databases or persistence,
- networking, external providers or model calls,
- secrets or real private data,
- SwiftUI or app-route changes,
- signing or hardware behavior,
- physical-device success claims without direct observation.

## Evidence boundary

A successful PR #51 proves only that metadata-only tool definitions are validated and registered deterministically.

It does not prove execution safety, signing, physical-device behavior, accessibility, performance or production readiness. Issue #29 remains open.

## After PR #51

If the PR is validated and merged:

1. close Issue #15 with source-backed acceptance evidence,
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
