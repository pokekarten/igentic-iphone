# Project Operating Model

This document defines how the iGentic iPhone repository should be operated so the project can move quickly without losing trust, reviewability or contributor clarity.

## Goals

- Keep `main` usable and trustworthy.
- Let ChatGPT, Codex and human contributors work in parallel through small reviewable tasks.
- Make GitHub the durable project memory instead of relying on any single chat session.
- Prefer visible progress through tests, diagnostics, documentation and safe stubs before runtime expansion.
- Attract contributors with clear issues, clear constraints and fast review loops.

## Roles

### Human owner

- Sets product direction and final priorities.
- Tests real-device behavior.
- Approves high-impact privacy, runtime, model and App Intents decisions.
- Decides when repository settings such as branch protection are changed.

### ChatGPT controller

- Reads repo state through the GitHub Connector.
- Chooses or creates the next small issue-backed task.
- Creates branches and pull requests for small safe changes when appropriate.
- Prepares Codex tasks in `docs/CODEX_NEXT_TASK.md` when implementation should be delegated.
- Reviews PR scope, changed files, tests, workflow results and safety impact before merge.
- Updates state docs and issues after meaningful changes.

### Codex worker

- Implements one narrow task per branch.
- Uses the branch name, allowed files, validation commands and stop rules from `docs/CODEX_NEXT_TASK.md`.
- Opens Draft PRs only.
- Stops instead of guessing when files are missing, tests cannot run, scope expands or credentials/private data would be required.

### Contributors

- Start with issues labeled as documentation, tests, good first issue, diagnostics or safe stub work.
- Follow the PR template and validation instructions.
- Use synthetic data only.
- Do not add secrets, real private data, external providers or runtime actions unless explicitly scoped.

## Work lanes

### Lane 1: ChatGPT fast lane

Used for small safe changes:

- documentation fixes,
- issue hygiene,
- workflow documentation,
- small validation scripts,
- small tests,
- PR review and triage.

Rules:

- Never commit directly to `main`.
- Use one branch per task.
- Keep changes small enough to review quickly.
- Record uncertainty instead of hiding it.

### Lane 2: Codex worker lane

Used for implementation tasks that are narrow enough to delegate.

Codex tasks must include:

- repository name,
- base branch,
- working branch,
- goal,
- allowed files,
- forbidden files or behaviors,
- validation commands,
- stop rules,
- Draft PR requirement.

Good Codex tasks are usually 3-5 files and under 250 changed lines.

### Lane 3: contributor lane

Used for community growth and external contributions.

Good contributor tasks should:

- explain the project fit,
- list suggested files,
- define acceptance criteria,
- define stop rules,
- avoid requiring private context,
- be possible without Apple signing credentials or real private data.

## Main branch rules

`main` is the public trust branch.

Required behavior:

- No direct writes to `main`.
- All changes go through PRs.
- PRs should be small and issue-backed when possible.
- Merge only after relevant checks pass or failures are explicitly understood and scoped.
- Prefer squash merge for a readable history.
- Keep Issue #1 open until current `main` validation evidence exists.

Recommended repository settings:

- require pull request before merge,
- require status checks before merge,
- require conversation resolution,
- disallow force pushes and branch deletion,
- do not allow bypassing protection for routine work,
- optionally require linear history once the workflow is stable.

## Validation gates

The canonical validation target is:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

A PR should not claim validation passed unless the command was actually run locally or by GitHub Actions.

If validation cannot be run, the PR must say that explicitly and explain why.

## GitHub Actions model

Actions should act as sensors and gates, not autonomous maintainers.

Allowed actions:

- validate structure,
- build and test,
- lint workflow files,
- check docs consistency,
- summarize repository and workflow state,
- label or comment on issues when conservative and transparent.

Disallowed by default:

- automatic merge,
- automatic code generation from issue or PR text,
- automatic committing of generated reports,
- workflow cancellation or reruns from collector scripts,
- secrets or private data in reports.

## Issue hygiene

Every important task should live in GitHub issues.

Issue states should be obvious from labels, comments or linked PRs:

- ready,
- in progress,
- blocked,
- needs validation,
- merged / awaiting main validation,
- done.

Issue #1 is special: it is the current repo validation gate and should remain open until validation evidence exists for current `main`.

## Definition of done

A task is done only when:

- the intended files changed,
- out-of-scope files did not change,
- tests or validation evidence are recorded,
- safety constraints were not loosened,
- docs/state/issues are updated if behavior or process changed,
- the PR was reviewed against the task scope.

## Recovery checklist

Use this when the repo path becomes unclear:

1. Stop writing.
2. Inspect open PRs.
3. Inspect latest `main` commit and visible checks.
4. Inspect Issue #1 and current validation evidence.
5. Close or ignore unused branches; do not build new work on them.
6. Pick one next issue.
7. Create one fresh branch from current `main`.
8. Open one small PR.

## Contributor growth strategy

To attract contributors, keep the first contribution path simple:

- keep README and contributor docs clear,
- maintain good-first issues,
- prefer small tests and diagnostics as entry tasks,
- keep labels meaningful,
- respond to PRs with concrete review notes,
- avoid hidden project context that only the original maintainers understand.

## Current next operating priority

1. Validate current `main` and update Issue #1.
2. Configure branch protection for `main`.
3. Resume small PRs through ChatGPT fast lane.
4. Re-enable Codex with one narrow Draft PR task after the validation gate is clean.
