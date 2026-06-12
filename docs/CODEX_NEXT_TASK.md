# Codex Next Task

Repository: `pokekarten/igentic-iphone`

## Task

Fix `AuditLog` thread safety before expanding the agent runtime.

## Why this task is first

A code audit identified `AuditLog` as the most important current risk: it is marked `@unchecked Sendable` while storing mutable events in a plain array. Because `AgentKernel` can be used from concurrent contexts, this must be fixed before adding more async runtime, approval or delegation behavior.

This is intentionally a small security-first task.

## Base branch

`main`

## Working branch

`codex/auditlog-thread-safety`

## Allowed files

Codex may only create or modify:

```text
ios/Sources/AgentCore/AuditLog.swift
ios/Tests/AgentCoreTests/AuditLogTests.swift
PROJECT_STATE.md
docs/CODEX_NEXT_TASK.md
```

Do not modify `README.md`, workflows, package layout or unrelated agent files.

## Required implementation

Choose one simple approach:

1. make `AuditLog` an `actor`, or
2. keep it as a final class but protect the mutable event array with `NSLock`.

Prefer the smallest change that keeps the current synchronous `AgentKernel` API working. If making `AuditLog` an actor requires broad async changes, use `NSLock` instead.

## Required behavior

- Concurrent calls to `record(_:)` must not race.
- `allEvents()` must return a snapshot copy.
- Existing public behavior should remain the same.
- Do not remove audit events or weaken privacy semantics.

## Required tests

Add tests that verify:

- events can still be recorded and read,
- concurrent recording does not lose events,
- returned events are a stable snapshot.

## Required validation

```bash
python scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

## Stop conditions

Stop and report clearly if:

- Swift tests cannot run because Swift is unavailable,
- the fix requires changing more than the allowed files,
- concurrency tests are flaky and cannot be made deterministic,
- unexpected build artifacts, secrets or model files appear.

## Draft PR body must include

- summary,
- changed files,
- validation output,
- why the chosen thread-safety approach was used,
- next recommended security task.

## Suggested next task after this PR

Import or implement `ApprovalManager` and make `AgentKernel` block or return an approval-required response when approval is `.pending` or `.rejected`, before adding any real App Intent execution.
