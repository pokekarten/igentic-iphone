# GitHub Actions Autonomy Control

Last reviewed: 2026-06-22

## Purpose

The iGentic autonomy control plane combines deterministic GitHub Actions with five scheduled tasks. GitHub Actions provide exact-head technical evidence. Scheduled tasks select one target, implement one bounded change, perform independent semantic review, close safely and reconcile state.

The control plane does not permit models or scheduled tasks to bypass deterministic policy, approval, schema validation, audit or execution boundaries.

## Responsibility split

| Surface | Responsibility |
| --- | --- |
| GitHub issues | Public scope, acceptance criteria, validation and stop rules |
| Pull requests | Reviewable implementation unit and current head SHA |
| GitHub Actions | Build, tests, repository structure, documentation, PR quality and changed-file validation |
| PR Autonomy Gate | Aggregate required exact-head technical evidence into one idempotent marker |
| Slot00 Director | Reconcile state and select exactly one target |
| Slot12 Producer | Implement one bounded artifact and open/adopt one Draft PR |
| Slot30 Validate + Review | Reconcile required checks and independently review semantics and safety |
| Slot42 Closer | Mark Ready, re-check stable head, merge once and synchronize terminal state |
| Slot54 Sequencer | Reconcile lane/rollup and count complete autonomous cycles |
| Private Brain | Compact mutable routing and rollup state only |

Current GitHub source always overrides copied lane, rollup or repository text.

## Five-task platform contract

The active scheduled product cycle is:

```text
00 Director
12 Producer
30 Validate + Review
42 Closer
54 Sequencer
```

The platform limit is five active tasks. A new active role requires replacing one of these five through an explicit reviewed automation update. Historical dedicated Reviewer, Validation Watcher, Context, Blocker Escape, Backlog Failover and Hygiene tasks remain disabled.

Exactly one product target and at most one implementation PR may be active.

## Legal transition contract

```text
CONTEXT_PENDING/CONTEXT
-> PRODUCER_PENDING/PRODUCER
-> REVIEW_PENDING/REVIEWER
-> CLOSER_PENDING/CLOSER
-> COMPLETE/CONTEXT
```

- Slot00 owns context selection and routing repair.
- Slot12 owns implementation only.
- Slot30 owns both technical reconciliation and independent semantic review.
- Slot42 owns Ready, merge and terminal synchronization.
- Slot54 owns rollup reconciliation and cycle measurement.

No task may perform the next role's work in the same run.

## PR Autonomy Gate

The metadata-only gate reports one state for the exact PR head:

- `WAITING_CI`: one or more required workflows are missing, queued, running, cancelled, skipped or otherwise incomplete;
- `FIX_NEEDED`: a required latest exact-head workflow has a concrete failure;
- `CI_GREEN`: all required workflows for the changed scope succeeded;
- `UNSUPPORTED_SCOPE`: the gate cannot safely classify the changed scope.

`CI_GREEN` is technical evidence only. It is not semantic approval, merge authorization, physical-device evidence or permission to bypass Slot30 or Slot42.

## Required evidence

The source contract is `docs/WORKFLOWS.md`.

Required for every PR:

- PR Change Scope
- Pull Request Quality
- Repo Audit
- Phase 0 CI Validation

Additional cases:

- Docs Consistency for documentation and project-control changes;
- Workflow Lint for workflow changes.

Standalone Swift is supporting evidence only. It cannot block when the required exact-head Phase 0 result is successful.

## Exact-head rule

Only the newest workflow run for the current PR head may be used.

Consequences:

- old-head success never authorizes a changed PR;
- a newer queued or failed run supersedes earlier success;
- cancelled or skipped required runs remain incomplete;
- Ready or merge requires a fresh same-head recheck;
- merge uses `expected_head_sha`.

## Trust boundaries

Candidate PR code and privileged gate reconciliation remain separated.

The privileged gate:

- runs trusted default-branch code only;
- never checks out or executes PR code, caches or artifacts;
- may read Actions, contents and PR metadata and update its single marker comment;
- cannot merge, mutate refs, close issues, select targets or write private Brain state;
- cannot claim model, signing or physical-device evidence.

Scheduled tasks:

- use current GitHub source before Brain or memory;
- act only in their authorized stage;
- make at most one product mutation before readback;
- do not download successful logs;
- fetch detailed logs only for a concrete current-head failure;
- stop on API `403` or `429` without probing alternate mutation endpoints.

## Combined Slot30 gate

Slot30 replaces the old split Validation Watcher and Reviewer roles.

It must:

1. verify exact target, head, draft state and complete scope;
2. reconcile all required current-head workflow results;
3. independently inspect the issue, PR body, full diff, comments, reviews and threads;
4. review acceptance criteria, safety, privacy, fail-closed behavior and tests;
5. route one result:
   - `WAITING_RUNNER`;
   - `FIX_NEEDED` back to Producer;
   - `READY_FOR_CLOSE` to Closer;
   - `STATE_SYNC_READY` to Closer;
   - `WAITING_API` or `OWNER_BOUNDARY` when proven.

It never implements or merges.

## Slot42 closure gate

Slot42 replaces the old Slot24 closer number.

It must:

1. require same-head `READY_FOR_CLOSE` or `STATE_SYNC_READY` authorization;
2. re-read the exact PR and current required evidence;
3. mark Draft Ready only when all gates pass;
4. re-check the unchanged head and discussion state;
5. squash-merge at most one PR with expected-head protection;
6. confirm terminal GitHub state and changed content on `main`;
7. close the linked issue only when acceptance criteria are source-backed;
8. route the lane to `COMPLETE/CONTEXT`.

It never selects the next target.

## Autonomous-cycle measurement

Slot54 counts a complete autonomous cycle only when all of these are source-backed:

- one target selected without duplicate scope;
- at most one implementation PR;
- bounded allowlisted files;
- persisted Producer result;
- current-head required technical checks;
- independent Slot30 semantic review;
- expected-head closure or accurate terminal synchronization;
- final GitHub readback;
- private lane and rollup synchronization;
- no interactive repair during the counted cycle.

The consecutive count resets for duplicate PRs, stale-head authorization, unsafe mutation, missing terminal readback or unrepaired lane/rollup drift.

After three consecutive complete untouched cycles, Slot54 may record `AUTONOMY_PROVEN=three_cycles` and notify the owner once. It does not enable additional tasks.

## Resource-aware operation

1. Exactly one target and one implementation PR maximum.
2. Queued runners are `WAITING_RUNNER`, not defects.
3. No no-op commit, branch rewrite or retry solely to trigger CI.
4. Connector operations stay serial and lane-first.
5. Successful logs are not downloaded.
6. API `403` or `429` stops the run as `WAITING_API`.
7. Adding a sixth role is impossible without replacing one active task.
8. Pokekartenkiste remains paused and cannot consume an iGentic task.
9. Playbook and SLM Lab remain support repositories and cannot become implicit product targets.

## Validation

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

Documentation changes must pass the exact-head checks defined in `docs/WORKFLOWS.md`. No earlier-head result may authorize the current head.
