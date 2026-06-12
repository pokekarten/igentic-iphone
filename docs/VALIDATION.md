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

## CI case coverage

The case-classification workflow is:

- `.github/workflows/pr-change-scope.yml`

It classifies pull requests so reviewers can tell which checks are expected for the exact change type. Documentation changes are still allowed to trigger CI. That is intentional: docs can define validation contracts, contributor rules and project state.

| Change case | Required evidence before merge or closure |
| --- | --- |
| Any pull request | PR Change Scope, Pull Request Quality, Repo Audit and Phase 0 CI Validation are green. |
| Documentation-only change | Docs Consistency is green when docs, README, templates or project-state files are touched. Phase 0 CI remains the baseline confidence check. |
| Workflow change | Workflow Lint is green and PR Change Scope confirms workflow files were intentionally changed. |
| Swift / iOS code change | Phase 0 CI Validation is green, including repo structure, Swift build and Swift tests. |
| Script / automation change | Repo Audit and Phase 0 CI Validation are green. The change must not introduce destructive automation unless explicitly scoped. |
| Forbidden local artifact | PR Change Scope must fail until the artifact is removed. |
| Latest `main` validation | Phase 0 CI Validation must succeed on the current `main` commit before Issue #1 is closed. |

## What counts as passing

A validation report is complete only when it records:

| Check | Required evidence |
| --- | --- |
| Repo structure | The repo-structure validation command exits 0 |
| Swift tests | The Swift test command exits 0 |
| Swift build | The Swift build command exits 0 |
| CI | GitHub Actions workflow conclusion is `success` for the relevant commit |
| Change-scope classification | PR Change Scope identifies the expected change buckets and does not report forbidden artifacts |

The exact command list remains the fenced command block above.

## What does not count as passing

Do not mark validation complete when:

- commands were only proposed but not executed,
- checks passed on an older commit,
- checks passed only before a merge but not on the current `main` commit when `main` validation is the task,
- the environment could not run Swift and no CI evidence exists,
- a docs-only PR skipped review of docs consistency,
- a workflow PR skipped workflow lint,
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

Validation work must remain documentation and verification focused. It must not introduce runtime capabilities, external integrations or real user data.

Validation should only prove that the existing safety-first repository is structurally sound and buildable.
