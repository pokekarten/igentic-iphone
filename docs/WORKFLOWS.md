# Project Workflows

This document explains the GitHub Actions workflows that support the public open-source project.

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

This is the main validation source for Issue #1.

## Repository control workflows

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

## Dependency workflow

### Dependabot

File: `.github/dependabot.yml`

Purpose:

- Open controlled update PRs for GitHub Actions dependencies.

Rule:

- Do not auto-merge dependency PRs until validation is stable and branch protection is configured.

## Recommended next steps

1. Run Phase 0 CI Validation on the latest `main` commit.
2. Record the result in `PROJECT_STATE.md`.
3. Keep Issue #1 open until the validation result is documented.
4. Configure branch protection for `main` in GitHub UI.
5. Convert selected good-first backlog items into real issues.
