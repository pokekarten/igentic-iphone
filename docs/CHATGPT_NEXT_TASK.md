# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-19

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, head SHA, changed files, checks, review threads and issue scope.

## Current operating mode

Mode: `IGENTIC_FOCUS_BURST`.

- iGentic is the active implementation lane.
- Pokekartenkiste remains outside this repository and must not be touched from this task.
- Use one active runtime PR at a time.
- Public GitHub Actions are the primary independent validation environment.
- Codex remains paused unless a later task is explicitly routed as a narrow Draft-PR handoff.

## Recently completed

PR #37 `Add carousel proof covers for social pillars` was squash-merged into `main` as `1b6304b49fd5b0cccfc51ff4efff2eb91d3510ac`.

Before merge:

- PR Change Scope passed.
- Pull Request Quality passed.
- Docs Consistency passed.
- Repo Audit passed.
- Phase 0 CI Validation passed.
- Swift passed.
- The three 1080 x 1350 SVG covers were visually reviewed without clipping or overflow.

The carousel proof task is complete. Do not reopen it without new visual evidence.

## Active cycle

Target: PR #38 / Issue #28.

Goal: complete the smallest local-only bridge from the existing synthetic `ScenarioRunner` to a deterministic, machine-readable and human-readable metadata report.

Current intended scope:

- `ios/Sources/AgentCore/SyntheticScenarioCatalog.swift`
- `ios/Sources/AgentCore/ScenarioReport.swift`
- `ios/Sources/AgentCore/ScenarioRunner.swift`
- `ios/Tests/AgentCoreTests/ScenarioReportTests.swift`
- `PROJECT_STATE.md`
- `docs/CHATGPT_NEXT_TASK.md`

## Next task

Gate and progress PR #38 at its current head:

1. Re-read PR #38 metadata, changed files, patch, comments and review threads.
2. Read all GitHub Actions results for the current head.
3. If a check fails, inspect the exact failed step and logs before changing code.
4. Fix only the smallest source-backed problem within Issue #28 scope.
5. Confirm that the report remains deterministic and metadata-only.
6. Confirm that no synthetic task text, real user content or private data appears in report output.
7. Mark ready only when current-head validation and review gates are clean.
8. Merge only with a stable expected head SHA and no unresolved review thread.

Required validation:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

## After PR #38

Select Issue #27 as the next independent product slice:

- minimal SwiftUI diagnostic screen,
- metadata-only state,
- synthetic inputs,
- no networking, persistence, providers, App Intents or real actions.

Do not open the Issue #27 implementation PR while PR #38 remains active.

## Guardrails

- No networking or external providers.
- No persistence of private data.
- No model calls or model weights.
- No App Intents or real tool execution.
- No signing files, secrets or `.env` files.
- No broad architecture rewrite.
- Preserve all unrelated safety tests.
- Do not claim validation success without a specific GitHub Actions run, local run or user-provided execution record.
- Do not create duplicate validation comments or parallel PRs.

## Expected terminal result

One of:

- `FIX_NEEDED`
- `READY_MARKED`
- `MERGED`
- `PATCH_READY`
- `NEXT_UNBLOCKED_TASK_SELECTED`
- `BEN` only for a genuinely human-only decision
