# Project State

Last updated: 2026-06-19

## Current status

`iGentic iPhone` is an open-source, privacy-first iPhone AI Runtime Layer research repository.

The repository is controlled directly through GitHub. ChatGPT works through the GitHub Connector on small, reviewable changes, while GitHub Actions provides independent validation evidence. Codex remains paused except for later narrow Draft-PR handoffs.

## Current baseline

- Repository: `pokekarten/igentic-iphone`
- Visibility: public
- Controller: ChatGPT via GitHub Connector
- Validation environment: public GitHub Actions
- Primary target device: iPhone Air as trust/control plane
- Master brand: `iGentic`
- Community model: GitHub-first, social-supported
- Current phase: Phase 2 diagnostic shell bootstrap
- Current MVP direction: local-only diagnostic app with synthetic dry-runs, metadata-only reports and a minimal SwiftUI surface

## Recent completed work

- PR #31 `Issue #18: add ApprovalReceipt metadata` was squash-merged into `main` as `c4e8bb137201382e73b86b81a69a465db87cc559`.
- PR #36 `Issue #34: add test coverage preservation gate` was squash-merged into `main` as `02aec38c2627ab5c299c94e5376c198c65821852`.
- PR #37 `Add carousel proof covers for social pillars` was squash-merged into `main` as `1b6304b49fd5b0cccfc51ff4efff2eb91d3510ac`.
- PR #38 `Issue #28: add deterministic synthetic scenario report` was squash-merged into `main` as `b124da205462ce253906fa51e2080a67ee52ba5f` after all required public checks passed.
- `SyntheticScenarioCatalog` now provides stable local dry-run scenarios.
- `ScenarioReport` exposes structured and human-readable policy, approval and delegation metadata without task text.
- The v3 profile, symbol, lockup and carousel system remain the current public identity direction.

## What exists now

- README, roadmap, governance, contribution, support, security and conduct docs
- Phase 0 source verification, Apple API, local runtime, model strategy, validation and workflow docs
- Brand and community docs plus accessible SVG identity and social assets
- Public identity sources: `docs/brand/BRAND.md`, `docs/brand/BRAND_ASSET_MANIFEST.md`, `assets/social/instagram-profile-v3.svg`, `docs/community/COMMUNITY_STRATEGY.md`
- GitHub control, workflow lint, PR quality, repo audit, docs consistency and validation workflows
- Swift Package under `ios/`
- `PolicyEngine`, `TaskRouter`, `AuditLog`, `AgentKernel`, `ApprovalManager`, `ApprovalReceipt`, `ToolRegistry`, `DelegationBroker`, `MemoryStore`, `SensitiveDataDetector`, `RiskScorer`, `ScenarioRunner`, `SyntheticScenarioCatalog`, `ScenarioReport`
- Tests for policy, audit log, approval-gated routing, approval receipt metadata, tool registry behavior, memory-store scope behavior, sensitive-data detection, risk scoring, delegation decisions and synthetic scenario reporting
- Repo validation requiring core safety files, contributor docs, critical workflows and accessible SVG metadata

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
- No model weights, credentials, signing files or real private data should be committed.

## Current validation status

Required validation remains:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

- Phase 0 acceptance evidence is recorded and Issue #1 is closed.
- PR #38 received green current-head evidence for PR scope, PR quality, docs consistency, repo audit, Phase 0 validation, Swift tests and Swift build before merge.
- Future runtime or UI changes require current PR-head validation through GitHub Actions or equivalent specific execution evidence.
- Documentation-only work must not claim Swift validation unless a concrete run exists.

## Current active task

PR #39 implements Issue #27 as the current single runtime/UI candidate:

- add a separate `iGenticApp` Swift package target,
- map the metadata-only `ScenarioReport` into a deterministic `DiagnosticViewState`,
- render a minimal SwiftUI diagnostics screen,
- ensure visible state excludes synthetic task text,
- validate on the public macOS Swift runner before ready or merge consideration.

No parallel runtime or UI PR should be opened while PR #39 remains active.

## Next sequence

1. Review and validate PR #39 at its current head.
2. Fix only source-backed failures within the Issue #27 scope.
3. Mark ready and merge only when scope, tests, build and review gates are clean.
4. After Issue #27 completes, prepare Issue #29's real-device validation report and exact device checklist.
5. Treat installation, launch, visual confirmation and device performance as human-device evidence, not connector evidence.

## What still needs owner UI setup

- Configure `main` branch protection or a ruleset in GitHub UI.
- Require pull requests and the selected status checks before merge.
- Disable force pushes and branch deletion on `main`.
- Add repository topics and optional social preview after the public identity is locked.
- Later, configure Apple signing and a physical-device run only when an actual iOS app wrapper exists.

## Important constraint

Repository bootstrapping should continue as small direct branches and narrow pull requests. ZIP snapshots are fallback evidence only, not the normal implementation path.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.

## Review owner

ChatGPT reviews changes against scope, privacy impact, current GitHub evidence and validation results.
