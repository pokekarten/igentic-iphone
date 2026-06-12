# Project State

Last updated: 2026-06-12

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
- Current phase: Phase 0 substantially documented / Phase 1 safety bootstrap in progress

## Phase 0 status

Phase 0 is now substantially documented and contributor-facing:

- Source verification rules: `docs/SOURCE_VERIFICATION.md`
- Apple API review: `docs/apple-api-review.md`
- Local runtime review: `docs/local-runtime-review.md`
- Model strategy: `MODEL_STRATEGY.md`
- Privacy model in code: `ios/Sources/AgentCore/DataClassification.swift`
- Policy model in code: `ios/Sources/AgentCore/PolicyEngine.swift`
- Public roadmap: `ROADMAP.md`
- Lightweight governance: `GOVERNANCE.md`
- Brand foundation: `docs/brand/BRAND.md`
- Design system: `docs/brand/DESIGN_SYSTEM.md`
- Logo brief and usage rules: `docs/brand/LOGO_BRIEF.md`, `docs/brand/LOGO_USAGE.md`
- Community strategy and channel model: `docs/community/COMMUNITY_STRATEGY.md`, `docs/community/COMMUNICATION_CHANNELS.md`
- Social media playbook: `docs/community/SOCIAL_MEDIA_PLAYBOOK.md`
- Contributor starter guide: `docs/community/CONTRIBUTOR_STARTER_GUIDE.md`
- Good-first-issue backlog: `docs/community/GOOD_FIRST_ISSUES.md`
- GitHub control runbook: `docs/GITHUB_CONTROL.md`
- Validation contract: `docs/VALIDATION.md`
- GitHub automation strategy: `docs/GITHUB_AUTOMATION_STRATEGY.md`
- Project operating model: `docs/PROJECT_OPERATING_MODEL.md`
- Workflow overview and CI case matrix: `docs/WORKFLOWS.md`
- Initial brand SVG assets and asset README: `assets/brand/`
- Apache 2.0 license: `LICENSE`

Remaining Phase 0 follow-up:

- Run CI/local validation after the latest safety-bootstrap and GitHub-control commits.
- Keep source notes current when Apple APIs or runtime candidates change.
- Decide whether to enable GitHub Discussions after the first repeated outside community questions.
- Convert selected good-first-issue backlog items into real GitHub issues.
- Review/refine initial SVG assets before setting a GitHub social preview.

## What exists now

- README with product vision, repo operating model, Phase 0 links, community links, brand links and new contributor quick-start
- `AGENTS.md` with ChatGPT/Codex/iPhone tester rules
- `ROADMAP.md`
- `GOVERNANCE.md`
- `CONTRIBUTING.md` with starter-guide, good-first-issue and design guidance links
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`
- `SUPPORT.md`
- `LICENSE`
- `docs/CODEX_NEXT_TASK.md` now paused
- `docs/CHATGPT_NEXT_TASK.md` as active next-task handoff
- `docs/GITHUB_AUTOMATION_STRATEGY.md` documenting GitHub Actions + `gh` CLI + Python reports for ChatGPT review
- `docs/PROJECT_OPERATING_MODEL.md` defining the durable ChatGPT/Codex/contributor work model
- `docs/WORKFLOWS.md` documenting Control Dashboard, Workflow Lint, PR Change Scope and validation expectations
- GitHub issue templates for feature, model, security, design, device test, good-first-issue and social content reviews
- Issue template chooser links for contributor guide, good-first-issue ideas, brand rules and security policy
- Pull request template with privacy, approval and delegation checklist
- Minimal Swift Package under `ios/`
- `PolicyEngine`, `TaskRouter`, `AuditLog`, `AgentKernel`, `ApprovalManager`, `ToolRegistry`, `DelegationBroker`, `MemoryStore`, `SensitiveDataDetector`, `RiskScorer`, `ScenarioRunner`
- Smoke tests for policy, audit log, approval-gated routing, tool registry behavior, memory-store scope behavior, sensitive-data detection, risk scoring, delegation broker decisions and scenario runner output
- Repo validation script requiring core AgentCore safety files, brand/community docs, issue templates, critical workflow files and accessible SVG metadata
- GitHub Actions for validation, PR change-scope classification, repo audit, docs consistency, main-health reporting, project control, issue triage and PR quality
- GitHub-control dashboard workflow for read-only repo state, PR, issue and CI run reports
- Workflow-lint workflow for `.github/workflows/**`

## Current safety posture

- Privacy and policy are implemented before app actions.
- `AuditLog` is lock-protected.
- Approval handling is now a first-class gate before tool routing.
- Tool registration is metadata-only; no real tool execution exists yet.
- `DelegationBroker` safe trusted-device paths are metadata-only and require approval for external or critical decisions.
- `MemoryStore` is volatile in-memory storage only; it has no persistence, no external dependencies, no networking and no model calls.
- `SensitiveDataDetector` emits categories and reasons only; it does not retain raw sensitive matches.
- `RiskScorer` is deterministic and local; it does not call models, networks or external services.
- `PolicyEngine` now attaches `RiskScorer` output to decisions as explanatory metadata only; existing allow, block and approval rules remain unchanged.
- `ScenarioRunner` runs synthetic dry-run scenarios only.
- GitHub-control scripts use read-only `git` and `gh` commands and generate reports only.
- Generated control reports are exposed through workflow summaries and are not committed back to `main` in this first version.
- No model weights, credentials, signing files or real private data should be committed.
- Public contribution docs warn against posting private data.
- Social media is explicitly not a decision authority.
- Official design must avoid Apple trade dress and confusing third-party mark usage.
- Brand SVG assets must include accessibility metadata (`title`, `desc`, `role="img"`).

## Current validation status

- GitHub Connector could inspect repository metadata, relevant project files and open GitHub issues.
- The accidental empty root file `DUMMY` was removed on branch `chatgpt/cleanup-validation-state`.
- GitHub-control dashboard automation was added on branch `codex/github-control-dashboard`.
- Project operating model is being added on branch `chatgpt/project-operating-model`.
- RiskScorer policy metadata integration is implemented on branch `codex/risk-scorer-policy-metadata`; local repo validation, Swift tests and Swift build passed before PR creation.
- CI case coverage is being added on branch `chatgpt/ci-case-coverage` with PR Change Scope and an updated validation contract.
- Local validation now passed in the Codex environment for this branch; Issue #1 should remain open until the same required checks are recorded for latest `main`.
- Required checks for latest `main` remain open:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

## What still needs bootstrapping

- Review the CI case coverage PR and confirm its PR Change Scope, Workflow Lint, Docs Consistency, Repo Audit, Pull Request Quality and Phase 0 CI results
- Run Control Dashboard, inspect generated report, then run Phase 0 CI/local validation after the latest GitHub-control commits
- Configure `main` branch protection in GitHub UI
- Re-enable Codex with one narrow Draft PR task after current `main` validation evidence is recorded
- Review and merge the conservative `RiskScorer` to `PolicyEngine` metadata-only Draft PR if validation remains green and policy behavior is not loosened
- Architecture docs from the verified starter package, imported gradually
- Convert first good-first-issue backlog items into GitHub issues
- Optional GitHub social preview configuration after final social-card asset review
- Optional first Instagram carousel asset/template based on the social playbook

## Important constraint

The GitHub Connector can edit repository files, but it does not directly upload and extract ZIP archives. Therefore repository bootstrapping should happen as small direct commits or later narrow Draft PRs, not as broad ZIP dumps.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.

## Review owner

ChatGPT reviews all changes against scope, privacy impact and actual repo state.
