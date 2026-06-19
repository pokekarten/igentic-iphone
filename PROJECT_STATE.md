# Project State

Last updated: 2026-06-19

## Current status

`iGentic iPhone` is an open-source, privacy-first iPhone AI Runtime Layer research repository.

The repository is controlled directly through GitHub. ChatGPT works through the GitHub Connector on small, reviewable changes, while GitHub Actions provides independent validation evidence. Codex remains paused except for later narrow Draft-PR handoffs.

## Current baseline

- Repository: `pokekarten/igentic-iphone`
- Visibility: public
- Controller: ChatGPT via GitHub Connector
- Validation environment: public GitHub Actions on macOS and Linux
- Primary target device: iPhone Air as trust/control plane
- Master brand: `iGentic`
- Community model: GitHub-first, social-supported
- Current phase: Phase 2 diagnostic shell ready for local device execution
- Current MVP direction: local-only diagnostics app with synthetic dry-runs, metadata-only reports, tested SwiftUI UI and a validated Xcode app wrapper

## Recent completed work

- PR #38 added the deterministic synthetic `ScenarioReport`.
- PR #39 added the minimal SwiftUI `DiagnosticView` and view-state tests.
- PR #40 added cross-platform SwiftUI guarding and Linux package validation.
- PR #41 and PR #42 synchronized project truth and closed completed cleanup work.
- PR #43 `Add minimal installable iOS diagnostics app wrapper` was squash-merged into `main` as `c2554d26a0a80cf0e19dafc5355ff1b4abd0d1d0` after all applicable checks passed.
- Issue #11 and Issue #7 are closed as completed.
- Issue #29 remains open for actual physical-device validation.

## What exists now

- README, roadmap, governance, contribution, support, security and conduct docs
- Phase 0 source verification, Apple API, local runtime, model strategy, validation and workflow docs
- Brand and community docs plus accessible SVG identity and social assets
- Public identity sources: `docs/brand/BRAND.md`, `docs/brand/BRAND_ASSET_MANIFEST.md`, `assets/social/instagram-profile-v3.svg`, `docs/community/COMMUNITY_STRATEGY.md`
- GitHub control, workflow lint, PR quality, repo audit, docs consistency and validation workflows
- Swift Package under `ios/`
- `AgentCore` library with policy, approval, audit, routing, risk, memory, delegation and synthetic diagnostic components
- `iGenticApp` SwiftUI library with `DiagnosticView` and `DiagnosticViewState`
- `SyntheticScenarioCatalog` and deterministic metadata-only `ScenarioReport`
- macOS and Linux Swift package build/test evidence
- Xcode iOS application project under `app/iGenticDiagnostics`
- `@main` application entry point presenting `DiagnosticView`
- shared Xcode scheme and local package dependency
- dedicated unsigned iOS Simulator build workflow
- device-test issue template, real-device checklist and validation report template

## Current safety posture

- Privacy and policy are implemented before app actions.
- `AuditLog` is lock-protected.
- Approval handling is a first-class gate before tool routing.
- Approval receipts and diagnostic outputs remain metadata-only.
- Tool registration is metadata-only; no real tool execution exists yet.
- `DelegationBroker` requires approval for external or critical decisions.
- `MemoryStore` is volatile in-memory storage only; it has no persistence, networking or model calls.
- `SensitiveDataDetector` emits categories and reasons only; it does not retain raw sensitive matches.
- `RiskScorer` is deterministic and local.
- `ScenarioRunner` uses synthetic dry-run scenarios only.
- `DiagnosticViewState` excludes raw synthetic task sentences.
- SwiftUI-only code is platform-guarded so non-Apple package validation remains possible.
- The Xcode app wrapper adds no networking, provider, persistence, App Intent or real-action capability.
- No model weights, credentials, signing files or real private data should be committed.

## Current validation status

Required repository validation remains:

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

PR #43 received green current-head evidence for PR scope, PR quality, docs consistency, repo audit, Workflow Lint, Phase 0 validation, Swift package validation and the unsigned simulator app build before merge.

This proves package and simulator buildability. It is not evidence of physical-device signing, installation, launch behavior or performance.

## Current autonomous mode

All recurring slot automations remain paused.

Repository-side autonomous implementation is complete for the current diagnostic MVP boundary. No parallel runtime or integration PR should be opened without new owner direction.

## Current active boundary

The committed app wrapper uses `org.example.iGenticDiagnostics` as a non-production placeholder bundle identifier.

Still required locally:

- replace the placeholder bundle identifier,
- select the Apple Developer Team,
- configure automatic signing and provisioning,
- connect and select a physical test iPhone,
- build, install, launch and relaunch the app,
- execute `docs/device-test-checklist.md`,
- complete `docs/reports/iphone-air-validation-template.md`,
- attach sanitized evidence to Issue #29.

Signing material, account identifiers, certificates, provisioning profiles and device identifiers must not be committed.

## Next sequence

1. Configure the minimal GitHub repository protection settings with the owner.
2. Open the committed Xcode project locally.
3. Set the production bundle identifier and Apple Developer Team locally.
4. Run the physical-device checklist.
5. Complete Issue #29 with direct observations and sanitized evidence.

## What still needs owner UI setup

- Configure a `main` ruleset or branch protection.
- Require pull requests and selected status checks before merge.
- Require conversation resolution.
- Disable force pushes and branch deletion on `main`.
- Choose allowed merge methods; squash-only is the current recommendation.
- Select Apple signing and a physical test device locally.

## Important constraint

Repository bootstrapping should continue as small direct branches and narrow pull requests. ZIP snapshots are fallback evidence only, not the normal implementation path.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.

## Review owner

ChatGPT reviews changes against scope, privacy impact, current GitHub evidence and validation results.
