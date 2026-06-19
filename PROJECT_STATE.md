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
- Current phase: Phase 2 diagnostic shell readiness
- Current MVP direction: local-only diagnostic app with synthetic dry-runs, metadata-only reports and a tested SwiftUI diagnostic surface

## Recent completed work

- PR #31 `Issue #18: add ApprovalReceipt metadata` was squash-merged into `main` as `c4e8bb137201382e73b86b81a69a465db87cc559`.
- PR #36 `Issue #34: add test coverage preservation gate` was squash-merged into `main` as `02aec38c2627ab5c299c94e5376c198c65821852`.
- PR #37 `Add carousel proof covers for social pillars` was squash-merged into `main` as `1b6304b49fd5b0cccfc51ff4efff2eb91d3510ac`.
- PR #38 `Issue #28: add deterministic synthetic scenario report` was squash-merged into `main` as `b124da205462ce253906fa51e2080a67ee52ba5f` after all required public checks passed.
- PR #39 `Issue #27: add minimal SwiftUI diagnostic screen` was squash-merged into `main` as `f4110e1dccaadd38695ff0e798cbe6c403afff7f` after all required public checks, Swift tests and Swift build passed.
- PR #40 `Guard SwiftUI and validate the package on Linux` was squash-merged into `main` as `1f13a0c3bf7d4d9625a9adb2a52a62a06e00c1c6` after macOS, Linux, workflow, documentation, scope and repository checks passed.
- PR #41 `Sync project state after PR #40` was squash-merged into `main` as `adb8b61c87e3207be2e33da917db2336d9aa4d54`.
- Issue #11 was verified against the deterministic `ScenarioReport` implementation and closed as completed.
- Issue #7 was verified against the real-device checklist, issue template and report template and closed as completed.
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
- Tests for AgentCore behavior and diagnostic view-state privacy/mapping
- macOS and Linux Swift package build/test evidence
- Device-test issue template, real-device checklist and validation report template

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
- No model weights, credentials, signing files or real private data should be committed.

## Current validation status

Required repository validation remains:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

- Phase 0 acceptance evidence is recorded and Issue #1 is closed.
- PR #40 received green current-head evidence for PR scope, PR quality, docs consistency, repo audit, Workflow Lint, Phase 0 validation, macOS Swift tests/build and Linux Swift tests/build before merge.
- The Swift package and SwiftUI library compile and test successfully in public GitHub Actions on Apple and Linux runners.
- This is not evidence of an installed or launched physical iPhone app.

## Current autonomous mode

The limited four-role iGentic burst completed its safe autonomous targets before the scheduled 11:00 start and is now paused.

Completed autonomously:

1. merged PR #41 to synchronize project truth,
2. verified and closed Issue #11,
3. verified and closed Issue #7,
4. preserved Issue #29 for real physical-device evidence,
5. stopped all four scheduled burst roles at the owner boundary.

All prior Pokekartenkiste, support and research slot systems remain disabled.

## Current active boundary

Real-device validation is **pending**.

Prepared autonomously:

- repeatable device-test checklist,
- report template separating observations, automated evidence and assumptions,
- build/install/launch/Diagnostic UI checks,
- synthetic scenario expectations,
- privacy, network and qualitative-performance boundaries.

Still required before a physical iPhone run:

- an installable Xcode iOS app target that presents `DiagnosticView`,
- a unique bundle identifier,
- local Apple Developer Team and signing selection,
- a connected physical test iPhone,
- direct observation of build, installation, launch and UI behavior.

The current `iGenticApp` product is a Swift package library, not yet an installable iOS application. No device-readiness or performance claim may be made from package CI alone.

## Next sequence

1. Configure the minimal GitHub repository protection settings with the owner.
2. Decide together whether the next code slice should add an installable Xcode app wrapper.
3. If approved, implement the wrapper as a separate narrow PR without networking, persistence, providers, App Intents or real actions.
4. Configure signing locally in Xcode without committing account or provisioning material.
5. Run the physical-device checklist and complete the validation report under Issue #29.

## What still needs owner UI setup

- Configure a `main` ruleset or branch protection.
- Require pull requests and selected status checks before merge.
- Require conversation resolution.
- Disable force pushes and branch deletion on `main`.
- Choose allowed merge methods; squash-only is the current recommendation.
- Later, select Apple signing and a physical test device locally when an installable app target exists.

## Important constraint

Repository bootstrapping should continue as small direct branches and narrow pull requests. ZIP snapshots are fallback evidence only, not the normal implementation path.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.

## Review owner

ChatGPT reviews changes against scope, privacy impact, current GitHub evidence and validation results.
