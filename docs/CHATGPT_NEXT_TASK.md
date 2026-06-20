# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-20

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, current `main`, workflow evidence, review threads and issue acceptance criteria.

## Current operating mode

Mode: `IGENTIC_CLOSE_AUDIT_TASK_TEXT_REDACTION`.

- iGentic is handled by the first half of the continuous ten-slot hourly cycle.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions remain the independent validation environment.
- Exactly one active implementation candidate is allowed.
- Do not select another slice while PR #60 remains open.

## Recently completed

- PR #55 `Issue #2: add contributor glossary` was squash-merged into `main` as `cbb1ecf8e10b0c8bb7ecd509aba2c35f1670e16f`.
- PR #56 `Clarify current AuditLog privacy behavior` was squash-merged into `main` as `421524c0709de166e0ab1e75ceb8585e3c98e1ef`.
- PR #57 was closed without merge because it was a parallel process-documentation candidate and must not displace product work.
- Issue #29 remains an owner/device boundary.

## Active target

Draft PR #60 `Issue #59: redact raw task text from AuditLog` is the only active iGentic implementation target.

Current head at creation: `8b5e3576c78206ac18e6bb0dab6dc252eda7efe9`.

Scope:

- `ios/Sources/AgentCore/AgentKernel.swift`
- `ios/Tests/AgentCoreTests/AuditPrivacyTests.swift`

Behavior:

- `.taskReceived` audit events use the fixed metadata-safe message `Task received.` instead of `task.userText`.
- Event type and data-sensitivity metadata remain available.
- Policy, approval and routing outcomes remain unchanged.
- A focused Swift regression test proves raw synthetic task text is absent from emitted audit messages.

## Required close gate for PR #60

Before merge:

1. base remains `main`,
2. head SHA remains stable,
3. changed files remain exactly the two scoped Swift files,
4. repository structure validation succeeds,
5. Swift tests and Swift build succeed on the current head,
6. PR quality and change-scope checks succeed,
7. no unresolved review thread or new source-backed blocker remains,
8. mark Ready only after the draft gate is satisfied,
9. re-check the same head and newly triggered automated review before merge.

Required validation:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

Do not treat an earlier failed superseded run as current if a later run for the same stable head succeeds.

## Sequence after PR #60

Only after PR #60 is merged or explicitly closed:

1. keep Issue #29 classified as an owner/device boundary,
2. inspect current open product issues and repository state,
3. select exactly one smallest safe deterministic or simulator-verifiable product slice,
4. do not revive PR #57 automatically; Issue #35 remains separate process work.

## Safety rules

Do not add:

- hardware probing or real performance measurements,
- CoreML, MLX, model weights or model loading,
- routing behavior or automatic external delegation,
- file access, databases or persistence,
- networking, external providers or model calls,
- secrets or real private data,
- App Intents, signing or physical-device success claims.

## Expected terminal result

One of:

- `MERGED`
- `REVIEW_BLOCKER_FOUND`
- `WAITING_CURRENT_HEAD_CHECKS`
- `FIX_APPLIED`
- `OWNER_DEVICE_STEP`
- `WRITE_SKIPPED`
