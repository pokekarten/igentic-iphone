# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-19

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, current `main`, workflow evidence, review threads and issue acceptance criteria.

## Current operating mode

Mode: `IGENTIC_SYNTHETIC_SAFETY_MATRIX`.

- iGentic is the only active repository context.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions remain the independent repository validation environment.
- Codex and all recurring slot automations remain paused.
- The owner requested continued progress without a local physical iPhone Air test.
- Exactly one active implementation candidate is allowed.

## Recently completed

PR #45 `Add automated simulator launch smoke test` was squash-merged into `main` as `74c913148eac7a1ed66647485ca5cad85db0123a`.

The current repository evidence now proves that the unsigned diagnostics app can be built, installed, launched, screenshotted, terminated and relaunched in an iOS Simulator. This remains simulator evidence only.

## Active target

PR #46 `Complete synthetic safety scenario catalog` is the single active candidate and implements the remaining acceptance criteria for Issue #16.

Intended scope:

- `ios/Sources/AgentCore/DelegationBroker.swift`
- `ios/Sources/AgentCore/SyntheticScenarioCatalog.swift`
- `ios/Sources/AgentCore/ScenarioRunner.swift`
- `ios/Tests/AgentCoreTests/ScenarioReportTests.swift`
- `ios/Tests/AgentCoreTests/SyntheticScenarioCatalogCompletionTests.swift`
- `PROJECT_STATE.md`
- `docs/CHATGPT_NEXT_TASK.md`

## Goal

Complete the deterministic synthetic safety matrix without changing UI, networking or device behavior:

1. preserve the existing four-scenario baseline report,
2. add `restricted-external-delegation`,
3. add `sensitive-data-detection`,
4. derive the sensitive scenario classification through `SensitiveDataDetector`,
5. block restricted sensitive data before the generic external-provider approval path,
6. run all six catalog scenarios through `ScenarioRunner`,
7. verify the complete report remains deterministic and metadata-only.

## Merge gate

Before PR #46 can merge:

- base must remain `main`,
- head SHA must remain stable during the final gate,
- changed files must match the declared scope,
- PR Change Scope, Pull Request Quality, Docs Consistency, Repo Audit and Workflow Lint must pass,
- Phase 0 CI Validation and Swift package validation must pass,
- the new complete-catalog tests must pass on macOS and Linux,
- no unresolved review thread or source-backed blocker may remain.

Inspect exact workflow logs before changing code. Do not make speculative fixes while a runner is merely queued or running.

## Required validation

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

The existing app-wrapper workflow may run when relevant paths change, but PR #46 does not change the Xcode app project or simulator smoke script.

## Evidence boundary

A successful PR #46 proves deterministic safety behavior for the complete synthetic scenario matrix and metadata-only reporting.

It does not prove:

- Apple signing or provisioning,
- physical-device installation or launch,
- device-specific UI behavior,
- accessibility quality,
- battery, thermal or performance behavior,
- production readiness.

Issue #29 remains open for physical-device evidence.

## Safety rules

Do not add:

- real user data or real app actions,
- networking, external providers or model calls,
- persistence of private data,
- App Intents or real tool execution,
- signing or device configuration,
- physical-device success claims without direct observation.

## After PR #46

If all acceptance criteria are proven and the PR is merged:

1. close Issue #16 with source-backed evidence,
2. keep Issue #29 open,
3. synchronize the project state,
4. select at most one additional simulator-verifiable or deterministic safety slice.

## Expected terminal result

One of:

- `FIX_NEEDED`
- `WAITING_RUNNER`
- `READY_MARKED`
- `MERGED`
- `ISSUE_CLOSED`
- `OWNER_DEVICE_STEP`
