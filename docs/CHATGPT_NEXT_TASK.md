# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-19

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, head SHA, changed files, checks, review threads and issue scope.

## Current operating mode

Mode: `IGENTIC_DEVICE_READINESS`.

- iGentic is the active repository lane.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions are the primary repository validation environment.
- Use one active implementation PR at a time.
- Do not open an app-wrapper PR until the owner settings and signing boundary are explicitly resolved.
- Codex remains paused unless a later task is explicitly routed as a narrow Draft-PR handoff.

## Recently completed

PR #39 `Issue #27: add minimal SwiftUI diagnostic screen` was squash-merged into `main` as `f4110e1dccaadd38695ff0e798cbe6c403afff7f`.

Before merge:

- PR Change Scope passed.
- Pull Request Quality passed.
- Docs Consistency passed.
- Repo Audit passed.
- Phase 0 CI Validation passed.
- Swift tests passed.
- Swift build passed.
- No unresolved review threads remained.

The repository now contains a tested `iGenticApp` SwiftUI library, but it does not yet contain an installable Xcode iOS app target.

## Prepared device-validation kit

Issue #29 preparation now includes:

- `docs/device-test-checklist.md`
- `docs/reports/iphone-air-validation-template.md`
- existing `.github/ISSUE_TEMPLATE/device_test_report.md`

These sources separate:

- physical-device observations,
- automated repository evidence,
- assumptions,
- unavailable prerequisites,
- explicit failures.

They do not claim that an iPhone test has run.

## Current boundary

Real-device validation remains pending because the following are not yet present or configured:

- installable Xcode iOS app target,
- bundle identifier,
- local Apple Developer Team/signing,
- physical test device run.

The Swift package CI proves buildability and tests for the package products. It does not prove installation, launch, visual behavior or performance on an iPhone.

## Next task

Prepare for one short owner-settings session before more app code:

1. Confirm the `main` ruleset and required checks.
2. Confirm squash-only merge policy and branch cleanup behavior.
3. Decide whether to create the minimal installable Xcode app wrapper now.
4. If approved, define the local bundle identifier and Apple Developer Team only in Xcode; never commit signing material.
5. Keep the initial app root limited to `DiagnosticView` with no network, persistence, providers, App Intents or real actions.

Until that decision is made:

- do not create a parallel runtime PR,
- do not claim real-device validation,
- do not add signing files,
- do not add external capabilities,
- continue only with source-backed review, issue cleanup or documentation corrections.

## Required repository validation

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

## Human-device phase after app-wrapper approval

Use:

- `docs/device-test-checklist.md`
- `docs/reports/iphone-air-validation-template.md`

Directly observe and record:

- Xcode build for the physical device,
- signing,
- installation,
- first launch and relaunch,
- Diagnostic UI content,
- synthetic scenario results,
- privacy and permission behavior,
- qualitative performance limitations.

## Guardrails

- No networking or external providers.
- No persistence of private data.
- No model calls or model weights.
- No App Intents or real tool execution.
- No signing files, credentials, secrets or `.env` files.
- No broad architecture rewrite.
- Preserve unrelated safety tests.
- Never present automated evidence as a device observation.

## Expected terminal result

One of:

- `OWNER_SETTINGS_READY`
- `APP_WRAPPER_APPROVED`
- `PATCH_READY`
- `NEXT_UNBLOCKED_TASK_SELECTED`
- `BEN` only for the explicit owner/signing/device boundary
