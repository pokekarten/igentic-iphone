# Project Workflows

This document explains the GitHub Actions workflows that support the public open-source project.

## CI principle

CI is the baseline for repository control. A pull request is not considered safe just because the changed files look small. The workflows must show which case applies and whether the relevant checks passed for the exact commit under review.

Documentation-only changes usually do not alter runtime or build behavior, but they can and should still trigger CI when they touch validation docs, workflow docs, repository-control files or PR templates.

## Review decision principle

Review classifications should separate actual defects from missing or partially unavailable evidence.

Use `MERGE-CANDIDATE` when the scope is correct, the diff is safe, linked issue context is clear, required CI is green or enough equivalent validation evidence is available, and no security, privacy, architecture or runtime regression is found. A draft PR with otherwise clean evidence may be recorded as `MERGE-CANDIDATE (Draft)` instead of `FIX-NEEDED`.

Use `FIX-NEEDED` only when there is a concrete problem that should be changed before merge, such as a failing required check, a scope mismatch, missing tests for changed runtime behavior, an unsafe diff, broken documentation contracts or a review finding that can be acted on in the PR.

Use `BLOCKED` when the reviewer cannot make a safe judgement because required evidence is unavailable, contradictory or outside the connector's visibility. Missing local validation logs alone do not make a PR `FIX-NEEDED` when GitHub Actions evidence is present and sufficient for the changed scope.

Use `NO-PR` when no open pull request is available for review.

## Core validation

### Phase 0 CI Validation

File: `.github/workflows/ci-phase-0-validation.yml`

Purpose:

- Validate repository structure.
- Build the Swift package.
- Run Swift tests.

Triggers:

- Pull requests.
- Pushes to `main`.
- Manual workflow runs.

This is the main validation source for Issue #1 and the baseline check for every PR.

## CI case coverage

### PR Change Scope

File: `.github/workflows/pr-change-scope.yml`

Purpose:

- Classify changed files into documentation, workflow, Swift/iOS, scripts, repo-control, other and forbidden-artifact buckets.
- Produce a GitHub Actions summary that tells reviewers which validation expectations apply.
- Fail early when forbidden artifacts are introduced, such as ZIP imports, local build products, signing files or environment files.

Triggers:

- Pull requests opened, edited, synchronized, reopened or marked ready for review.
- Manual workflow runs.

Safety rules:

- Read-only permissions.
- No marketplace checkout action.
- No file modifications.
- No generated commits.

### Required checks by change type

| Change case | Required CI evidence | Notes |
| --- | --- | --- |
| Any pull request | PR Change Scope, Pull Request Quality, Repo Audit, Phase 0 CI Validation | Baseline for review and merge readiness. |
| Documentation / project-control docs | Docs Consistency, Repo Audit, Phase 0 CI Validation | Docs-only does not mean no CI; docs can affect validation contracts. |
| GitHub workflow changes | Workflow Lint, PR Change Scope, Repo Audit, Phase 0 CI Validation | Workflow syntax must be checked before merge. |
| Swift / iOS runtime or test code | Phase 0 CI Validation | Includes repo structure, Swift build and Swift tests. |
| Scripts / automation code | Repo Audit and Phase 0 CI Validation | Automation must stay reviewable and non-destructive unless explicitly scoped. |
| Issue templates / PR template | PR Change Scope, Docs Consistency, Repo Audit | These files affect contributor intake and validation evidence. |
| Forbidden artifacts or secrets | PR Change Scope must fail | Remove ZIPs, `.env` files, signing files, local build products and private data. |
| Latest `main` validation | Phase 0 CI Validation on the current `main` commit | Required before closing Issue #1. |

## Repository control workflows

### Control Dashboard

File: `.github/workflows/control-dashboard.yml`

Purpose:

- Collect a read-only repository-state snapshot.
- Collect recent GitHub Actions workflow runs.
- Render the latest control report into the workflow workspace.
- Expose the report through `$GITHUB_STEP_SUMMARY`.

Triggers:

- Manual workflow runs.
- Weekly schedule at `03:17 UTC` on Tuesdays.
- Repository dispatch events: `project-control`, `repo-audit`, `run-validation`.

Safety rules:

- No marketplace checkout action.
- No mutation of issues, pull requests, refs, workflow runs or repository files.
- No generated reports committed back to `main` in this first version.

### Repo Audit

File: `.github/workflows/repo-audit.yml`

Purpose:

- Run the repo structure validator.
- Check that required public project control files exist.
- Produce a GitHub Actions summary.

Triggers:

- Pull requests.
- Manual workflow runs.
- Weekly schedule.

### Docs Consistency

File: `.github/workflows/docs-consistency.yml`

Purpose:

- Check that local markdown references point to existing files.
- Check that README and validation docs keep required control markers.

Triggers:

- Pull requests that touch docs, workflows or templates.
- Pushes to `main` that touch docs, workflows or templates.
- Manual workflow runs.

### Main Health Reporter

File: `.github/workflows/main-health.yml`

Purpose:

- React to completed validation, audit or docs consistency workflows.
- Fail when an upstream workflow did not pass.
- Produce a concise health summary.

Triggers:

- Completed runs of Phase 0 CI Validation, Repo Audit or Docs Consistency.
- Manual workflow runs.

### Project Control

File: `.github/workflows/project-control.yml`

Purpose:

- Check that the main control files exist.
- Produce a project-control summary and recommended next action.
- Support manual, scheduled and external dispatch usage.

Triggers:

- Manual workflow runs.
- Weekly schedule.
- Repository dispatch events: `project-control`, `repo-audit`, `run-validation`.

## Collaboration workflows

### Issue Triage

File: `.github/workflows/issue-triage.yml`

Purpose:

- Inspect new or updated issues.
- Add basic labels based on issue content when possible.
- Comment when important planning fields are missing.

Triggers:

- Issues opened, edited or reopened.

### Pull Request Quality

File: `.github/workflows/pr-quality.yml`

Purpose:

- Check PR descriptions for core planning, validation and safety sections.
- Encourage small, reviewable PRs with clear evidence.

Triggers:

- Pull requests opened, edited, synchronized, reopened or marked ready for review.

### Workflow Lint

File: `.github/workflows/workflow-lint.yml`

Purpose:

- Lint GitHub Actions workflow YAML files.
- Catch workflow syntax and actionlint problems early.
- Make workflow edits safer before merging.

Triggers:

- Pull requests that change `.github/workflows/**`.
- Pushes to `main` that change `.github/workflows/**`.
- Manual workflow runs.

Safety rules:

- Read-only permissions.
- No file modifications.
- No generated commits.

## Dependency workflow

### Dependabot

File: `.github/dependabot.yml`

Purpose:

- Open controlled update PRs for GitHub Actions dependencies.

Rule:

- Do not auto-merge dependency PRs until validation is stable and branch protection is configured.

## Recommended next steps

1. Open the CI case coverage PR and inspect its PR Change Scope summary.
2. Let Phase 0 CI Validation, Repo Audit, Docs Consistency, Workflow Lint and PR Quality run on the PR.
3. Merge only if the workflow changes are green and the PR summary matches the intended scope.
4. Run Phase 0 CI Validation on the latest `main` commit after merge.
5. Record the result in `PROJECT_STATE.md` and Issue #1.
6. Configure branch protection for `main` in GitHub UI.
7. Convert selected good-first backlog items into real issues after Issue #1 is resolved.
