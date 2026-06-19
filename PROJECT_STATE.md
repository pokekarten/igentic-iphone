# Project State

Last updated: 2026-06-19

## Current status

`iGentic iPhone` is an open-source, privacy-first iPhone AI Runtime Layer research repository.

ChatGPT works through the GitHub Connector on small, reviewable branches and pull requests. GitHub Actions provides independent validation evidence. Codex and all recurring slot automations remain paused.

## Current baseline

- Repository: `pokekarten/igentic-iphone`
- Visibility: public
- Controller: ChatGPT via GitHub Connector
- Validation environment: public GitHub Actions on macOS and Linux
- Primary target device: iPhone Air as trust/control plane
- Master brand: `iGentic`
- Community model: GitHub-first, social-supported
- Current phase: Phase 2 diagnostic shell and metadata-only safety visibility
- Current MVP direction: local-only diagnostics app with synthetic dry-runs, metadata-only reports, tested SwiftUI UI, an installable Xcode app wrapper and automated simulator runtime smoke evidence

## Recently completed

- PR #43 added the minimal installable iOS diagnostics app wrapper.
- PR #45 added automated simulator install, launch, screenshot, terminate and relaunch evidence.
- PR #46 completed the six-scenario synthetic safety matrix and restricted-data delegation blocking.
- PR #47 `Add metadata-only DiagnosticSnapshot` was squash-merged into `main` as `ba351e8b3206108a14d5dae5849287b657a09e54`.
- Issues #16, #10, #11 and #7 are closed with source-backed evidence.
- Issue #29 remains open for physical-device validation.

## What exists on `main`

- README, roadmap, governance, contribution, support, security and conduct docs
- Phase 0 source verification, Apple API, local runtime, model strategy, validation and workflow docs
- Brand and community docs plus accessible SVG identity and social assets
- Public identity sources: `docs/brand/BRAND.md`, `docs/brand/BRAND_ASSET_MANIFEST.md`, `assets/social/instagram-profile-v3.svg`, `docs/community/COMMUNITY_STRATEGY.md`
- GitHub control, workflow lint, PR quality, repo audit, docs consistency and validation workflows
- Swift Package under `ios/`
- `AgentCore` policy, approval, audit, routing, risk, memory, delegation and synthetic diagnostic components
- `ApprovalManager` and metadata-only `ApprovalReceipt`
- metadata-only `DiagnosticSnapshot` with typed summaries and deterministic output
- `SensitiveDataDetector`, `RiskScorer`, `ScenarioRunner`, `SyntheticScenarioCatalog` and metadata-only `ScenarioReport`
- complete six-scenario synthetic safety matrix with restricted-data delegation blocking
- `iGenticApp` SwiftUI library with `DiagnosticView` and `DiagnosticViewState`
- Xcode iOS application project under `app/iGenticDiagnostics`
- shared Xcode scheme and local package dependency
- dedicated unsigned iOS Simulator build and runtime smoke workflow
- device-test issue template, real-device checklist and validation report template

## Current safety posture

- Privacy and policy are implemented before app actions.
- `AuditLog` is lock-protected.
- Approval handling is a first-class gate before tool routing.
- Approval receipts, diagnostic snapshots and reports remain metadata-only.
- Restricted sensitive data is blocked before automatic external delegation.
- Tool registration is metadata-only; no real tool execution exists yet.
- `MemoryStore` is volatile in-memory storage only.
- `SensitiveDataDetector` reports categories without retaining raw matches.
- `ScenarioRunner` uses synthetic dry-run scenarios only.
- `DiagnosticViewState` excludes raw synthetic task sentences.
- The app wrapper adds no networking, provider, persistence, App Intent or real-action capability.
- No model weights, credentials, signing files or real private data should be committed.

## Current active candidate

PR #48 `Add typed PolicyDecision reason codes` is the single active candidate for Issue #13.

The candidate adds:

- stable typed `PolicyDecisionReason` metadata,
- explicit codes for local-only and restricted-data blocking,
- explicit codes for low-risk allow, data approval, action approval and combined approval,
- source-compatible `.unspecified` metadata for direct manual construction,
- focused tests for six engine paths and the compatibility default.

Existing free-text reasons remain available. Existing `isAllowed` and `requiresApproval` behavior must remain unchanged.

The candidate must not add runtime execution, app actions, networking, external providers, model calls, persistence, secrets, real private data, signing or hardware behavior.

## Current validation contract

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

Before PR #48 can merge:

- base must remain `main`,
- head SHA must remain stable during the final gate,
- changed files must match the declared four-file scope,
- PR Change Scope, Pull Request Quality, Docs Consistency, Repo Audit and Workflow Lint must pass,
- macOS and Linux Swift package build/tests must pass,
- existing allow/block/approval outcomes must remain unchanged,
- no unresolved review thread or source-backed blocker may remain.

## Evidence boundary

A successful PR #48 may prove that policy outcomes expose stable typed reason metadata without depending only on free-text explanations.

It cannot prove:

- Apple signing or provisioning,
- physical-device installation or launch,
- device-specific UI behavior,
- accessibility quality,
- battery, thermal or performance behavior,
- production readiness.

The committed app wrapper still uses `org.example.iGenticDiagnostics` as a non-production placeholder bundle identifier.

## Remaining owner-local boundary

- configure a `main` ruleset or branch protection,
- choose repository merge settings,
- replace the placeholder bundle identifier locally,
- select the Apple Developer Team,
- configure signing and provisioning,
- connect and select a physical test iPhone,
- execute `docs/device-test-checklist.md`,
- complete `docs/reports/iphone-air-validation-template.md`,
- attach sanitized physical-device evidence to Issue #29.

Signing material, account identifiers, certificates, provisioning profiles and device identifiers must not be committed.

## Next sequence

1. Gate PR #48 against scope, validation and review evidence.
2. Fix only exact source-backed failures within the declared scope.
3. Mark ready and merge only with a stable head and no unresolved review thread.
4. Close Issue #13 only after current-source acceptance evidence is complete.
5. Keep Issue #29 open.
6. Select at most one additional deterministic or simulator-verifiable safety slice.

## Important constraint

Repository work must continue through small branches and narrow pull requests. ZIP snapshots are fallback evidence only, not the normal implementation path.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.

## Review owner

ChatGPT reviews changes against scope, privacy impact, current GitHub evidence and validation results.
