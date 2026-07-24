# Concurrency primitive decision

Status: decided — keep NSLock under current targets

## Decision

`LockedBox`, `AuditLog`, `ToolRegistry`, `MemoryStore`, and related lock-protected AgentCore types continue to use `NSLock` with `@unchecked Sendable` under the current deployment targets.

## Rationale

- `Package.swift` currently targets iOS 17 and macOS 14.
- `Synchronization.Mutex` is a compiler-checked alternative, but it requires iOS 18 / macOS 15 or newer.
- Under the current platform envelope, `NSLock` remains the correct choice.
- `Mutex` becomes a candidate only if the minimum deployment target is deliberately raised in a separate decision.

## Follow-up

A future platform-target decision is required before any switch from `NSLock` to `Mutex`.
