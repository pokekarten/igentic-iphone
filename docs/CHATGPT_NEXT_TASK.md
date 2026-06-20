# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-20

## Source-of-truth contract

Current GitHub source overrides this file, Brain and memory. A merged PR or closed issue may never be selected again from stale control text.

## Current operating mode

Mode: `HYBRID_PERSISTENT_LANE_V5`.

- iGentic uses Brain issue #25 as its persistent lane bus.
- Exactly one ACTIVE target is allowed.
- Public GitHub Actions remain the independent code-validation environment.
- Pokekartenkiste remains outside this task.

## Recently completed

- PR #60 removed raw task text from AuditLog and merged as `ba562376fdb019ab20af19d2d8f68a1e6d626c90`.
- PR #61 added the metadata-only LocalModelRuntime contract and merged as `a7ff62463a27e707b2fd5f1b431cbb426ffba35d`.
- Issues #25, #29, #58 and #59 are closed completed for their documented scope.
- No physical-device, signing, benchmark or real model result is claimed.

## ACTIVE target

Issue #6 `Research: Add App Intents safety notes for draft-first action patterns`.

This is a documentation-only Phase 4 preparation task. It must explain safe future patterns without adding App Intents code or implying that real actions are implemented.

## Producer question

Create or update one source-linked safety document that covers:

- draft before execute,
- approval before critical actions,
- synthetic examples only,
- privacy and data-minimization boundaries,
- explicit separation between future research and current implemented behavior,
- what is not implemented.

## Allowed scope

Preferred file:

```text
docs/app-intents-safety.md
```

Update `README.md`, `ROADMAP.md` or `scripts/validate_repo_structure.py` only when a link or validation requirement is clearly necessary.

## Required evidence

- Re-read Issue #6 immediately before writing.
- Verify whether an equivalent document already exists.
- Use current official Apple documentation for claims about App Intents or platform behavior.
- Run or require `python3 scripts/validate_repo_structure.py` when repository structure changes.

## Stop rules

Do not add:

- App Intents code,
- signing files, entitlements or provisioning profiles,
- real actions or tool execution,
- networking, persistence or external providers,
- model calls or weights,
- secrets, device identifiers or real private data,
- Pokekartenkiste changes.

## Expected terminal result

```text
DOC_FIX_APPLIED
PR_OPENED
REVIEW_BLOCKER_FOUND
WRITE_SKIPPED
```
