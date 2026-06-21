# Project Workflows

This document explains the GitHub Actions workflows that support the public open-source project.

## CI principle

CI is the baseline for repository control. A pull request is not considered safe just because the changed files look small. Workflow evidence must match the exact commit under review.

Documentation-only changes usually do not alter runtime behavior, but they still require the checks that protect validation docs, workflow docs, repository-control files and contributor templates.

## Review decision principle

Use `MERGE-CANDIDATE` when scope is correct, the diff is safe, issue context is clear, required exact-head CI is green or equivalent evidence is sufficient, and no security, privacy, architecture or runtime regression is found. A clean Draft may be classified as `MERGE-CANDIDATE (Draft)`.

Use `FIX-NEEDED` only for a concrete defect: a failing required check, scope mismatch, missing tests for changed runtime behavior, unsafe diff, broken documentation contract or actionable review finding.

Use `BLOCKED` when a safe judgement cannot be made because required evidence is unavailable, contradictory or outside current visibility. Missing local logs alone are not a defect when GitHub Actions evidence is sufficient.

Use `NO-PR` when no open pull request is available.

## Required checks by change type

| Change case | Required CI evidence | Notes |
| --- | --- | --- |
| Any pull request | PR Change Scope, Pull Request Quality, Repo Audit, Phase 0 CI Validation | Baseline for review and merge readiness. |
| Documentation / project-control docs | Docs Consistency, Repo Audit, Phase 0 CI Validation | Docs-only does not mean no CI. |
| GitHub workflow changes | Workflow Lint, PR Change Scope, Repo Audit, Phase 0 CI Validation | Workflow syntax and scope must be checked. |
| Swift / iOS runtime or test code | Phase 0 CI Validation | Includes repo structure, Swift build and Swift tests. |
| Scripts / automation code | Repo Audit and Phase 0 CI Validation | Automation must remain reviewable and non-destructive. |
| Issue templates / PR template | PR Change Scope, Docs Consistency, Repo Audit | Contributor intake affects evidence quality. |
| Forbidden artifacts or secrets | PR Change Scope must fail | Remove ZIPs, `.env` files, signing files, build products and private data. |
| Latest `main` validation | Phase 0 CI Validation on current `main` | Required before closing Issue #1. |

The shadow PR Autonomy Gate summarizes these requirements but never replaces semantic review or merge gates.

## Core validation

### Phase 0 CI Validation

File: `.github/workflows/ci-phase-0-validation.yml`

Purpose:

- validate repository structure;
- build the Swift package on supported runners;
- run Swift tests.

Triggers:

- pull requests;
- pushes to `main`;
- manual runs.

This is the main validation source for Issue #1 and the required Swift/iOS technical gate for pull requests.

### Swift

File: `.github/workflows/swift.yml`

Purpose:

- provide an additional Swift build and test signal;
- expose runner-specific failures independently from the combined Phase 0 workflow.

The standalone Swift workflow is supporting evidence only. It does not become a merge blocker when the required exact-head Phase 0 CI Validation is successful.

## Scope and repository checks

### PR Change Scope

File: `.github/workflows/pr-change-scope.yml`

Purpose:

- classify documentation, workflow, Swift/iOS, scripts, repo-control, other and forbidden-artifact changes;
- summarize which validation expectations apply;
- fail when ZIP imports, environment files, signing files, local build products or other forbidden artifacts are introduced.

Safety:

- read-only permissions;
- no marketplace checkout action;
- no file modifications or generated commits.

### Repo Audit

File: `.github/workflows/repo-audit.yml`

Purpose:

- run the repository structure validator;
- execute `scripts/autonomy/test_evaluate_pr.py` on candidate PR code with contents-read permission only;
- check required public project-control files;
- publish a concise Actions summary.

Repo Audit is the only pull-request workflow that executes the autonomy evaluator tests. It has no issue, pull-request, Actions or branch write permission.

### Docs Consistency

File: `.github/workflows/docs-consistency.yml`

Purpose:

- check local markdown references;
- protect README and validation-contract markers.

It runs for documentation, workflow and contributor-template changes.

### Pull Request Quality

File: `.github/workflows/pr-quality.yml`

Purpose:

- require Summary, Scope, Validation, Safety and Follow-up context;
- keep PRs small, reviewable and evidence-backed.

### Workflow Lint

File: `.github/workflows/workflow-lint.yml`

Purpose:

- lint GitHub Actions YAML with actionlint;
- catch syntax and expression errors before merge.

It is required whenever `.github/workflows/**` changes.

## Repository control workflows

### Control Dashboard

File: `.github/workflows/control-dashboard.yml`

Purpose:

- collect a read-only repository snapshot;
- collect recent workflow runs;
- render a control report in `$GITHUB_STEP_SUMMARY`.

