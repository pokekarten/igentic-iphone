# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-19

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, current `main`, open issues and the physical-device evidence boundary.

## Current operating mode

Mode: `IGENTIC_DEVICE_RUN_READY`.

- iGentic remains the active repository context.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions remain the independent repository validation environment.
- Codex remains paused.
- All recurring slot automations remain paused.
- No speculative runtime or integration work should start while the next step requires local Apple/Xcode/device access.

## Recently completed

PR #43 `Add minimal installable iOS diagnostics app wrapper` was squash-merged into `main` as `c2554d26a0a80cf0e19dafc5355ff1b4abd0d1d0`.

Before merge:

- PR Change Scope passed.
- Pull Request Quality passed.
- Docs Consistency passed.
- Repo Audit passed.
- Workflow Lint passed.
- Phase 0 CI Validation passed.
- Swift package validation passed.
- `Build diagnostic app for simulator` passed.
- No unresolved review thread remained.

## Current repository state

The repository now contains:

- tested `AgentCore` and `iGenticApp` Swift package products,
- deterministic metadata-only `ScenarioReport`,
- tested SwiftUI `DiagnosticView`,
- an Xcode application project under `app/iGenticDiagnostics`,
- an `@main` iOS app entry point that presents `DiagnosticView`,
- a shared Xcode scheme,
- a successful unsigned iOS Simulator build workflow,
- a committed device-test checklist and validation report template.

The app wrapper uses `org.example.iGenticDiagnostics` as an explicit non-production placeholder bundle identifier.

## Current boundary

Repository automation has completed everything that can be proven without the owner's local Apple environment.

The remaining steps require local owner action:

1. open `app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj` in Xcode,
2. replace the placeholder bundle identifier,
3. select the Apple Developer Team,
4. configure automatic signing locally,
5. connect and select the physical test iPhone,
6. build, install, launch and relaunch the app,
7. execute `docs/device-test-checklist.md`,
8. complete `docs/reports/iphone-air-validation-template.md`,
9. attach sanitized evidence to Issue #29.

## Required repository validation

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

App-wrapper validation:

```bash
xcodebuild \
  -project app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj \
  -scheme iGenticDiagnostics \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

These checks prove package and simulator buildability only. They do not prove physical-device signing, installation, launch behavior or performance.

## Stop rules

Do not autonomously add:

- Apple account, team, certificate, provisioning-profile or device identifiers,
- committed signing configuration,
- networking, external providers or model calls,
- persistence of private data,
- App Intents or real tool execution,
- physical-device success claims without direct observation.

## Expected terminal result

Until local device evidence is supplied:

- `OWNER_DEVICE_STEP`
- `BEN` for Xcode, signing or physical-device execution
