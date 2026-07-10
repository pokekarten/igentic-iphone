# MemoryStore integration decision

Status: decided — deliberate pre-integration stub

## Decision

`MemoryStore` is intentionally not wired into `AgentKernel` or any other
live authorization path at this time. It is built ahead of integration,
following the same pattern as `DelegationBroker`.

## Rationale

- No accidental unclassified-data leak into the kernel while the
  classification design (how a stored `value: String` gets a
  `DataClassification` before persistence) remains undecided.
- Defers integration until the actual memory use case is concrete
  enough to shape the scope design properly.
- Keeps exactly one active iGentic implementation target free for the
  CoreML feasibility work.

## Follow-up

A future issue must be opened before `MemoryStore` is wired into
`AgentKernel`. That issue must specify:

- how each stored value receives a `DataClassification`,
- whether `MemoryEntry` needs a `dataSensitivity` field akin to
  `AuditEvent`,
- test coverage for classification thresholds and scope isolation,
  in addition to baseline `MemoryStoreTests.swift` coverage.

This decision does not authorize implementation.