It does not mutate issues, pull requests, refs, runs or repository files.

### Main Health Reporter

File: `.github/workflows/main-health.yml`

Purpose:

- react to selected completed validation workflows;
- fail when the triggering upstream workflow did not pass;
- publish a concise health summary.

This reporter evaluates the triggering workflow only. It is not the complete PR evidence aggregator.

### Project Control

File: `.github/workflows/project-control.yml`

Purpose:

- verify that durable control files exist;
- publish project-control guidance;
- support manual, scheduled and repository-dispatch entry points.

### PR Autonomy Gate

File: `.github/workflows/pr-autonomy-gate.yml`

Purpose:

- aggregate the latest required workflow result for the exact head of each open PR;
- distinguish `WAITING_CI`, `FIX_NEEDED`, `CI_GREEN` and `UNSUPPORTED_SCOPE`;
- maintain one idempotent marker comment owned by GitHub Actions;
- repair status drift through event-driven runs plus one low-frequency scheduled fallback.

Triggers:

- completion of PR Change Scope, Pull Request Quality, Repo Audit, Phase 0 CI Validation, Docs Consistency or Workflow Lint;
- manual dispatch, optionally for one open PR;
- scheduled reconciliation once per hour at minute 17.

The standalone Swift workflow does not trigger the gate because it is supporting rather than required evidence. Phase 0 completion and the hourly recovery run are sufficient to reconcile the required state.

Security rules:

- no `pull_request` or `pull_request_target` trigger;
- top-level permissions are empty;
- the job checks out trusted default-branch code only;
- the job never downloads or executes PR code, caches or artifacts;
- the job has Actions read, contents read, pull requests read and issues write permissions only;
- no merge, auto-merge, branch update, issue closure, labels, cross-repository write or private Brain write.

Candidate evaluator tests are intentionally outside this privileged workflow and run in Repo Audit.

`CI_GREEN` is technical evidence only. Scheduled Reviewer and Closer roles still perform semantic review, discussion checks and stable-head merge control. See `docs/AUTONOMY_CONTROL.md`.

## Resource-aware workflow policy

- Exactly one implementation PR is active so scarce macOS capacity is not split across parallel targets.
- Broad and inexpensive validation runs on Linux before the required macOS result is considered.
- A queued or running job is a resource wait, not a code defect. It does not justify a no-op commit or branch rewrite.
- Phase 0 is the required macOS/Swift gate; standalone Swift is supporting evidence.
- `workflow_run` is the event-driven path. The minute-17 schedule is recovery only and must not be treated as exact-time delivery.
- Per-PR concurrency cancels superseded gate runs while keeping different PRs isolated.
- Successful job logs are not downloaded. Detailed logs are inspected only for a concrete latest-head failure.
- GitHub API and connector reads are role-gated and serial. Non-authorized slots stop after the lane read.
- API `403` or `429` responses stop the current operation. The system respects reset or retry guidance rather than probing repeatedly.
- Each authorized slot performs at most one product mutation and then re-reads the changed resource.

## Collaboration workflows

### Issue Triage

File: `.github/workflows/issue-triage.yml`

Purpose:

- inspect new or updated issues;
- add basic labels when possible;
- comment when important planning fields are missing.

### Dependabot

File: `.github/dependabot.yml`

Dependabot may open controlled GitHub Actions update PRs. Do not auto-merge dependency PRs until validation and repository protection rules are proven stable.

## GitHub Actions and scheduled slots

GitHub Actions own deterministic validation and exact-head technical aggregation. Scheduled slots own target selection, implementation, semantic review, blocker escape and controlled closure.

```text
Issue -> Context -> Producer -> PR Actions -> PR Autonomy Gate -> Reviewer -> Closer -> next Context
```

A stale private lane or rollup never overrides newer current GitHub evidence. The shadow comment is an index, not a substitute for reading the PR, changed files, issue, comments, reviews and review threads.

## Recommended rollout

1. Open the shadow-gate Draft PR from Issue #64.
2. Verify Repo Audit including evaluator tests, Workflow Lint, PR Change Scope, Pull Request Quality, Docs Consistency and Phase 0 CI Validation on the exact PR head.
3. Treat standalone Swift as supporting evidence rather than an additional required macOS gate.
4. Confirm that the privileged gate has no PR trigger and that Repo Audit is the only workflow executing candidate evaluator code.
5. Resolve all security review threads before Ready or merge.
6. Merge only after a stable-head security review.
7. Verify the first trusted default-branch shadow run while Issue #64 remains open.
8. Observe at least three real PR transitions: waiting, failing and green.
9. Confirm repeated runs update one marker comment without duplicate noise.
10. Keep auto-merge, automatic task selection and cross-repository writes out of version 1.
11. Configure repository rules or branch protection separately when owner settings are available.