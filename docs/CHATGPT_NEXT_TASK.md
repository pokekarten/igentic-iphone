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

PR #38 `Issue #28: add deterministic synthetic scenario report` was squash-merged into `main` as `b124da205462ce253906fa51e2080a67ee52ba5f`.

Before merge:

- PR Change Scope passed.
- Pull Request Quality passed.
- Docs Consistency passed.
- Repo Audit passed.
- Phase 0 CI Validation passed.
- Swift tests and Swift build passed.
- No unresolved review threads remained.

Issue #28 is complete. Do not reopen its scope unless a future diagnostic regression is source-backed.

## Active cycle

Target: PR #39 / Issue #27.

Goal: expose the existing metadata-only `ScenarioReport` through the smallest separate SwiftUI diagnostic target without adding an app action path.

Current intended scope:

- `ios/Package.swift`
- `ios/Sources/iGenticApp/DiagnosticView.swift`
- `ios/Sources/iGenticApp/DiagnosticViewState.swift`
- `ios/Tests/iGenticAppTests/DiagnosticViewStateTests.swift`
- `PROJECT_STATE.md`
- `docs/CHATGPT_NEXT_TASK.md`

## Next task

Gate and progress PR #39 at its current head:

1. Re-read PR #39 metadata, changed files, patch, comments and review threads.
2. Read all GitHub Actions results for the current head.
3. Confirm the new `iGenticApp` target compiles on the macOS Swift runner.
4. Confirm the view state contains structured scenario metadata and excludes synthetic task text.
5. Fix only the smallest source-backed failure within Issue #27 scope.
6. Mark ready only when current-head validation and review gates are clean.
7. Merge only with a stable expected head SHA and no unresolved review thread.

Required validation:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

## After PR #39

Issue #29 is the next phase, but it contains a genuine human-device boundary.

Autonomous preparation may include:

- a synthetic device-test report template,
- exact build/launch/diagnostic-screen steps,
- evidence fields separating observation from assumption,
- privacy and no-network checks.

Do not claim real iPhone installation, launch or performance evidence without an actual device run.

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
