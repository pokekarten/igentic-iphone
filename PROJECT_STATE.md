# Project State

Last updated: 2026-06-13

## Current status

`iGentic iPhone` is being initialized as an open-source, privacy-first iPhone AI Runtime Layer repository.

The repo is controlled directly through GitHub. ChatGPT works through the GitHub Connector on small, safe repository-control, documentation, process and narrow runtime-preparation changes. Runtime/code changes must stay narrow and use pull requests before merge.

## Current baseline

- Repository: `pokekarten/igentic-iphone`
- Visibility: public
- Controller: ChatGPT via GitHub Connector
- Implementation assistant: Codex can later be used for narrow Draft PRs after explicit task handoff
- Primary target device: iPhone Air as trust/control plane
- Master brand: `iGentic`
- Current research track: `iGentic iPhone`
- Community model: GitHub-first, social-supported
- Current phase: Phase 0 validation complete; Phase 1 safety bootstrap in progress; Phase 2 diagnostic-shell readiness starting with metadata-only building blocks

## Phase 0 status

Phase 0 is substantially documented and contributor-facing. Issue #1 is closed as completed because its original acceptance criteria are satisfied by recorded validation evidence.

## Recent completed work

- PR #31 `Issue #18: add ApprovalReceipt metadata` was squash-merged into `main` as `c4e8bb137201382e73b86b81a69a465db87cc559`.
- Issue #18 is closed as completed.
- `ApprovalReceipt` now records approval status metadata without storing private raw data.
- PR #32 `Issue #26: clarify validation and PR scope evidence` was squash-merged into `main` as `8cfad90d8eae909c6cc61583ce01f732e813ec97`.
- Issue #26 is closed as completed.
- PR scope, privacy, safety and validation provenance are now explicit in the PR template and validation summary.

## What exists now

- README, roadmap, governance, contribution, support, security and conduct docs
- Phase 0 source verification, Apple API, local runtime, model strategy, validation and workflow docs
- Brand/community docs and initial SVG assets, including `docs/brand/BRAND.md` and `docs/community/COMMUNITY_STRATEGY.md`
- GitHub control, workflow lint, PR quality, repo audit, docs consistency and validation workflows
- Minimal Swift Package under `ios/`
- `PolicyEngine`, `TaskRouter`, `AuditLog`, `AgentKernel`, `ApprovalManager`, `ApprovalReceipt`, `DiagnosticSnapshot`, `ToolRegistry`, `DelegationBroker`, `MemoryStore`, `SensitiveDataDetector`, `RiskScorer`, `ScenarioRunner`
- Smoke tests for policy, audit log, approval-gated routing, approval receipt metadata, diagnostic snapshot metadata, tool registry behavior, memory-store scope behavior, sensitive-data detection, risk scoring, delegation broker decisions and scenario runner output
- Repo validation script requiring core AgentCore safety files, brand/community docs, issue templates, critical workflow files and accessible SVG metadata

## Current safety posture

- Privacy and policy are implemented before app actions.
- `AuditLog` is lock-protected.
- Approval handling is a first-class gate before tool routing.
- Approval receipts are metadata-only and must not store private raw input.
- Diagnostic snapshots are metadata-only and must not expose raw private audit messages.
- Tool registration is metadata-only; no real tool execution exists yet.
- `DelegationBroker` safe trusted-device paths are metadata-only and require approval for external or critical decisions.
- `MemoryStore` is volatile in-memory storage only; it has no persistence, no external dependencies, no networking and no model calls.
- `SensitiveDataDetector` emits categories and reasons only; it does not retain raw sensitive matches.
- `RiskScorer` is deterministic and local; it does not call models, networks or external services.
- `ScenarioRunner` runs synthetic dry-run scenarios only.
- No model weights, credentials, signing files or real private data should be committed.

## Current validation status

- GitHub Connector could inspect repository metadata, relevant project files and open GitHub issues.
- Issue #1 acceptance criteria are satisfied by recorded validation evidence for:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

- Local/Codex-environment evidence is recorded on Issue #1 for all three required commands.
- PR #31 and PR #32 both recorded green PR-head validation evidence before merge.
- A local ZIP snapshot additionally confirmed `scripts/validate_repo_structure.py`, `scripts/validation_summary.py`, Swift tests and Swift build on the supplied repo snapshot.
- A post-merge workflow run attached to every new `main` merge commit is useful extra evidence, but it is no longer treated as a blocker for closing already satisfied validation issues.
- ChatGPT watcher comments, documentation notes and bookkeeping commits must not reset Issue #1 or create a new latest-main validation loop.
- Future code/runtime changes still require PR validation or a new validation issue.

## Current active task

Issue #10 is the current narrow runtime-preparation task: add `DiagnosticSnapshot` for Phase 2 readiness.

The active branch is:

```text
chatgpt/issue10-diagnostic-snapshot
```

This task is metadata-only. It must not add SwiftUI, App Intents, persistence, networking, external providers, model calls, screenshots, signing files or real private data.

## What still needs bootstrapping

- Configure `main` branch protection in GitHub UI
- Architecture docs from the verified starter package, imported gradually
- Optional GitHub social preview configuration after final social-card asset review
- Optional first Instagram carousel asset/template based on the social playbook

## Important constraint

The GitHub Connector can edit repository files, but it does not directly upload and extract ZIP archives. Therefore repository bootstrapping should happen as small direct commits or later narrow Draft PRs, not as broad ZIP dumps.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.

## Review owner

ChatGPT reviews all changes against scope, privacy impact and actual repo state.
