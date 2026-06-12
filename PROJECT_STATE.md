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
- Current phase: Phase 0 substantially documented / Phase 1 safety bootstrap in progress

## Phase 0 status

Phase 0 is now substantially documented:

- Source verification rules: `docs/SOURCE_VERIFICATION.md`
- Apple API review: `docs/apple-api-review.md`
- Local runtime review: `docs/local-runtime-review.md`
- Model strategy: `MODEL_STRATEGY.md`
- Privacy model in code: `ios/Sources/AgentCore/DataClassification.swift`
- Policy model in code: `ios/Sources/AgentCore/PolicyEngine.swift`

Remaining Phase 0 follow-up:

- Run CI/local validation after the latest commits.
- Keep source notes current when Apple APIs or runtime candidates change.

## What exists now

- README with product vision, repo operating model, Phase 0 links and community links
- `AGENTS.md` with ChatGPT/Codex/iPhone tester rules
- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`
- `SUPPORT.md`
- `docs/CODEX_NEXT_TASK.md` now paused
- `docs/CHATGPT_NEXT_TASK.md` as active next-task handoff
- GitHub issue templates for feature, model and security reviews
- Minimal Swift Package under `ios/`
- `PolicyEngine`, `TaskRouter`, `AuditLog`, `AgentKernel`, `ApprovalManager`, `ToolRegistry`
- `AuditLog` thread-safety fix using a lock
- Approval gate in `AgentKernel` before routing to local tools
- `ToolRegistry` metadata-only stub for tool names, required data levels and action risks
- Smoke tests for policy, audit log, approval-gated routing and tool registry behavior
- Repo validation script
- Swift and repo-audit GitHub Actions workflows

## Current safety posture

- Privacy and policy are implemented before app actions.
- `AuditLog` is lock-protected.
- Approval handling is now a first-class gate before tool routing.
- `.pending` approval status stops routing.
- `.approved` approval status allows routing to continue.
- Tool registration is metadata-only; no real tool execution exists yet.
- No model weights, secrets, app signing files or real private data should be committed.
- Public contribution docs warn against posting secrets or private data.

## What still needs bootstrapping

- `MemoryStore` safe stub
- `DelegationBroker` policy-gated stub
- Architecture docs from the verified starter package, imported gradually
- Initial CI verification after the next push/run cycle

## Important constraint

The GitHub Connector can edit repository files, but it does not directly upload and extract ZIP archives. Therefore repository bootstrapping should happen as small direct commits or later narrow Draft PRs, not as broad ZIP dumps.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.

## Review owner

ChatGPT reviews all changes against scope, privacy impact and actual repo state.
