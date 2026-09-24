# Project Workflows

Last reviewed: 2026-09-24

This document defines the GitHub Actions evidence used by the public iGentic repository and how that evidence fits the current manual GitHub-first operating mode. Historical slot-based autonomy machinery is not an active product-work controller.

## CI principle

CI is the technical baseline for repository control. Evidence must match the exact commit under review. A small or documentation-only change is not exempt from the checks that protect repository structure, control files and contributor contracts.

GitHub Actions never replace semantic review or controlled merge authorization.

## Required checks by change type

| Change case | Required CI evidence | Notes |
| --- | --- | --- |
| Any pull request | PR Change Scope, Pull Request Quality, Repo Audit, Phase 0 CI Validation | Baseline for review and merge readiness. |
| Documentation / project-control docs | Docs Consistency, Repo Audit, Phase 0 CI Validation | Docs-only does not mean no CI. |
| GitHub workflow changes | Workflow Lint, PR Change Scope, Repo Audit, Phase 0 CI Validation | Workflow syntax and scope must be checked. |
| Swift / iOS runtime or test code | Phase 0 CI Validation | Includes repository structure, Swift build and Swift tests. |
| Scripts / automation code | Repo Audit and Phase 0 CI Validation | Automation must remain reviewable and non-destructive. |
| Issue templates / PR template | PR Change Scope, Docs Consistency, Repo Audit | Contributor intake affects evidence quality. |
| Forbidden artifacts or secrets | PR Change Scope must fail | Remove ZIPs, `.env` files, signing files, build products and private data. |
| Latest `main` validation | Phase 0 CI Validation on current `main` | Required before closing repository-wide validation work. |

Standalone Swift is supporting evidence only. It cannot block merge when the required exact-head Phase 0 CI Validation result is successful.

## Core workflows

### Phase 0 CI Validation

File: `.github/workflows/ci-phase-0-validation.yml`

Purpose:

- validate repository structure;
- build the Swift package on supported runners;
- run Swift tests.

Triggers: pull requests, pushes to `main` and manual runs.

This is the required Swift/iOS technical gate.

### Swift

File: `.github/workflows/swift.yml`

Purpose: provide an additional runner-specific Swift build and test signal. It is supporting evidence, not a second required macOS gate.

### PR Change Scope

File: `.github/workflows/pr-change-scope.yml`

Purpose:

- classify documentation, workflow, Swift, scripts, repository-control and other changes;
- fail on forbidden ZIPs, environment files, signing files, local build products or private data;
- remain read-only and non-mutating.

### Repo Audit

File: `.github/workflows/repo-audit.yml`

Purpose:

- run `scripts/validate_repo_structure.py`;
- execute autonomy evaluator tests on candidate PR code with contents-read permission only;
- check required public control files;
- publish a concise Actions summary.

It has no issue, PR, Actions or branch write permission.

### Docs Consistency

File: `.github/workflows/docs-consistency.yml`

Purpose:

- check local markdown references;
- protect README, workflow and validation-contract markers.

It runs for documentation, workflow and contributor-template changes.

### Pull Request Quality

File: `.github/workflows/pr-quality.yml`

Purpose: require `Summary`, `Scope`, `Validation`, `Safety` and `Follow-up` context and keep PRs small and evidence-backed.

### Workflow Lint

File: `.github/workflows/workflow-lint.yml`

Purpose: lint GitHub Actions YAML and catch syntax or expression errors. It is required whenever `.github/workflows/**` changes.

## Repository-control workflows

### PR Autonomy Gate

File: `.github/workflows/pr-autonomy-gate.yml`

Purpose:

- aggregate the newest required workflow result for the exact head of each open PR;
- distinguish `WAITING_CI`, `FIX_NEEDED`, `CI_GREEN` and `UNSUPPORTED_SCOPE`;
- maintain one idempotent marker comment owned by GitHub Actions;
- repair status drift through workflow-completion events and one low-frequency scheduled fallback.

Triggers:

- completion of PR Change Scope, Pull Request Quality, Repo Audit, Phase 0 CI Validation, Docs Consistency or Workflow Lint;
- manual dispatch;
- scheduled reconciliation once per hour at minute 17.

Security rules:

- no `pull_request` or `pull_request_target` trigger;
- trusted default-branch code only;
- never download or execute PR code, caches or artifacts;
- Actions read, contents read, pull requests read and issues write permissions only;
- no merge, auto-merge, branch update, issue closure, label mutation, cross-repository write or private Brain write.

The marker is an index only. `CI_GREEN` is technical evidence, not semantic approval or merge authorization.

### Control Dashboard

File: `.github/workflows/control-dashboard.yml`

Collects a read-only repository snapshot and recent workflow runs. It never mutates issues, PRs, refs or files.

### Main Health Reporter

File: `.github/workflows/main-health.yml`

Reports the selected triggering validation workflow. It is not the complete PR evidence aggregator.

### Project Control

File: `.github/workflows/project-control.yml`

Verifies durable control files and publishes project-control guidance. It does not own mutable lane state.

## Current operating mode

The repository is currently in **manual GitHub-first mode**.

- Live GitHub repository state is authoritative for pull requests, issues, branches, checks and merged state.
- Scheduled repository-control workflows are reconciliation and observability helpers; they do not select product work, authorize semantic changes or merge pull requests.
- `PR Autonomy Gate` may summarize exact-head CI state, but `CI_GREEN` is technical evidence only.
- ChatGPT with the live GitHub connector is the default repository inspection/edit/review lane for bounded work.
- Mac/Codex or physical-device execution is used only when a result genuinely depends on Xcode, Apple frameworks, signing, local model runtime, hardware behavior or another unavailable platform boundary.
- Historical private-Brain or Slot00/12/30/42/54 state must not override current GitHub source.

## Exact-head and resource policy

- Exactly one active implementation target and at most one active implementation PR.
- Current GitHub source overrides historical Brain, slot-controller, rollup or remembered state.
- Only the newest exact-head run of each required workflow may support review.
- A green old-head run cannot authorize a changed PR.
- Queued or running required checks are waiting evidence, not defects.
- Do not create no-op commits, rewrite branches or weaken gates merely to obtain a green status.
- Linux checks provide broad inexpensive validation; Phase 0 remains the required Swift/iOS package gate where applicable.
- Successful logs need not be downloaded; inspect detailed steps or logs only for a concrete current-head failure.
- API `403` or `429` is a real access/rate-limit boundary; do not probe alternate mutation endpoints to work around it.
- Platform-specific claims require evidence from the platform they depend on.

## Review and merge decisions

A pull request is merge-ready only when:

- the exact head is stable;
- all required workflows for its change type are successful;
- the changed-file scope is correct;
- linked acceptance criteria, when present, are satisfied;
- semantic and safety review is clean;
- no unresolved review thread remains;
- GitHub reports the PR as mergeable.

A Draft PR is not merge-ready. Technical CI success does not replace semantic review or user/repository authority for sensitive changes.

## Historical autonomy notes

The former five-slot autonomous product cycle (Slot00/12/30/42/54), private Brain lane and counted-cycle proof rules are historical operating material, not current execution authority. Do not create work, merge changes or block bounded repository progress merely to satisfy that retired controller shape.

If an old issue, comment or document refers to the slot controller, interpret it as historical unless current GitHub source explicitly reactivates that mechanism.

## Support repositories

Playbook, SLM Lab, Mac-worker and other repositories remain separate support or execution lanes. They do not become implicit iGentic implementation targets, and their state must not override live iGentic GitHub source.
