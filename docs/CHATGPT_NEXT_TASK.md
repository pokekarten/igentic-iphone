# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-19

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, current `main`, workflow evidence, review threads and the physical-device evidence boundary.

## Current operating mode

Mode: `IGENTIC_SIMULATOR_RELIABILITY`.

- iGentic is the only active repository context.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions remain the independent repository validation environment.
- Codex and all recurring slot automations remain paused.
- The owner explicitly requested continued progress without a local physical iPhone Air test.
- Exactly one active implementation candidate is allowed.

## Active target

PR #45 `Add automated simulator launch smoke test` is the single active candidate.

Intended scope:

- `scripts/smoke-ios-simulator.sh`
- `.github/workflows/ios-app-wrapper.yml`
- `app/iGenticDiagnostics/README.md`
- `docs/CHATGPT_NEXT_TASK.md`

`PROJECT_STATE.md` will be synchronized only after the candidate is validated and merged.

## Goal

Extend simulator evidence from build-only to runtime smoke evidence:

1. build the unsigned diagnostics app into a deterministic DerivedData path,
2. select an available iPhone simulator dynamically,
3. boot the simulator,
4. install the app,
5. launch it and require a returned process identifier,
6. capture a non-empty simulator screenshot,
7. terminate the app,
8. relaunch it cleanly,
9. shut down the simulator.

## Merge gate

Before PR #45 can merge:

- base must remain `main`,
- head SHA must remain stable during the final gate,
- changed files must match the declared scope,
- PR Change Scope, Pull Request Quality, Docs Consistency, Repo Audit and Workflow Lint must pass,
- Phase 0 CI Validation and Swift package validation must pass,
- `Build and launch diagnostic app in simulator` must pass on the current head,
- no unresolved review thread or source-backed blocker may remain.

Inspect exact workflow logs before changing the smoke script or workflow. Do not make speculative fixes while a runner is merely queued or running.

## Required repository validation

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

App-wrapper build and runtime smoke validation:

```bash
xcodebuild \
  -project app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj \
  -scheme iGenticDiagnostics \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/iGenticDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH=/tmp/iGenticDerivedData/Build/Products/Debug-iphonesimulator/iGenticDiagnostics.app \
BUNDLE_IDENTIFIER=org.example.iGenticDiagnostics \
bash scripts/smoke-ios-simulator.sh
```

## Evidence boundary

A successful simulator smoke test proves that the built app can be installed, launched, screenshotted, terminated and relaunched in an iOS Simulator.

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

- Apple account, team, certificate, provisioning-profile or device identifiers,
- committed signing configuration,
- networking, external providers or model calls,
- persistence of private data,
- App Intents or real tool execution,
- physical-device success claims without direct observation.

## Expected terminal result

One of:

- `FIX_NEEDED`
- `WAITING_RUNNER`
- `READY_MARKED`
- `MERGED`
- `OWNER_DEVICE_STEP`
