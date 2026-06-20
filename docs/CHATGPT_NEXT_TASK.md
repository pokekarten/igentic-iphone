# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-20

## Source-of-truth contract

Current GitHub source overrides this file, Brain and memory for PR, issue, branch, check and merge state.

The only mutable source for the active iGentic target and lane stage is:

```text
pokekarten/agentic-private-brain issue #25
```

This file defines durable execution rules. It must not store a live PR number, current head SHA, mergeability result or current lane stage. A merged or closed target may never be selected again from stale text.

## Operating mode

Mode: `HYBRID_PERSISTENT_LANE_V5` with single-target-source hardening.

- Exactly one ACTIVE target is allowed.
- An existing open PR takes priority over selecting new work.
- When no open PR exists, choose one smallest safe source-backed issue.
- Public GitHub Actions remain independent validation evidence.
- Pokekartenkiste remains outside this task.

## Mandatory reconciliation preflight

Every iGentic slot must perform this check before acting:

```text
1. Read Brain issue #25.
2. Read the named GitHub target.
3. Confirm target state, kind and repository.
4. For PRs, confirm current head and changed-file scope.
5. Confirm the lane stage authorizes this role.
6. If target is merged, closed, missing or mismatched: do no product mutation and repair/route the lane.
```

Current GitHub source wins over all copied or remembered state.

## Lane roles

- Context selects one verified target and sets `PRODUCER_PENDING`.
- Producer creates at most one artifact or mutation and routes to review.
- Reviewer independently verifies and never implements.
- Closer merges, closes or synchronizes only after explicit reviewer authorization.
- Director and sequencer reconcile stale targets and invalid transitions; they do not implement product work.

## Target envelope

The lane issue must carry:

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

For issue targets, `TARGET_HEAD=none`. For PR targets, evidence and mutations must match the current head SHA.

## Evidence envelope

Before review or closure, record the applicable fields:

```text
TARGET_HEAD
CHANGED_FILES
COMMANDS_EXECUTED
COMMAND_RESULTS
WORKFLOW_RESULTS
REVIEW_THREADS
DRAFT_STATE
MERGEABILITY
EVIDENCE_SOURCE
```

Never claim commands or device behavior that were not actually observed.

## Safety boundaries

Do not add or claim:

- networking, providers or model calls,
- persistence of private data,
- App Intents implementation or real action execution,
- signing files, entitlements or provisioning profiles,
- physical-device performance or readiness,
- secrets or real private data,
- Pokekartenkiste changes.

## Validation contract

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

Use only the validation required by the changed scope. Documentation-only work normally requires repository-structure validation; Swift validation is required when Swift source changes.

## Completion transaction

After merge or issue closure:

```text
1. Re-read the target and confirm completion from GitHub.
2. Record the terminal artifact and merge/closure evidence.
3. Set the lane to COMPLETE.
4. Clear any assumption that the completed target remains active.
5. Re-read the lane and confirm revision/stage persistence.
6. Allow Context to select the next target.
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
OWNER_BOUNDARY
NEXT_TARGET_NEEDED
NO_TRIGGER
```