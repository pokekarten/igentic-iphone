# Project State

Last updated: 2026-06-20

## Current status

`iGentic iPhone` is an open-source, privacy-first iPhone AI Runtime Layer research repository.

ChatGPT works through the GitHub Connector on small, reviewable branches and pull requests. GitHub Actions provides independent validation evidence. The continuous ten-slot cycle is active; iGentic work is handled by Slots 00, 06, 12, 18 and 24 before the Pokekartenkiste half-hour begins.

## Current baseline

- Repository: `pokekarten/igentic-iphone`
- Visibility: public
- Controller: ChatGPT via GitHub Connector
- Validation environment: public GitHub Actions on macOS and Linux
- Primary target device: iPhone Air as trust/control plane
- Master brand: `iGentic`
- Community model: GitHub-first, social-supported
- Current phase: Phase 2 diagnostic shell and safety visibility
- Current MVP direction: local-only diagnostics app with synthetic dry-runs, privacy-aware reports, tested SwiftUI UI, an installable Xcode app wrapper and automated simulator runtime smoke evidence

## Canonical brand and community sources

- `docs/brand/BRAND.md`
- `docs/brand/BRAND_ASSET_MANIFEST.md`
- `assets/social/instagram-profile-v3.svg`
- `docs/community/COMMUNITY_STRATEGY.md`

These pointers are repository structure markers and do not imply Apple endorsement or production readiness.

## Recently completed

- PR #48 added typed `PolicyDecisionReason` metadata.
- PR #50 added lock-protected AuditLog metadata query helpers.
- PR #51 `Add ToolRegistry contract validation` was squash-merged into `main` as `8730b302ef2a30175d4bd6d330ef15d741e29964`.
- PR #52 `Add metadata-only RuntimeBudget model` was merged into `main` as `6ff0c6875cb58560b0a98c4d23dbee91e538319b`.
- PR #55 `Issue #2: add contributor glossary` was squash-merged into `main` as `cbb1ecf8e10b0c8bb7ecd509aba2c35f1670e16f`.
- PR #56 `Clarify current AuditLog privacy behavior` was squash-merged into `main` as `421524c0709de166e0ab1e75ceb8585e3c98e1ef`.
- PR #57 was closed without merge because it was parallel process work and must not displace the product target.
- Issues #16, #15, #14, #13, #12, #10, #11 and #7 are closed with source-backed evidence.
- Issue #29 remains open for physical-device validation.

## What exists on `main`

- README, roadmap, governance, contribution, support, security, conduct and glossary docs
- Phase 0 source verification, Apple API, local runtime, model strategy, validation and workflow docs
- Brand and community docs plus accessible SVG identity and social assets
- GitHub control, workflow lint, PR quality, repo audit, docs consistency and validation workflows
- Swift Package under `ios/`
- `AgentCore` policy, approval, audit, routing, risk, memory, delegation and synthetic diagnostic components
- typed policy reason metadata without loosening policy outcomes
- lock-protected AuditLog storage plus metadata projections, filters and counts
- validated metadata-only ToolRegistry definitions with deterministic invalid/duplicate handling
- metadata-only RuntimeBudget planning classes and deterministic diagnostic metadata
- metadata-only `ApprovalReceipt`, `DiagnosticSnapshot`, `ScenarioReport` and diagnostic view state
- complete six-scenario synthetic safety matrix with restricted-data delegation blocking
- `iGenticApp` SwiftUI library and installable Xcode diagnostics wrapper
- dedicated unsigned iOS Simulator build and runtime smoke workflow
- device-test issue template, checklist and validation report template

## Current safety posture

- Privacy and policy are implemented before app actions.
- `AuditLog` reads and writes remain lock-protected.
- On current `main`, the full `AuditEvent` is not metadata-only: it contains a message, and task-received events still record `task.userText` until PR #60 is merged.
- `AuditEventMetadata` projections and diagnostic snapshots exclude raw messages and identifiers.
- Approval handling is a first-class gate before tool routing.
- Approval receipts, diagnostic snapshots and reports remain metadata-only.
- Policy decisions expose stable typed reason codes while preserving existing explanations.
- Restricted sensitive data is blocked before automatic external delegation.
- Tool registration validates metadata deterministically; no real tool execution exists yet.
- RuntimeBudget describes planning assumptions only; it does not probe hardware or measure performance.
- `MemoryStore` is volatile in-memory storage only.
- The app wrapper adds no networking, provider, persistence, App Intent or real-action capability.
- No model weights, credentials, signing files or real private data should be committed.

## Current active candidate

Draft PR #60 `Issue #59: redact raw task text from AuditLog` is the only active implementation candidate.

- Scope: `ios/Sources/AgentCore/AgentKernel.swift` and `ios/Tests/AgentCoreTests/AuditPrivacyTests.swift` only.
- It replaces the task-received raw-text audit message with a fixed metadata-safe message.
- It preserves event type, sensitivity metadata and all policy, approval and routing outcomes.
- Current head at creation: `8b5e3576c78206ac18e6bb0dab6dc252eda7efe9`.
- It remains Draft until current-head repository validation, Swift tests/build, PR quality and review gates pass.
- No parallel implementation slice should be selected while PR #60 remains open.

## Current validation contract

For PR #60, final merge requires:

- base remains `main`,
- head SHA remains stable,
- changed files remain exactly the two scoped Swift files,
- required current-head workflows pass,
- no unresolved review thread or source-backed blocker remains,
- Ready transition is followed by a fresh review/thread re-check before merge.

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

## Evidence boundary

The current repository proves deterministic metadata models, policy and diagnostic behavior under repository and simulator validation.

It does not prove actual iPhone capacity, memory use, performance, model compatibility, signing, physical-device behavior or production readiness.

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

1. Validate and review PR #60 on its current head.
2. Apply only an exact source-backed fix if a current-head check fails.
3. Mark PR #60 Ready only when the full gate passes, then re-check the same head.
4. Merge PR #60 only with stable head and clean evidence.
5. Keep Issue #29 open as an owner/device boundary.
6. Then select exactly one smallest safe deterministic or simulator-verifiable product slice.

## Important constraint

Repository work must continue through small branches and narrow pull requests. ZIP snapshots are fallback evidence only, not the normal implementation path.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.

## Review owner

ChatGPT reviews changes against scope, privacy impact, current GitHub evidence and validation results.
