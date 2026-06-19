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

- PR #46 completed the six-scenario synthetic safety matrix and restricted-data delegation blocking.
- PR #47 added metadata-only `DiagnosticSnapshot`.
- PR #48 `Add typed PolicyDecision reason codes` was squash-merged into `main` as `4a4579bb2b099a0e5b718940ff76e3b4635e80cc`.
- Issues #16, #13, #10, #11 and #7 are closed with source-backed evidence.
- Issue #29 remains open for physical-device validation.

## What exists on `main`

- README, roadmap, governance, contribution, support, security and conduct docs
- Phase 0 source verification, Apple API, local runtime, model strategy, validation and workflow docs
- Brand and community docs plus accessible SVG identity and social assets
- Public identity sources: `docs/brand/BRAND.md`, `docs/brand/BRAND_ASSET_MANIFEST.md`, `assets/social/instagram-profile-v3.svg`, `docs/community/COMMUNITY_STRATEGY.md`
- GitHub control, workflow lint, PR quality, repo audit, docs consistency and validation workflows
- Swift Package under `ios/`
- `AgentCore` policy, approval, audit, routing, risk, memory, delegation and synthetic diagnostic components
- typed `PolicyDecisionReason` metadata without loosening policy outcomes
- metadata-only `ApprovalReceipt`, `DiagnosticSnapshot`, `ScenarioReport` and diagnostic view state
- complete six-scenario synthetic safety matrix with restricted-data delegation blocking
- `iGenticApp` SwiftUI library and installable Xcode diagnostics wrapper
- dedicated unsigned iOS Simulator build and runtime smoke workflow
- device-test issue template, checklist and validation report template

## Current safety posture

- Privacy and policy are implemented before app actions.
- `AuditLog` is lock-protected.
- Approval handling is a first-class gate before tool routing.
- Approval receipts, diagnostic snapshots and reports remain metadata-only.
- Policy decisions expose stable typed reason codes while preserving existing free-text explanations.
- Restricted sensitive data is blocked before automatic external delegation.
- Tool registration is metadata-only; no real tool execution exists yet.
- `MemoryStore` is volatile in-memory storage only.
- `SensitiveDataDetector` reports categories without retaining raw matches.
- `ScenarioRunner` uses synthetic dry-run scenarios only.
- The app wrapper adds no networking, provider, persistence, App Intent or real-action capability.
- No model weights, credentials, signing files or real private data should be committed.

## Current active candidate

PR #50 `Add metadata-only AuditLog query helpers` is the single active candidate for Issue #12.

The candidate adds:

- `AuditEventMetadata` containing only timestamp, event type and sensitivity,
- stable metadata snapshots in recording order,
- filtering and counting by event type,
- filtering and counting at or above a sensitivity level,
- one shared lock-protected read boundary,
- focused tests for metadata exclusion, ordering, filters, counts, unchanged raw-event behavior and concurrent recording.

Existing `record(_:)` and `allEvents()` behavior must remain unchanged. New diagnostic helpers must never expose raw messages or event identifiers.

The candidate must not add databases, files, persistence, networking, external providers, app actions, secrets, model calls, signing or hardware behavior.

## Current validation contract

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

Before PR #50 can merge:

- base must remain `main`,
- head SHA must remain stable during the final gate,
- changed files must match the declared four-file scope,
- PR Change Scope, Pull Request Quality, Docs Consistency, Repo Audit and Workflow Lint must pass,
- macOS and Linux Swift package build/tests must pass,
- tests must prove metadata-only output and unchanged recording behavior,
- no unresolved review thread or source-backed blocker may remain.

## Evidence boundary

A successful PR #50 may prove that lock-protected audit metadata can be queried deterministically without exposing raw audit messages or identifiers.

It cannot prove signing, physical-device behavior, accessibility, performance or production readiness.

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

1. Gate PR #50 against scope, validation and review evidence.
2. Fix only exact source-backed failures within the declared scope.
3. Mark ready and merge only with a stable head and no unresolved review thread.
4. Close Issue #12 only after current-source acceptance evidence is complete.
5. Keep Issue #29 open.
6. Select at most one additional deterministic or simulator-verifiable safety slice.

## Important constraint

Repository work must continue through small branches and narrow pull requests. ZIP snapshots are fallback evidence only, not the normal implementation path.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.

## Review owner

ChatGPT reviews changes against scope, privacy impact, current GitHub evidence and validation results.
