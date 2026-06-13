# Project State

Last updated: 2026-06-13

## Current status

`iGentic iPhone` is being initialized as an open-source, privacy-first iPhone AI Runtime Layer repository.

The repo is controlled directly through GitHub. Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

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

## Phase 0 status

Phase 0 is substantially documented and contributor-facing. Issue #1 is ready to close because its original acceptance criteria are satisfied by recorded validation evidence.

## What exists now

- README, roadmap, governance, contribution, support, security and conduct docs
- Phase 0 source verification, Apple API, local runtime, model strategy, validation and workflow docs
- Brand/community docs and initial SVG assets, including `docs/brand/BRAND.md` and `docs/community/COMMUNITY_STRATEGY.md`
- GitHub control, workflow lint, PR quality, repo audit, docs consistency and validation workflows
- Minimal Swift Package under `ios/`
- `PolicyEngine`, `TaskRouter`, `AuditLog`, `AgentKernel`, `ApprovalManager`, `ToolRegistry`, `DelegationBroker`, `MemoryStore`, `SensitiveDataDetector`, `RiskScorer`, `ScenarioRunner`
- Smoke tests for policy, audit log, approval-gated routing, tool registry behavior, memory-store scope behavior, sensitive-data detection, risk scoring, delegation broker decisions and scenario runner output
- Repo validation script requiring core AgentCore safety files, brand/community docs, issue templates, critical workflow files and accessible SVG metadata

## Current safety posture

- Privacy and policy are implemented before app actions.
- `AuditLog` is lock-protected.
- Approval handling is now a first-class gate before tool routing.
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
- Recent PR-head checks also recorded repository validation evidence before merge.
- A post-merge workflow run attached to every new `main` merge commit is useful extra evidence, but it is no longer treated as a blocker for closing the original Phase 0 validation issue when the issue acceptance criteria are already met.
- ChatGPT watcher comments, documentation notes and bookkeeping commits must not reset Issue #1 or create a new latest-main validation loop.
- Future code/runtime changes still require PR validation or a new validation issue.

## What still needs bootstrapping

- Configure `main` branch protection in GitHub UI
- Convert first good-first-issue backlog items into GitHub issues
- Architecture docs from the verified starter package, imported gradually
- Optional GitHub social preview configuration after final social-card asset review
- Optional first Instagram carousel asset/template based on the social playbook

## Important constraint

The GitHub Connector can edit repository files, but it does not directly upload and extract ZIP archives. Therefore repository bootstrapping should happen as small direct commits or later narrow Draft PRs, not as broad ZIP dumps.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.

## Review owner

ChatGPT reviews all changes against scope, privacy impact and actual repo state.
