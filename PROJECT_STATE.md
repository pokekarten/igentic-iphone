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

- PR #47 added metadata-only `DiagnosticSnapshot`.
- PR #48 added typed `PolicyDecisionReason` metadata.
- PR #50 `Add metadata-only AuditLog query helpers` was squash-merged into `main` as `94f20aea5bd739339586af9ff9a0d66aab162e29`.
- Issues #16, #13, #12, #10, #11 and #7 are closed with source-backed evidence.
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
- Tool registration is metadata-only; no real tool execution exists yet.
- `MemoryStore` is volatile in-memory storage only.
- The app wrapper adds no networking, provider, persistence, App Intent or real-action capability.
- No model weights, credentials, signing files or real private data should be committed.

## Current active candidate

PR #51 `Add ToolRegistry contract validation` is the single active candidate for Issue #15.

The candidate adds:

- `ToolDefinitionValidationIssue` for invalid contract metadata,
- deterministic registration results for success, invalid names and duplicate names,
- rejection of empty or whitespace-only names,
- outer-whitespace normalization for valid names and lookups,
- first-valid-definition-wins duplicate handling,
- focused tests for valid metadata, invalid names, duplicates and sorted initialization snapshots.

Required data level and action risk remain mandatory typed fields. Existing registry callers remain source-compatible through an `@discardableResult` registration API. No actual tool execution is added.

## Current validation contract

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

Before PR #51 can merge:

- base must remain `main`,
- head SHA must remain stable during the final gate,
- changed files must match the declared four-file scope,
- PR Change Scope, Pull Request Quality, Docs Consistency, Repo Audit and Workflow Lint must pass,
- macOS and Linux Swift package build/tests must pass,
- valid, invalid, duplicate and deterministic snapshot behavior must be covered,
- no unresolved review thread or source-backed blocker may remain.

## Evidence boundary

A successful PR #51 may prove that metadata-only tool definitions are validated deterministically before registration.

It does not add or validate real tool execution, App Intents, file access, networking, providers, persistence, signing, hardware behavior or production readiness.

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

1. Gate PR #51 against scope, validation and review evidence.
2. Fix only exact source-backed failures within the declared scope.
3. Mark ready and merge only with a stable head and no unresolved review thread.
4. Close Issue #15 only after current-source acceptance evidence is complete.
5. Keep Issue #29 open.
6. Select at most one additional deterministic or simulator-verifiable safety slice.

## Important constraint

Repository work must continue through small branches and narrow pull requests. ZIP snapshots are fallback evidence only, not the normal implementation path.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.

## Review owner

ChatGPT reviews changes against scope, privacy impact, current GitHub evidence and validation results.
