# AGENTS.md — iGentic iPhone Repo Constitution

Repository: `pokekarten/igentic-iphone`

This repository is designed to be operated by a human product owner, ChatGPT with GitHub Connector, and Codex working through small pull requests.

The project is not a normal chatbot app. It is a privacy-first iPhone AI Runtime Layer. Security, local-first behavior, policy decisions and auditability are product requirements, not implementation details.

## Roles

### Human owner

- Owns product direction and final decisions.
- Tests on the real iPhone.
- Approves critical privacy, security and model decisions.
- Never has to accept hidden autonomy from the agent.

### ChatGPT project controller

- Reads repo state through the GitHub Connector.
- Turns product goals into small, reviewable tasks.
- Updates or prepares `docs/CODEX_NEXT_TASK.md` before delegating implementation.
- Reviews Codex PRs against scope, allowed files, tests and privacy impact.
- Keeps architecture, roadmap and state docs aligned.
- Does not claim a task is done unless repo state, diff or provided logs support it.

### Codex implementation agent

- Implements one narrow task per branch.
- Uses the branch and file allowlist specified in `docs/CODEX_NEXT_TASK.md`.
- Creates Draft PRs only.
- Stops when stop rules are hit instead of guessing.
- Does not perform broad rewrites, secret handling, external integrations or App Store changes unless explicitly scoped.

### iPhone field tester

- Runs prototypes on a real iPhone or simulator.
- Captures screenshots, logs, thermal/battery notes and device constraints.
- Reports results back into issues or PR comments.

## Operating rules

1. One task equals one branch and one Draft PR.
2. Prefer docs, tests and policy code before runtime expansion.
3. Every PR must state data classes touched, action risks changed and approval behavior.
4. Never store secrets, tokens, health data, financial data, messages or private user data in the repo.
5. Use English file names and code comments. German product notes are fine in discussion and planning.
6. For iOS app work, prefer Swift Package tests first; add app targets only after kernel behavior is stable.
7. If a task touches privacy policy, delegation, model runtime or App Intents, add or update tests.
8. If uncertainty is high, create a research note or issue instead of shipping speculative code.

## Sparsamkeit rules

- Default Codex context is `AGENTS.md`, `PROJECT_STATE.md`, `docs/CODEX_NEXT_TASK.md`, one task-specific doc and the allowlisted files only.
- Keep Codex tasks to 3-5 files whenever possible.
- Prefer under 250 changed lines per PR.
- Do not ask Codex to explore the whole repository unless the task is explicitly a repo audit.
- Use ChatGPT + GitHub Connector for review, source verification, issue creation and next-task preparation.
- Use real iPhone testing only for device behavior, Apple permissions, App Intents, thermal, battery or local model runtime validation.
- Read `docs/SPARSAMKEIT.md` before expanding task scope.

## Stop rules for agents

Stop and report instead of continuing when:

- required source files are missing,
- local build/test environment is unavailable,
- the task requires credentials, signing certificates, Apple Developer account access or private data,
- a requested change exceeds the allowed files,
- a model/runtime claim cannot be verified from a current source,
- the implementation would bypass `PolicyEngine`, `ApprovalManager` or `AuditLog`.

## Validation

Default validation for code changes:

```bash
python scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

If a command is unavailable because the repo is still being bootstrapped, explain that clearly in the PR body.
