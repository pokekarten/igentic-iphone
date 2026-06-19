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
- Current phase: Phase 2 diagnostic shell simulator reliability and deterministic safety validation
- Current MVP direction: local-only diagnostics app with synthetic dry-runs, metadata-only reports, tested SwiftUI UI, a validated Xcode app wrapper and automated simulator runtime smoke evidence

## Recent completed work

- PR #38 added the deterministic synthetic `ScenarioReport`.
- PR #39 added the minimal SwiftUI `DiagnosticView` and view-state tests.
- PR #40 added cross-platform SwiftUI guarding and Linux package validation.
- PR #41 and PR #42 synchronized project truth and closed completed cleanup work.
- PR #43 added the minimal installable iOS diagnostics app wrapper and passed unsigned simulator build validation.
- PR #44 synchronized the device-ready project state.
- PR #45 `Add automated simulator launch smoke test` was squash-merged into `main` as `74c913148eac7a1ed66647485ca5cad85db0123a` after all current-head checks passed.
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
- `ApprovalManager` and metadata-only `ApprovalReceipt` support for approval-gated audit and diagnostics
- `iGenticApp` SwiftUI library with `DiagnosticView` and `DiagnosticViewState`
- `SyntheticScenarioCatalog` and deterministic metadata-only `ScenarioReport`
- macOS and Linux Swift package build/test evidence
- Xcode iOS application project under `app/iGenticDiagnostics`
- `@main` application entry point presenting `DiagnosticView`
- shared Xcode scheme and local package dependency
- dedicated unsigned iOS Simulator build and runtime smoke workflow
- automated simulator install, launch, screenshot, terminate and relaunch evidence
- device-test issue template, real-device checklist and validation report template

## Current safety posture

- Privacy and policy are implemented before app actions.
- `AuditLog` is lock-protected.
- Approval handling is a first-class gate before tool routing.
- Approval receipts and diagnostic outputs remain metadata-only.
- Tool registration is metadata-only; no real tool execution exists yet.
- `DelegationBroker` requires approval for external or critical decisions on the current `main` baseline.
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

App-wrapper runtime smoke validation now additionally proves that the unsigned simulator app can be:

- built,
- installed,
- launched with a process identifier,
- screenshotted,
- terminated,
- relaunched cleanly.

PR #45 received green current-head evidence for PR scope, PR quality, docs consistency, repo audit, Workflow Lint, Phase 0 validation, Swift package validation and the simulator runtime smoke test before merge.

This proves package and simulator runtime behavior. It is not evidence of physical-device signing, installation, device-specific behavior or performance.

## Current active candidate

PR #46 `Complete synthetic safety scenario catalog` is the single active candidate for Issue #16.

It proposes:

- preserving the existing four-scenario baseline report,
- adding `restricted-external-delegation`,
- adding `sensitive-data-detection`,
- deriving the synthetic sensitive classification through `SensitiveDataDetector`,
- blocking restricted sensitive data before the generic external-provider approval path,
- running the complete six-scenario catalog through `ScenarioRunner`,
- verifying deterministic metadata-only complete-report output.

PR #46 remains a candidate until all current-head repository and Swift checks pass.

## Current autonomous mode

All recurring slot automations remain paused.

The owner requested continued progress without a local physical iPhone Air test. Work remains limited to exactly one deterministic or simulator-verifiable safety slice at a time. No parallel runtime, UI or integration PR should be opened while PR #46 remains active.

## Evidence boundary

A successful PR #46 may prove the complete synthetic safety matrix and restricted-data delegation behavior.

It cannot prove:

- Apple signing or provisioning,
- physical-device installation or launch,
- device-specific UI behavior,
- accessibility quality,
- battery, thermal or performance behavior,
- production readiness.

The committed app wrapper continues to use `org.example.iGenticDiagnostics` as a non-production placeholder bundle identifier.

## Remaining owner-local boundary

- replace the placeholder bundle identifier,
- select the Apple Developer Team,
- configure automatic signing and provisioning,
- connect and select a physical test iPhone,
- execute `docs/device-test-checklist.md`,
- complete `docs/reports/iphone-air-validation-template.md`,
- attach sanitized physical-device evidence to Issue #29.

Signing material, account identifiers, certificates, provisioning profiles and device identifiers must not be committed.

## Next sequence

1. Gate PR #46 against scope, workflow, macOS/Linux Swift and complete-catalog test evidence.
2. Fix only exact source-backed failures within the declared scope.
3. Mark ready and merge only with a stable head and no unresolved review thread.
4. Close Issue #16 only after current-source acceptance evidence is complete.
5. Keep Issue #29 open.
6. Select at most one additional deterministic or simulator-verifiable safety slice after PR #46 is complete.

## What still needs owner UI setup

- Configure a `main` ruleset or branch protection.
- Require pull requests and selected status checks before merge.
- Require conversation resolution.
- Disable force pushes and branch deletion on `main`.
- Choose allowed merge methods; squash-only is the current recommendation.
- Select Apple signing and a physical test device locally when physical validation resumes.

## Important constraint

Repository bootstrapping should continue as small direct branches and narrow pull requests. ZIP snapshots are fallback evidence only, not the normal implementation path.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.

## Review owner

ChatGPT reviews changes against scope, privacy impact, current GitHub evidence and validation results.
