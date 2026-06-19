# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-19

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, head SHA, changed files, checks, review threads and issue scope.

## Current operating mode

Mode: `IGENTIC_APP_WRAPPER_VALIDATION`.

- iGentic remains the active repository context.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions remain the independent validation environment.
- Codex remains paused.
- All recurring slot automations remain paused.
- The owner authorized implementation of the smallest safe app-wrapper slice through the current chat instruction to implement what is possible.

## Active target

PR #43 `Add minimal installable iOS diagnostics app wrapper` is the single active candidate.

Intended scope:

- `app/iGenticDiagnostics/iGenticDiagnostics/iGenticDiagnosticsApp.swift`
- `app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj/project.pbxproj`
- `app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj/xcshareddata/xcschemes/iGenticDiagnostics.xcscheme`
- `app/iGenticDiagnostics/README.md`
- `.github/workflows/ios-app-wrapper.yml`
- `PROJECT_STATE.md`
- `docs/CHATGPT_NEXT_TASK.md`

## Goal

- Provide the smallest Xcode iOS application target.
- Import the existing local `iGenticApp` Swift package product.
- Present `DiagnosticView` as the application root.
- Validate an unsigned iOS Simulator build in GitHub Actions.
- Preserve the owner-only boundary for bundle identity, Apple Developer Team, signing and physical-device evidence.

## Next task

Gate PR #43 at its latest head:

1. Read current PR metadata, changed files, patch, comments and review threads.
2. Require repository structure, PR scope, PR quality, docs consistency, repo audit and workflow lint checks.
3. Require existing macOS and Linux Swift package build/test checks.
4. Require the `Build diagnostic app for simulator` check to resolve the local package and complete an unsigned simulator build.
5. Inspect exact logs before changing project or workflow files.
6. Mark ready and merge only with a stable head, green current-head evidence and no unresolved review thread.

## Required repository validation

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

Additional app-wrapper validation:

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

## Safety boundary

- `org.example.iGenticDiagnostics` is a non-production placeholder only.
- Do not add Apple account, team, certificate, provisioning-profile or device identifiers.
- Do not claim physical-device installation, launch or performance from simulator CI.
- No networking, providers, persistence, App Intents, model calls, real actions, secrets or private data.

## After PR #43

If PR #43 is validated and merged:

1. keep Issue #29 open,
2. replace the placeholder bundle identifier locally,
3. select the Apple Developer Team locally in Xcode,
4. configure signing without committing signing material,
5. run the physical-device checklist and complete the validation report.

## Expected terminal result

One of:

- `FIX_NEEDED`
- `WAITING_RUNNER`
- `READY_MARKED`
- `MERGED`
- `BEN` only for local Apple/Xcode/signing/device steps
