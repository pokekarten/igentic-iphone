# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Source-of-truth contract

Current verified GitHub source overrides this file, Brain and memory for pull-request, issue, branch, check and merge state.

The only mutable source for the active iGentic target and lane stage is the authorized private Brain lane. This file defines durable execution rules only. It must not store a live PR number, current head SHA, mergeability result or current lane stage.

A merged or closed target must never be revived from stale text.

## Operating mode

Mode: `IGENTIC_FIVE_TASK_AUTONOMY`.

The platform currently permits five active scheduled tasks. The complete product cycle is therefore:

```text
00 Director
12 Producer
30 Validate + Review
42 Closer
54 Sequencer
```

Adding another active task requires deliberately replacing one of these five. Historical context, reviewer, validation-watcher, blocker, failover and hygiene automations remain disabled unless a reviewed migration explicitly replaces an active task.

Operating rules:

- Exactly one active iGentic implementation target is allowed.
- At most one active iGentic implementation PR is allowed.
- Existing open iGentic PRs take priority over selecting new issues.
- When no PR exists, select one smallest safe source-backed iGentic issue.
- Pokekartenkiste remains controlled by its paused Brain lane and outside this product cycle.
- `agentic-dev-playbook` and `agentic-slm-lab` are support repositories, never implicit product targets.
- GitHub Actions provide technical evidence; scheduled tasks provide routing, implementation, semantic review and controlled closure.

## Five-task roles

### Slot00 Director

- reconciles stale, terminal or missing targets;
- verifies that no duplicate target or PR exists;
- selects exactly one next safe target only in a context stage;
- writes the complete target envelope to the private lane;
- never edits product files, reviews or merges.

### Slot12 Producer

- acts only in `PRODUCER_PENDING/PRODUCER`;
- adopts an equivalent branch or PR instead of creating parallel scope;
- changes only the allowlisted files;
- creates or updates exactly one bounded Draft PR;
- re-reads branch files and PR head;
- routes the exact head to `REVIEW_PENDING/REVIEWER`;
- never reviews or merges its own work.

### Slot30 Validate + Review

- acts only in `REVIEW_PENDING/REVIEWER`;
- combines current-head workflow reconciliation with independent semantic review;
- reads the issue, PR body, complete diff, comments, reviews and review threads;
- routes concrete defects back to the Producer;
- routes a clean exact head to `CLOSER_PENDING/CLOSER`;
- never implements or merges.

### Slot42 Closer

- acts only in `CLOSER_PENDING/CLOSER` with explicit same-head authorization;
- marks a Draft Ready only after all gates pass;
- re-checks the stable head and current required evidence;
- squash-merges at most one PR with expected-head protection;
- confirms terminal GitHub state and synchronizes the lane to `COMPLETE/CONTEXT`;
- never selects the next target.

### Slot54 Sequencer

- reconciles the active lane, rollup and paused lane;
- verifies legal transitions and detects drift or duplicate scope;
- records complete autonomous cycles only from source-backed evidence;
- does not implement, review or merge;
- after three consecutive complete untouched cycles, may record `AUTONOMY_PROVEN=three_cycles` and notify the owner once.

## Legal stage sequence

```text
CONTEXT_PENDING/CONTEXT
-> PRODUCER_PENDING/PRODUCER
-> REVIEW_PENDING/REVIEWER
-> CLOSER_PENDING/CLOSER
-> COMPLETE/CONTEXT
```

Alternative safe states:

```text
WAITING_RUNNER
WAITING_API
BLOCKED_TOOL_RETRYABLE
OWNER_BOUNDARY
```

A non-authorized task reads the lane once, returns `NO_TRIGGER` and performs no product read or mutation.

## Mandatory reconciliation preflight

Before an authorized action:

```text
1. Read the private lane.
2. Confirm stage and next role authorize this task.
3. Read the exact named GitHub target.
4. Confirm repository, target kind, number, state, lane ID and revision.
5. For PRs, confirm current head, draft state and complete changed-file scope.
6. Confirm no duplicate implementation target, PR or equivalent branch exists.
7. Confirm the action stays inside allowed files and stop rules.
8. If the target is terminal, missing or mismatched, perform no product mutation and route repair.
```

