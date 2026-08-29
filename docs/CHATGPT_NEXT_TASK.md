# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Source-of-truth contract

Current verified GitHub source is authoritative for pull requests, issues, branches, checks, merged state and active work.

This file contains durable execution rules only. It must not be treated as a live task queue and must not store an authoritative current PR number, branch head, mergeability result or scheduler lane stage.

Private Brain notes, old task envelopes, memory and historical automation state are supporting context only. They never override live GitHub.

A merged, closed, superseded or otherwise terminal target must never be revived from stale text.

## Operating mode

Mode: `MANUAL_GITHUB_FIRST`.

The historical five-slot/private-Brain autonomy controller is suspended. Slot00/12/30/42/54 role sequencing is not an active iGentic execution contract and must not be recreated unless the owner explicitly authorizes a new migration.

Normal work is direct and source-backed:

1. read live GitHub;
2. adopt an existing open implementation PR if one exists;
3. otherwise select one smallest safe issue whose ordering constraints are satisfied;
4. implement, validate, review and close that one bounded change;
5. re-read GitHub before selecting more work.

## WIP rules

- Exactly one active iGentic implementation target at a time.
- At most one active iGentic implementation PR at a time.
- Existing open implementation PRs take priority over selecting new work.
- Do not create placeholder, no-op or duplicate PRs merely to generate activity.
- Waiting for a required runner is not a code defect and does not justify changing the branch.
- A settings, hardware, license or external-host blocker must remain explicit rather than being converted into unrelated repository code.
- `agentic-dev-playbook`, `agentic-slm-lab`, `agentic-private-brain` and other support repositories are never implicit iGentic product targets.

## Mandatory reconciliation preflight

Before a product mutation:

```text
1. Read current main and current open PRs.
2. Read the exact selected issue plus relevant current comments.
3. Confirm ordering prerequisites and stop rules.
4. Search for an equivalent open PR or branch before creating another.
5. Record the exact starting main SHA and, after writing, the exact branch head.
6. Confirm the proposed change stays inside the selected scope.
7. If the target is already terminal or the prerequisite is unmet, do not mutate product code.
```

## Review and merge contract

For an implementation PR:

- read the complete current-head diff;
- read issue/PR comments, reviews and open review threads;
- require evidence for the exact current head;
- distinguish semantic review from CI status;
- fix only concrete current-head defects;
- merge with expected-head protection only after the required evidence is terminal and green.

Do not create a new commit solely to retrigger already-valid CI.

## Required technical evidence

The workflow source contract is `docs/WORKFLOWS.md`.

Baseline repository checks include:

- PR Change Scope;
- Pull Request Quality;
- Repo Audit;
- Phase 0 CI Validation.

Additional checks apply by scope, including Docs Consistency for project-control/documentation changes and Workflow Lint for workflow changes.

Baseline local commands are:

```bash
python3 scripts/validate_repo_structure.py
```

Swift source changes normally also require:

```bash
cd ios && swift test
```

The iOS App Wrapper is required when the scoped change can affect the diagnostic app target. Compile/simulator evidence is platform evidence only and is not physical-device readiness evidence.

## Resource-aware behavior

```text
required check queued/running -> WAITING_RUNNER
API 403/429 -> WAITING_API
concrete current-head failure -> FIX_NEEDED
required checks green + semantic review clean -> READY_FOR_CLOSE
terminal GitHub state -> COMPLETE
settings/hardware/license boundary -> OWNER_OR_EXTERNAL_BOUNDARY
```

Rules:

- Do not rewrite a correct branch while runners are merely queued.
- Fetch detailed logs only for a concrete failure or when needed to distinguish a real blocker from runner delay.
- On an unavailable mutation API, do not probe risky alternate write paths.
- Do not claim work happened on a physical Mac, device, account setting or gated upstream service without source-backed evidence from that environment.

## Pull-request contract

Every iGentic PR body should make these sections explicit:

```text
Summary
Scope
Validation
Safety
Follow-up
```

It should name `python3 scripts/validate_repo_structure.py` and either `cd ios && swift test` or an explicit reason Swift tests do not apply.

## Product safety boundaries

Models may propose. Deterministic policy, approval, schema validation, execution boundaries and audit remain authoritative.

Do not add or claim without an explicitly source-backed scope:

- networking or external providers;
- real model execution;
- persistence of private user data;
- App Intents/Siri execution or side effects;
- signing files, entitlements or provisioning profiles;
- credentials, secrets, real messages, contacts, files or identifiers;
- physical-device performance/readiness from host or simulator evidence;
- a second active implementation PR.

For Safe Action work, a platform permission grant is setup/access control, never approval for a specific action. Existing-reminder content must not be read merely because EventKit Full Access technically permits it. A real reminder save remains a separately reviewed side-effect boundary and must not be inferred from completion of approval, destination-resolution or TOCTOU components.

## Research execution boundary

Untouched model baselines must preserve their frozen benchmark, model revision, decoding and seed contracts. Do not repair weak outputs, select favorable cases/seeds or substitute a newer repository/model SHA without re-establishing the execution gate.

Host evidence remains host evidence. Physical iPhone claims require physical-device evidence.

## Completion transaction

After a merge or source-backed issue closure:

```text
1. Re-read the PR/issue and confirm terminal GitHub state.
2. Confirm the expected content exists on main.
3. Confirm any linked issue closed only when its acceptance criteria were satisfied.
4. Clear the completed work from the mental/automation queue.
5. Re-read open PRs and issue ordering before selecting another target.
```

## Expected terminal results

```text
PR_OPENED
VALIDATION_EVIDENCE
REVIEW_EVIDENCE
READY_FOR_CLOSE
MERGED_AND_CONFIRMED
STATE_RECONCILED
WAITING_RUNNER
WAITING_API
OWNER_OR_EXTERNAL_BOUNDARY
NEXT_TARGET_NEEDED
NO_TRIGGER
```
