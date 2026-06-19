# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-19

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, head SHA, changed files, checks, review threads and issue scope.

## Current operating mode

Mode: `IGENTIC_VALIDATION_REPAIR`.

- iGentic is the active repository lane.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions are the primary repository validation environment.
- Use one active implementation PR at a time.
- Scheduled iGentic cycle automations remain paused while this explicit repair PR is gated.
- Codex remains paused for implementation; post-merge review evidence may identify source-backed regressions.

## Recently completed

PR #39 `Issue #27: add minimal SwiftUI diagnostic screen` was squash-merged into `main` as `f4110e1dccaadd38695ff0e798cbe6c403afff7f` after its current-head macOS Swift tests and build passed.

A later automated review identified a cross-platform validation gap: `DiagnosticView.swift` imported SwiftUI unconditionally, so the documented Swift package validation could fail on non-Apple toolchains.

## Active cycle

Target: PR #40, a narrow validation repair.

Goal:

- guard the SwiftUI-only view with `canImport(SwiftUI)`,
- preserve cross-platform `DiagnosticViewState` tests,
- add explicit Linux Swift package build/test evidence,
- fix the docs path checker so shell commands are not misclassified as repository paths.

Current intended scope:

- `ios/Sources/iGenticApp/DiagnosticView.swift`
- `.github/workflows/ci-phase-0-validation.yml`
- `.github/workflows/docs-consistency.yml`
- `docs/CHATGPT_NEXT_TASK.md`

## Next task

Gate PR #40 at its latest head:

1. Require repository structure validation.
2. Require Workflow Lint.
3. Require macOS Swift build and tests.
4. Require Linux Swift build and tests.
5. Require Docs Consistency, PR Change Scope, PR Quality and Repo Audit.
6. Inspect exact failed steps before changing any file.
7. Mark ready and merge only with a stable head and no unresolved review thread.

Required validation commands represented by CI:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

## After PR #40

- Close only clearly completed duplicate/backlog issues such as the device-test checklist and ScenarioReport tasks when current source satisfies their acceptance criteria.
- Keep Issue #29 open for the physical-device boundary.
- Return to the short owner-settings session for repository rules and the installable app-wrapper decision.
- Do not begin signing, bundle configuration or a physical-device claim autonomously.

## Guardrails

- No networking or external providers.
- No persistence of private data.
- No model calls or model weights.
- No App Intents or real tool execution.
- No signing files, credentials, secrets or `.env` files.
- No broad architecture rewrite.
- Preserve unrelated safety tests.
- Never present macOS or Linux package CI as physical-device evidence.

## Expected terminal result

One of:

- `FIX_NEEDED`
- `WAITING_RUNNER`
- `READY_MARKED`
- `MERGED`
- `BEN` only for the explicit owner/signing/device boundary