## Target envelope

The private lane must carry:

```text
TARGET_REPO
TARGET_KIND
TARGET_NUMBER
TARGET_BRANCH when applicable
TARGET_BASE_SHA when applicable
TARGET_HEAD
TARGET_STATE
LANE_ID
STAGE
REVISION
ALLOWED_FILES
ACCEPTANCE_CRITERIA
VALIDATION
STOP_RULES
NEXT_ALLOWED_ROLE
WATCHED_TARGETS
```

For a PR target, all review and closure evidence must match the current live head SHA.

## Required technical evidence

The source contract is `docs/WORKFLOWS.md`.

Baseline required checks:

- PR Change Scope
- Pull Request Quality
- Repo Audit
- Phase 0 CI Validation

Additional checks:

- Docs Consistency for documentation and project-control changes;
- Workflow Lint for `.github/workflows/**` changes.

Standalone Swift is supporting evidence only when required Phase 0 succeeds.

The `PR Autonomy Gate` marker is an index only. `CI_GREEN` is technical evidence, not semantic approval or merge authorization.

## Resource-aware behavior

```text
required check queued/running -> WAITING_RUNNER
API 403/429 -> WAITING_API
concrete current-head failure -> FIX_NEEDED
required checks green + semantic review clean -> READY_FOR_CLOSE
terminal GitHub state -> COMPLETE
```

Rules:

- Runner waiting is not a code defect.
- Do not retry, rewrite a branch or create a no-op commit to retrigger CI.
- Connector calls are serial and lane-first.
- Successful job logs are not downloaded.
- Detailed steps or logs are fetched only for a concrete current-head failure.
- One authorized Producer or Closer performs at most one product mutation before readback.
- On API `403` or `429`, stop and do not probe alternate mutation endpoints.

## Pull-request contract

Every iGentic PR body must contain:

```text
Summary
Scope
Validation
Safety
Follow-up
```

It must name `python3 scripts/validate_repo_structure.py` and either `cd ios && swift test` or an explicit reason that Swift tests are not applicable.

## Safety boundaries

Do not add or claim:

- networking or external providers;
- real model execution unless explicitly authorized by a later scoped issue;
- persistence of private user data;
- App Intents execution or side effects;
- signing files, entitlements or provisioning profiles;
- physical-device performance or readiness without physical-device evidence;
- credentials, secrets, real messages, contacts, files or identifiers;
- Pokekartenkiste, Playbook or SLM-lab product mutations from this lane;
- a second active implementation PR.

Models may propose. Deterministic policy, approval, schema validation, execution and audit remain authoritative.

## Completion transaction

After merge or source-backed issue closure:

```text
1. Re-read the target and confirm terminal GitHub state.
2. Confirm changed content on main when applicable.
3. Close the linked implementation issue only when acceptance criteria are satisfied.
4. Record terminal artifact and merge/closure evidence.
5. Increment lane revision and set COMPLETE/CONTEXT.
6. Preserve watched targets and clear the completed target as active work.
7. Re-read the lane.
8. Allow Slot00 to select the next target on its next authorized run.
```

## Current migration rule

The active control repair is iGentic PR #99 on branch `phase2/model-selection-engine-v3`. It is the sole active implementation track.

Issue #88 is already terminal (`closed` / `completed`). Its untouched-baseline provenance scope is closed history, not the next active target, and it must not be implemented in the migration PR.

## Expected terminal results

```text
PR_OPENED
COLLISION_ADOPTED
WRITE_SKIPPED_IDENTICAL
VALIDATION_EVIDENCE
REVIEW_EVIDENCE
READY_FOR_CLOSE
MERGED_AND_SYNCED
STATE_SYNCED
WAITING_RUNNER
WAITING_API
BLOCKED_TOOL_RETRYABLE
OWNER_BOUNDARY
NEXT_TARGET_NEEDED
NO_TRIGGER
```