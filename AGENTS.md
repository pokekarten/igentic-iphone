# AGENTS.md

## Repository
`pokekarten/igentic-iphone`

## Goal
Privacy-first iPhone AI runtime starter repo, developed as an open-source project with small, reviewable Codex tasks.

## Default workflow
1. Read `PROJECT_STATE.md`, `docs/CODEX_NEXT_TASK.md`, and `docs/CHATGPT_NEXT_TASK.md` before changing files.
2. Use a dedicated branch for each task, usually `codex/<task-name>`.
3. Keep changes small and scoped.
4. Run validation before creating a Draft PR.
5. Open Draft PRs only. ChatGPT reviews before merge.

## Do not commit
- secrets or credentials
- `.env*`
- certificates or provisioning profiles
- model weights
- `.build/`, DerivedData, `node_modules/`
- ZIP archives or generated build artifacts

## Validation
Run:

```bash
npm run validate
cd ios && swift test
```

If a command is unavailable because the repo is not fully bootstrapped yet, explain that clearly in the PR body.
