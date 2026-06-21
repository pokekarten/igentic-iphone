# GitHub Actions Autonomy Control

Issue: #64

## Purpose

The PR Autonomy Gate is a GitHub-native, metadata-only shadow controller for open iGentic pull requests. It closes the gap between individual validation workflows and the scheduled agent lane by publishing one exact-head technical summary directly on the pull request.

The gate does not replace review. It does not decide product direction, approve semantics or merge code.

## Responsibility split

| Surface | Responsibility |
| --- | --- |
| GitHub Issues | Public task scope, acceptance criteria and stop rules |
| Pull Requests | Reviewable implementation unit and current head SHA |
| Existing GitHub Actions | Build, tests, repository structure, documentation, PR quality and changed-file validation |
| Repo Audit | Execute evaluator unit tests on candidate PR code with contents-read permission only |
| PR Autonomy Gate | Aggregate latest required exact-head evidence after trusted code reaches the default branch |
| Scheduled Context/Producer slots | Select one target and implement one narrow change |
| Scheduled Reviewer slot | Review scope, diff, issue fit, safety and current technical evidence |
| Scheduled Closer slot | Re-check stable head, discussion and evidence before one controlled merge |
| Private Brain | Compact routing, durable rules and cross-project rollup only |

Current GitHub PR and issue state always overrides copied lane or rollup text.

## Shadow states

The gate reports exactly one state:

- `WAITING_CI`: at least one required workflow is missing, queued, running, cancelled, skipped or otherwise not successfully completed for the exact head.
- `FIX_NEEDED`: at least one required latest exact-head workflow has a concrete failing conclusion.
- `CI_GREEN`: every required workflow for the changed scope has a successful latest run for the exact head.
- `UNSUPPORTED_SCOPE`: the gate cannot safely classify the PR scope, for example because the changed-file list is empty.

`CI_GREEN` is technical evidence only. It is not semantic approval, merge authorization, physical-device evidence or permission to bypass Reviewer and Closer.

## Required evidence

The source contract is `docs/WORKFLOWS.md`.

Baseline for every PR:

- PR Change Scope
- Pull Request Quality
- Repo Audit
- Phase 0 CI Validation

Additional cases:

- Documentation and project-control changes require Docs Consistency.
- Changes under `.github/workflows/**` also require Workflow Lint.

The standalone Swift workflow may be displayed or used as supporting evidence, but the shadow gate does not invent requirements that are absent from the repository workflow contract.

## Exact-head rule

The evaluator requests workflow runs for the current pull-request head SHA and filters every run again by `head_sha`. For each required workflow name, only the newest exact-head run is used.

Consequences:

- a green old-head run cannot authorize a changed PR;
- a newer queued or failed run supersedes an older successful run with the same name;
- cancelled or skipped required runs remain `WAITING_CI` rather than being treated as success;
- repeated workflow completions recompute the whole required set instead of trusting only the triggering workflow.

## Idempotent status comment

The gate owns one PR comment containing this hidden marker:

```html
<!-- igentic-pr-autonomy-gate -->
```

A later run updates that comment only when its content changed. It selects only a marker comment owned by GitHub Actions, so copied marker text in contributor comments is not overwritten.

## Separated trust boundaries

Candidate code and privileged reconciliation are intentionally handled by different workflows.

### Read-only candidate tests

`Repo Audit` runs on pull requests and checks out the candidate merge ref. It executes:

```bash
python3 scripts/validate_repo_structure.py
python3 scripts/autonomy/test_evaluate_pr.py
```

Its workflow permission is `contents: read` only. It does not grant issue, pull-request, Actions or branch write permission, and it does not reference or pass an additional secret to candidate code.

### Privileged shadow gate

`PR Autonomy Gate` has no `pull_request` or `pull_request_target` trigger. It runs only on:

- completion of relevant validation workflows;
- manual dispatch;
- low-frequency scheduled reconciliation.

The privileged job:

- executes only the evaluator stored on the trusted default branch;
- fetches the default branch, never the pull-request head;
- does not restore or consume pull-request caches;
- does not download or execute pull-request artifacts;
- uses only the automatic `GITHUB_TOKEN`;
- restricts permissions to Actions read, contents read, pull requests read and issues write;
- performs GitHub API requests only against the current repository;
- uses concurrency to avoid overlapping reconciliation writes.

The privileged job must never:

- merge or enable auto-merge;
- change a branch or commit;
- close an issue or pull request;
- create or remove labels;
- write to the private Brain or another repository;
- execute untrusted PR code, caches or artifacts;
- claim signing, device or real model evidence.

## Slot integration

Until the shadow gate is proven in repeated real cycles:

1. Slot30 continues to reconcile raw current-head workflow evidence.
2. Slot18 may use the gate as a compact index but must independently inspect the PR, changed files, issue, comments, reviews and review threads.
3. Slot24 may merge only after a stable-head recheck and an explicit semantic `READY_FOR_CLOSE` decision.
4. A stale private lane cannot overrule newer current GitHub evidence.

Promotion beyond shadow mode requires separate reviewed scope and evidence from multiple correct cycles. Auto-merge, automatic target selection and cross-repository writes are explicitly outside version 1.

## Validation

```bash
python3 scripts/autonomy/test_evaluate_pr.py
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

A workflow-changing PR must additionally pass Repo Audit with the evaluator tests, Workflow Lint and all other checks required by `docs/WORKFLOWS.md` for its exact head. No earlier-head result may authorize the current head.