# Project State

Last updated: 2026-06-12

## Current status

`iGentic iPhone` is being initialized as an open-source, privacy-first iPhone AI Runtime Layer repository.

The repo is now controlled directly through GitHub instead of relying on ZIP download/upload loops. Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

## Current baseline

- Repository: `pokekarten/igentic-iphone`
- Visibility: public
- Controller: ChatGPT via GitHub Connector
- Implementation assistant: paused; Codex later only for narrow Draft PRs
- Primary target device: iPhone Air as trust/control plane
- Current phase: Phase 0 / Phase 1 safety bootstrap

## What exists now

- README with product vision and repo operating model
- `AGENTS.md` with ChatGPT/Codex/iPhone tester rules
- `docs/CODEX_NEXT_TASK.md` now paused
- `docs/CHATGPT_NEXT_TASK.md` as active next-task handoff
- GitHub issue templates for feature, model and security reviews
- Minimal Swift Package under `ios/`
- `PolicyEngine`, `TaskRouter`, `AuditLog`, `AgentKernel`
- `AuditLog` thread-safety fix using a lock
- Smoke tests for policy and audit log behavior
- Repo validation script
- Swift and repo-audit GitHub Actions workflows

## Current safety posture

- Privacy and policy are implemented before app actions.
- `AuditLog` is no longer backed by an unprotected mutable array.
- Approval handling still needs a first-class guard before any real action layer is added.
- No model weights, secrets, app signing files or real private data should be committed.

## What still needs bootstrapping

- `ApprovalManager` with `.pending` and `.rejected` guard behavior
- `ToolRegistry` safe stub
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
