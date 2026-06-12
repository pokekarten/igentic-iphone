# GitHub Control Runbook

This repository is intentionally operated through GitHub-first control surfaces so ChatGPT, Codex, maintainers and contributors can work without hidden state.

## Control surfaces

| Surface | Purpose | Owner |
| --- | --- | --- |
| `PROJECT_STATE.md` | Canonical project state and validation status | ChatGPT / maintainers |
| `docs/CHATGPT_NEXT_TASK.md` | Current ChatGPT handoff and next safe action | ChatGPT / Ben |
| `docs/CODEX_NEXT_TASK.md` | Paused or narrow Codex Draft-PR handoff | ChatGPT / Ben |
| `docs/VALIDATION.md` | Validation contract and Issue #1 closure rule | Maintainers |
| GitHub Issues | Public backlog and contributor entry point | Maintainers / contributors |
| Pull Requests | Reviewable units of change | Contributors / automation |
| GitHub Actions | Objective validation evidence | CI |

## Default workflow

1. Start from an issue or `docs/CHATGPT_NEXT_TASK.md`.
2. Keep scope small and explicit.
3. Prefer a branch and PR over direct `main` edits.
4. Change only the allowed files.
5. Run or verify validation.
6. Update `PROJECT_STATE.md` and the next-task file.
7. Merge only when the diff is scoped and validation evidence is clear.

## Branch naming

Use predictable branch names:

- `chatgpt/<short-task>` for ChatGPT-controlled changes,
- `codex/<short-task>` for Codex Draft PRs,
- `docs/<short-topic>` for contributor documentation changes,
- `fix/<short-bug>` for small bug fixes.

## PR expectations

Every PR should include:

- summary,
- changed files,
- validation evidence,
- privacy/safety impact,
- follow-up task.

PRs must not claim that checks passed unless logs, local output or GitHub Actions evidence exists.

## Issue expectations

Every issue should include:

- goal,
- context,
- allowed files or safe scope,
- forbidden changes,
- validation target,
- definition of done.

Use `good first issue` only when a new contributor can complete the task without understanding the full runtime architecture.

## ChatGPT control rules

ChatGPT may safely do:

- read repo files,
- inspect issues and PRs,
- create focused docs and workflow changes,
- create small Swift safety stubs and tests when scope is explicit,
- review PR diffs,
- document validation status.

ChatGPT must be conservative with:

- closing issues,
- merging PRs,
- claiming validation success,
- editing broad architecture or runtime behavior.

ChatGPT must not add:

- real private data,
- secrets or signing files,
- external providers,
- model calls,
- networking,
- persistence,
- app actions,
- CoreML runtime changes,
- App Intents,

unless a future issue explicitly allows them and validation is updated.

## Codex control rules

Codex is paused by default. When used, it should receive only:

- a narrow branch name,
- an allowed file list,
- stop rules,
- exact validation commands,
- a requirement to open a Draft PR.

Codex must not claim a PR exists unless a real GitHub PR exists.

## Public open-source leverage

The repository should make outside contribution easy by keeping these areas current:

- README landing page,
- contributor starter guide,
- good-first-issue backlog,
- issue templates,
- PR template,
- validation contract,
- security policy,
- roadmap,
- project state.

The goal is not maximum activity. The goal is high-trust, privacy-first collaboration with clear review boundaries.
