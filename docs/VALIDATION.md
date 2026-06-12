# Validation

This document defines what counts as a verified repository state for `pokekarten/igentic-iphone`.

The goal is to make validation reproducible for contributors, ChatGPT GitHub-Connector work, Codex Draft PRs and real-device testers.

## Required validation commands

Run these commands from the repository root unless noted otherwise:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

A task that claims to complete Issue #1 or any validation-gated milestone must record the exact result of all three commands.

## GitHub Actions validation

The canonical CI workflow is:

- `.github/workflows/ci-phase-0-validation.yml`

It must run on:

- pull requests,
- pushes to `main`,
- manual `workflow_dispatch` runs.

For a PR to be treated as merge-ready, the equivalent CI checks must be green on the PR head or PR merge ref. For `main` to be treated as clean, the same workflow must have a successful run on the current `main` commit.

## What counts as passing

A validation report is complete only when it records:

| Check | Required evidence |
| --- | --- |
| Repo structure | `python3 scripts/validate_repo_structure.py` exits 0 |
| Swift tests | `cd ios && swift test` exits 0 |
| Swift build | `cd ios && swift build` exits 0 |
| CI | GitHub Actions workflow conclusion is `success` for the relevant commit |

## What does not count as passing

Do not mark validation complete when:

- commands were only proposed but not executed,
- checks passed on an older commit,
- checks passed only before a merge but not on the current `main` commit when `main` validation is the task,
- the environment could not run Swift and no CI evidence exists,
- failure output is hidden or summarized as "probably fine".

## Documentation rules

When validation is run, update `PROJECT_STATE.md` with:

- date,
- commit or branch checked,
- exact command list,
- pass/fail result for each command,
- CI run IDs or links when available,
- any remaining blockers.

Update `docs/CHATGPT_NEXT_TASK.md` with the next safe task after validation.

## Issue #1 closure rule

Issue #1 may be closed only after all required validation commands are executed and documented, either locally or by GitHub Actions, for the relevant current repository state.

If any required check fails, keep Issue #1 open and document the smallest safe next fix.

## Safety boundary

Validation work must not add:

- app actions,
- persistence,
- networking,
- external providers,
- model calls,
- CoreML runtime changes,
- App Intents,
- secrets,
- real private data.

Validation should only prove that the existing safety-first repository is structurally sound and buildable.
