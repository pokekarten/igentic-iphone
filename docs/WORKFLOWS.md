# Project Workflows

Last reviewed: 2026-06-22

This document defines the GitHub Actions evidence used by the public iGentic repository and how that evidence connects to the five-task autonomous cycle.

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

## Five-task scheduled cycle

The active scheduled product cycle is:

```text
Issue or terminal state
-> Slot00 Director
-> Slot12 Producer
-> GitHub Actions + PR Autonomy Gate
-> Slot30 Validate + Review
-> Slot42 Closer
-> Slot54 Sequencer
-> next Slot00 context
```

Role boundaries:

- **Slot00 Director:** reconcile state and select one target only in a context stage.
- **Slot12 Producer:** implement one bounded artifact and open or adopt one Draft PR.
- **Slot30 Validate + Review:** reconcile required current-head workflows and independently review scope, semantics, safety and discussions.
- **Slot42 Closer:** mark Ready, re-check the stable head, squash-merge once and synchronize terminal state.
- **Slot54 Sequencer:** reconcile lane and rollup and count complete autonomous cycles.

Historical separate Slot18 Reviewer, Slot24 Closer and Slot30 Validation Watcher roles are not active. Slot30 now combines validation and semantic review; Slot42 is the closer.

The platform permits five active scheduled tasks. Adding a role requires replacing an active task through an explicit reviewed automation update.

## Exact-head and resource policy

- Exactly one active implementation target and at most one active PR.
- Current GitHub source overrides Brain, rollup and remembered state.
- Only the newest exact-head run of each required workflow may authorize review.
- A green old-head run cannot authorize a changed PR.
- Queued or running checks are `WAITING_RUNNER`, not defects.
- No no-op commit, branch rewrite or automatic retry to trigger CI.
- Linux checks provide broad inexpensive validation; Phase 0 is the required Swift/iOS gate.
- Successful logs are not downloaded.
- Detailed steps or logs are inspected only for a concrete latest-head failure.
- Connector calls remain serial and role-gated.
- API `403` or `429` stops the operation as `WAITING_API`; do not probe alternate mutation endpoints.
- Each authorized Producer or Closer performs at most one product mutation before readback.

## Review and merge decisions

Use `FIX_NEEDED` only for a concrete current-head defect, unsafe diff, scope mismatch, missing required test or broken contract.

Use `WAITING_RUNNER` when required checks are queued, running or temporarily absent.

Use `READY_FOR_CLOSE` only when:

- the exact head is stable;
- all required workflows are successful;
- the changed-file scope is correct;
- the linked issue and acceptance criteria are satisfied;
- semantic review is clean;
- no unresolved review thread remains;
- the PR is mergeable.

Slot42 must not merge Draft directly. It marks Ready, re-checks the same head and then squash-merges with `expected_head_sha`.

## Autonomous-cycle evidence

A complete counted cycle requires:

- one source-backed target;
- at most one implementation PR;
- bounded allowlisted scope;
- persisted Producer result;
- current-head required checks;
- independent Slot30 semantic review;
- expected-head closure or accurate terminal synchronization;
- final GitHub readback;
- private lane and rollup synchronization;
- no interactive repair during that counted cycle.

Three consecutive complete untouched cycles are required before the system may record `AUTONOMY_PROVEN=three_cycles`. This does not create or enable a sixth task.

## Support repositories

Pokekartenkiste remains paused and cannot consume an iGentic product task. Playbook and SLM Lab remain separate support repositories and cannot become implicit iGentic implementation targets.
