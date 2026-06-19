# Project State

Last updated: 2026-06-19

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
- Current phase: Phase 2 diagnostic shell and metadata-only safety visibility
- Current MVP direction: local-only diagnostics app with synthetic dry-runs, metadata-only reports, tested SwiftUI UI, an installable Xcode app wrapper and automated simulator runtime smoke evidence

## Recently completed

- PR #48 added typed `PolicyDecisionReason` metadata.
- PR #50 added lock-protected AuditLog metadata query helpers.
- PR #51 `Add ToolRegistry contract validation` was squash-merged into `main` as `8730b302ef2a30175d4bd6d330ef15d741e29964`.
- PR #52 `Add metadata-only RuntimeBudget model` was merged into `main` as `6ff0c6875cb58560b0a98c4d23dbee91e538319b`.
- Issues #16, #15, #13, #12, #10, #11 and #7 are closed with source-backed evidence.
- Issue #14 is implemented and awaiting final issue closure.
- Issue #29 remains open for physical-device validation.

## What exists on `main`

- README, roadmap, governance, contribution, support, security and conduct docs
- Phase 0 source verification, Apple API, local runtime, model strategy, validation and workflow docs
- Brand and community docs plus accessible SVG identity and social assets
- Public identity sources: `docs/brand/BRAND.md`, `docs/brand/BRAND_ASSET_MANIFEST.md`, `assets/social/instagram-profile-v3.svg`, `docs/community/COMMUNITY_STRATEGY.md`
- GitHub control, workflow lint, PR quality, repo audit, docs consistency and validation workflows
- Swift Package under `ios/`
- `AgentCore` policy, approval, audit, routing, risk, memory, delegation and synthetic diagnostic components
- typed policy reason metadata without loosening policy outcomes
- lock-protected AuditLog metadata snapshots, filters and counts
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
- Audit diagnostic snapshots exclude raw messages and identifiers.
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

No new implementation candidate is selected yet.

The next iGentic cycle must first verify Issue #14 closure, then select at most one small deterministic or simulator-verifiable safety slice from current open issues and repository evidence. The open Dependabot PR #49 is maintenance work and must not automatically displace the next explicit product target.

## Current validation contract

For any new Swift product slice:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

A pull request may be marked ready or merged only when:

- base remains `main`,
- head SHA is stable during the final gate,
- changed files match the declared scope,
- required current-head workflows pass,
- no unresolved review thread or source-backed blocker remains,
- the change preserves the privacy and safety boundaries below.

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

1. Verify and close Issue #14 with PR #52 acceptance evidence.
2. Keep Issue #29 open as an owner/device boundary.
3. Re-read open product issues and select exactly one smallest safe deterministic or simulator-verifiable slice.
4. Open at most one narrow Draft PR with explicit scope and validation.
5. Keep unrelated maintenance PRs outside the product target unless intentionally selected.

## Important constraint

Repository work must continue through small branches and narrow pull requests. ZIP snapshots are fallback evidence only, not the normal implementation path.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.

## Review owner

ChatGPT reviews changes against scope, privacy impact, current GitHub evidence and validation results.
