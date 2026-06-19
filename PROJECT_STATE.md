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
- Current phase: Phase 0 validation complete; Phase 1 safety bootstrap moving into the Phase 2 diagnostic bridge
- Current MVP direction: local-only diagnostic app with synthetic dry-runs and metadata-only reports

## Recent completed work

- PR #31 `Issue #18: add ApprovalReceipt metadata` was squash-merged into `main` as `c4e8bb137201382e73b86b81a69a465db87cc559`.
- PR #36 `Issue #34: add test coverage preservation gate` was squash-merged into `main` as `02aec38c2627ab5c299c94e5376c198c65821852`.
- PR #37 `Add carousel proof covers for social pillars` was squash-merged into `main` as `1b6304b49fd5b0cccfc51ff4efff2eb91d3510ac` after PR-scope, PR-quality, docs-consistency, repo-audit, Phase 0 and Swift checks passed.
- The three 1080 x 1350 carousel proof covers were visually reviewed without clipping or overflow.
- The v3 profile, symbol, lockup and carousel system are now the current public identity direction.
- `ApprovalReceipt` records approval status metadata without storing private raw data.
- `ApprovalManager` can create approval receipts for audit and diagnostic use.
- The test coverage preservation gate documents that narrow runtime or test PRs must not silently remove unrelated safety coverage.

## What exists now

- README, roadmap, governance, contribution, support, security and conduct docs
- Phase 0 source verification, Apple API, local runtime, model strategy, validation and workflow docs
- Brand and community docs plus accessible SVG identity and social assets
- GitHub control, workflow lint, PR quality, repo audit, docs consistency and validation workflows
- Minimal Swift Package under `ios/`
- `PolicyEngine`, `TaskRouter`, `AuditLog`, `AgentKernel`, `ApprovalManager`, `ApprovalReceipt`, `ToolRegistry`, `DelegationBroker`, `MemoryStore`, `SensitiveDataDetector`, `RiskScorer`, `ScenarioRunner`
- Smoke tests for policy, audit log, approval-gated routing, approval receipt metadata, tool registry behavior, memory-store scope behavior, sensitive-data detection, risk scoring, delegation decisions and synthetic scenario output
- Repo validation requiring core safety files, contributor docs, critical workflows and accessible SVG metadata

## Current safety posture

- Privacy and policy are implemented before app actions.
- `AuditLog` is lock-protected.
- Approval handling is a first-class gate before tool routing.
- Approval receipts and diagnostic outputs must remain metadata-only.
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
- PR #37 received green public-repository workflow evidence before merge.
- Future runtime changes require current PR-head validation through GitHub Actions or equivalent specific execution evidence.
- Documentation-only work must not claim Swift validation unless a concrete run exists.

## Current active task

PR #38 implements Issue #28 as the current single runtime candidate:

- move existing synthetic scenarios into a dedicated catalog,
- add a deterministic metadata-only `ScenarioReport`,
- expose structured and human-readable safety outcomes,
- retain the existing policy, approval and delegation gates,
- validate through public GitHub Actions before ready or merge consideration.

No parallel runtime PR should be opened while PR #38 remains active.

## Next sequence

1. Review and validate PR #38 at its current head.
2. Fix only source-backed failures within the Issue #28 scope.
3. Mark ready and merge only when scope, tests, build and review gates are clean.
4. After Issue #28 completes, select Issue #27 as the next independent slice: a minimal SwiftUI diagnostic screen using metadata-only state.
5. Keep real-device validation under Issue #29 for a later human-device phase.

## What still needs owner UI setup

- Configure `main` branch protection or a ruleset in GitHub UI.
- Require pull requests and the selected status checks before merge.
- Disable force pushes on `main`.
- Add repository topics and optional social preview after the public identity is locked.

## Important constraint

Repository bootstrapping should continue as small direct branches and narrow pull requests. ZIP snapshots are fallback evidence only, not the normal implementation path.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.

## Review owner

ChatGPT reviews changes against scope, privacy impact, current GitHub evidence and validation results.
