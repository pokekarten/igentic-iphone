# Project State

Last updated: 2026-06-13

## Current status

`iGentic iPhone` is being initialized as an open-source, privacy-first iPhone AI Runtime Layer repository.

The repo is controlled directly through GitHub. Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository-control, documentation and process changes.

## Current baseline

- Repository: `pokekarten/igentic-iphone`
- Visibility: public
- Controller: ChatGPT via GitHub Connector
- Implementation assistant: paused; Codex later only for narrow Draft PRs
- Primary target device: iPhone Air as trust/control plane
- Master brand: `iGentic`
- Current research track: `iGentic iPhone`
- Community model: GitHub-first, social-supported
- Current phase: Phase 0 validation complete; Phase 1 safety bootstrap in progress
- Current brand track: v3 responsive brand system, documented in `docs/brand/BRAND_ASSET_MANIFEST.md`

## Phase 0 status

Phase 0 is substantially documented and contributor-facing. Issue #1 is closed as completed because its original acceptance criteria are satisfied by recorded validation evidence.

## Recent completed work

- PR #31 `Issue #18: add ApprovalReceipt metadata` was squash-merged into `main` as `c4e8bb137201382e73b86b81a69a465db87cc559`.
- Issue #18 is closed as completed.
- `ApprovalReceipt` now records approval status metadata without storing private raw data.
- `ApprovalManager` can create approval receipts for audit/diagnostic use.
- Focused tests cover pending, approved and rejected approval outcomes.
- Brand identity v3 assets were added as preferred candidates for public profile, symbol, lockup, dark mark and social carousel usage.

## What exists now

- README, roadmap, governance, contribution, support, security and conduct docs
- Phase 0 source verification, Apple API, local runtime, model strategy, validation and workflow docs
- Brand/community docs and SVG assets, including `docs/brand/BRAND.md`, `docs/brand/CORPORATE_IDENTITY.md`, `docs/brand/SOCIAL_IDENTITY.md`, `docs/brand/BRAND_ASSET_MANIFEST.md`, `docs/brand/BRAND_REVIEW_WORKFLOW.md` and `docs/community/COMMUNITY_STRATEGY.md`
- Current preferred brand candidates:
  - `assets/brand/logo-symbol-v3.svg`
  - `assets/social/instagram-profile-v3.svg`
  - `assets/brand/logo-mark-dark-v3.svg`
  - `assets/brand/logo-lockup-v3.svg`
  - `assets/social/instagram-carousel-template-v1.svg`
- GitHub control, workflow lint, PR quality, repo audit, docs consistency and validation workflows
- Minimal Swift Package under `ios/`
- `PolicyEngine`, `TaskRouter`, `AuditLog`, `AgentKernel`, `ApprovalManager`, `ApprovalReceipt`, `ToolRegistry`, `DelegationBroker`, `MemoryStore`, `SensitiveDataDetector`, `RiskScorer`, `ScenarioRunner`
- Smoke tests for policy, audit log, approval-gated routing, approval receipt metadata, tool registry behavior, memory-store scope behavior, sensitive-data detection, risk scoring, delegation broker decisions and scenario runner output
- Repo validation script requiring core AgentCore safety files, brand/community docs, issue templates, critical workflow files and accessible SVG metadata

## Current safety posture

- Privacy and policy are implemented before app actions.
- `AuditLog` is lock-protected.
- Approval handling is now a first-class gate before tool routing.
- Approval receipts are metadata-only and must not store private raw input.
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
- PR #31 also recorded PR-head validation evidence before merge.
- A local ZIP snapshot additionally confirmed `scripts/validate_repo_structure.py`, `scripts/validation_summary.py`, Swift tests and Swift build on the supplied repo snapshot.
- A post-merge workflow run attached to every new `main` merge commit is useful extra evidence, but it is no longer treated as a blocker for closing the original Phase 0 validation issue when the issue acceptance criteria are already met.
- ChatGPT watcher comments, documentation notes and bookkeeping commits must not reset Issue #1 or create a new latest-main validation loop.
- Future code/runtime changes still require PR validation or a new validation issue.

## Current active task

The current active brand task is to visually validate the v3 responsive brand system and decide whether it becomes the default public identity.

The source-of-truth files are:

- `docs/brand/BRAND_ASSET_MANIFEST.md`
- `docs/brand/BRAND_REVIEW_WORKFLOW.md`
- `docs/brand/SOCIAL_IDENTITY.md`
- `docs/CHATGPT_NEXT_TASK.md`

## What still needs bootstrapping

- Configure `main` branch protection in GitHub UI
- Architecture docs from the verified starter package, imported gradually
- Optional GitHub social preview configuration after final social-card asset review
- Visual review of v3 brand assets at 64 px, 120 px and 220 px
- Test `assets/social/instagram-carousel-template-v1.svg` with three real social topics

## Important constraint

The GitHub Connector can edit repository files, but it does not directly upload and extract ZIP archives. Therefore repository bootstrapping should happen as small direct commits or later narrow Draft PRs, not as broad ZIP dumps.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.

## Review owner

ChatGPT reviews all changes against scope, privacy impact and actual repo state.
