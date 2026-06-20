# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-20

## Source-of-truth contract

Current GitHub source overrides this file, Brain and memory. A merged or closed target may never be selected again from stale control text.

## Current operating mode

Mode: `HYBRID_PERSISTENT_LANE_V5`.

- iGentic uses Brain issue #25 as its persistent lane bus.
- Exactly one ACTIVE target is allowed.
- An existing open PR takes priority over selecting a new implementation or documentation target.
- Public GitHub Actions remain independent validation evidence.
- Pokekartenkiste remains outside this task.

## Recently completed

- PR #60 removed raw task text from AuditLog and merged as `ba562376fdb019ab20af19d2d8f68a1e6d626c90`.
- PR #61 added the metadata-only LocalModelRuntime contract and merged as `a7ff62463a27e707b2fd5f1b431cbb426ffba35d`.
- Issues #25, #29, #58 and #59 are closed completed for their documented scope.
- No physical-device, signing, benchmark or real model result is claimed.

## ACTIVE target

PR #49 `chore(deps): bump actions/checkout from 6 to 7`.

Verified current state:

- Base: `main`
- Head branch: `dependabot/github_actions/actions/checkout-7`
- Head SHA: `60a1821c975d18fe9a4b466891276c3340462f65`
- Scope: exactly `.github/workflows/unpack-bootstrap-zip.yml`
- Diff: `actions/checkout@v6` to `actions/checkout@v7`
- PR is open and not Draft.
- Branch is diverged: one commit ahead and 39 commits behind current `main`.
- Current-head workflow evidence includes successful PR Change Scope, Pull Request Quality, Docs Consistency, Repo Audit, Workflow Lint, Phase 0 CI Validation and Swift runs.
- GitHub currently does not report the PR as mergeable; refresh or conflict resolution is required before any merge decision.

## Current producer question

Determine the safest in-place path for PR #49:

1. re-read current PR head, diff, review threads and workflow evidence,
2. verify whether Dependabot can refresh the branch automatically,
3. otherwise prepare an exact refresh/recreate recommendation without creating a parallel PR,
4. preserve the one-file workflow dependency scope,
5. move the lane to independent review only after the branch is current and mergeability is resolved.

## Allowed scope

- PR #49 metadata, branch state, current workflow evidence and the one-line checkout reference.
- No product Swift implementation.
- No unrelated workflow edits.

## Stop rules

Do not:

- merge while `mergeable` is false or branch state is unresolved,
- create a duplicate PR for the same dependency bump,
- claim checks that were not observed for the current head,
- add secrets, signing files, private data, networking, providers, persistence, model calls or App Intents,
- touch Pokekartenkiste.

## QUEUED next target

Issue #6 `Research: Add App Intents safety notes for draft-first action patterns` remains the next documentation candidate only after PR #49 is merged, closed or explicitly blocked.

Preferred future file:

```text
docs/app-intents-safety.md
```

Issue #6 must remain documentation-only and source-linked; it must not add App Intents code or imply that real actions are implemented.

## Expected terminal result

```text
PR_REFRESHED
READY_FOR_REVIEW
WAITING_RUNNER
FIX_NEEDED
WRITE_SKIPPED
```
