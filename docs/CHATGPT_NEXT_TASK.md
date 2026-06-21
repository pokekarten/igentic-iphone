# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-21

## Source-of-truth contract

Current GitHub source overrides this file, Brain and memory for pull request, issue, branch, check and merge state.

The only mutable source for the active iGentic target and lane stage is:

```text
pokekarten/agentic-private-brain issue #25
```

This file defines durable execution rules. It must not store a live PR number, current head SHA, mergeability result or current lane stage. A merged or closed target may never be selected again from stale text.

## Operating mode

Mode: `IGENTIC_FOCUSED_LANE_V6` with one target, exact-head evidence and resource-aware GitHub coordination.

- Exactly one active iGentic implementation target and one active implementation PR are allowed.
- An existing open iGentic PR takes priority over selecting new work.
- When no open PR exists, choose one smallest safe source-backed iGentic issue.
- Pokekartenkiste remains controlled by Brain issue #26 and outside this task.
- `agentic-dev-playbook` and `agentic-slm-lab` are separate support tracks. Their issues or PRs are never implicit iGentic product targets.
- Current GitHub source always overrides copied lane, project-file or remembered state.

## Core-canary activation

After the first live Autonomy Gate canary is verified, enable only these six core slots:

```text
00 Director + Context
12 Producer
18 Reviewer
24 Closer
30 Validation Watcher
54 Sequencer
```

Keep these four expansion slots disabled during the first three complete source-backed product cycles:

```text
06 Dedicated Context
36 Blocker Escape
42 Backlog Failover
48 Hygiene Auditor
```

Slot54 records complete consecutive cycles and may set `EXPANSION_READY=yes` after three. It does not enable expansion slots. Expansion requires a separate explicit automation update after evidence review.

## Mandatory reconciliation preflight

Every iGentic slot must perform this check before acting:

```text
1. Read Brain issue #25.
2. If NEXT_ALLOWED_ROLE does not authorize this slot, return NO_TRIGGER without product reads.
3. Read the exact named GitHub target only when authorized.
4. Confirm target state, kind, repository, lane ID and revision.
5. For PRs, confirm current head, draft state and complete changed-file scope.
6. Confirm there is no duplicate active implementation target or PR.
7. If the target is merged, closed, missing or mismatched: do no product mutation and repair or route the lane.
```

## Lane roles

Core-canary roles:

- Director + Context repairs routing, reconciles terminal or stale targets and selects one verified next target.
- Producer creates at most one verifiable artifact or product mutation and routes to review.
- Validation Watcher reconciles required exact-head workflow summaries and never implements.
- Reviewer independently verifies scope, semantics, required checks, comments, reviews and threads; it never implements.
- Closer marks Ready and merges only after explicit reviewer authorization and a stable-head recheck.
- Sequencer validates transitions, synchronizes compact rollup state and counts complete core cycles.

Expansion roles remain configured but disabled until the evidence threshold is reached:

- Dedicated Context separates target selection from Slot00 when additional capacity is justified.
- Blocker Escape preserves blocked work as watched and selects one safe alternative.
- Backlog Failover may self-seed one precise issue only when no suitable target exists.
- Hygiene Auditor repairs proven lane drift without implementing product work.

## Target envelope

Brain issue #25 must carry:

```text
TARGET_REPO
TARGET_KIND
TARGET_NUMBER
TARGET_HEAD
TARGET_STATE
LANE_ID
STAGE
REVISION
LAST_VERIFIED_AT
NEXT_ALLOWED_ROLE
```

For issue targets, `TARGET_HEAD=none`. For PR targets, evidence and mutations must match the current live head SHA.

## Evidence envelope

Before review or closure, record the applicable fields:

```text
TARGET_HEAD
CHANGED_FILES
COMMANDS_EXECUTED
COMMAND_RESULTS
WORKFLOW_RESULTS
GATE_MARKER_STATE
REVIEW_THREADS
DRAFT_STATE
MERGEABILITY
EVIDENCE_SOURCE
```

Never claim commands, workflow results or device behavior that were not actually observed.

## GitHub Actions and Autonomy Gate

The metadata-only `PR Autonomy Gate` is active on `main`.

Required exact-head evidence:

- PR Change Scope
- Pull Request Quality
- Repo Audit
- Phase 0 CI Validation
- Docs Consistency when applicable
- Workflow Lint when applicable

Standalone Swift is supporting evidence only when Phase 0 succeeds; it must not create a second macOS merge gate.

The gate uses required workflow-completion events as the normal path and one recovery schedule at minute 17 each hour. Its marker comment is an index only. `CI_GREEN` means technical evidence is green; it is not semantic approval or merge authorization.

The privileged gate executes trusted default-branch code only. It cannot merge, mutate refs, close issues, write Brain, select targets or execute pull-request code, caches or artifacts.

## Resource-aware behavior

```text
required check queued/running -> WAITING_RUNNER
API 403/429 -> WAITING_API
concrete current-head failure -> FIX_NEEDED
required checks green -> REVIEW_PENDING
semantic review green -> CLOSER_PENDING
terminal GitHub state -> COMPLETE
```

Rules:

- Runner waiting is not a code defect and does not trigger retry, no-op commit or branch rewrite.
- Connector calls are lane-first and serial.
- Successful job logs are not downloaded; detailed steps or logs are read only for a concrete latest-head failure.
- One authorized producer or closer performs at most one product mutation, followed by readback.
- On API `403` or `429`, stop the run, record `WAITING_API` when safe, respect retry/reset guidance and do not probe alternate endpoints.
- Scheduled reconciliation is recovery only; event-driven GitHub evidence is the primary technical path.

## Safety boundaries

Do not add or claim:

- networking, providers or model calls,
- persistence of private data,
- App Intents implementation or real action execution,
- signing files, entitlements or provisioning profiles,
- physical-device performance or readiness,
- secrets or real private data,
- Pokekartenkiste, playbook or SLM-lab mutations from the iGentic lane.

## Validation contract

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

Use only the validation required by the changed scope. GitHub Actions remain the authoritative execution evidence. Documentation-only changes require the repository checks defined in `docs/WORKFLOWS.md`.

## Completion transaction

After merge or issue closure:

```text
1. Re-read the target and confirm completion from GitHub.
2. Record the terminal artifact and merge or closure evidence.
3. Set the lane to COMPLETE and increment REVISION.
4. Clear any assumption that the completed target remains active.
5. Re-read the lane and confirm persistence.
6. Complete any explicit restore guard before selecting the next target.
7. For the initial V6 restore, enable the six core slots, keep expansion slots disabled and disable the migration watcher.
```

## Expected terminal results

```text
PR_OPENED
FILE_CHANGED
ISSUE_UPDATED
VALIDATION_EVIDENCE
REVIEW_EVIDENCE
READY_FOR_CLOSE
MERGED
CLOSED
STATE_SYNC
WAITING_RUNNER
WAITING_API
OWNER_BOUNDARY
NEXT_TARGET_NEEDED
NO_TRIGGER
```
