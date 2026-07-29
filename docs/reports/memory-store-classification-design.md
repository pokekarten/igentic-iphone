# MemoryStore classification and retention design

Status: decided — design-only predecessor for implementation
Date: 2026-07-29
Scope: `pokekarten/igentic-iphone`

## Decision summary

`MemoryStore` must remain a pre-integration stub until the later wiring issue is opened, but the storage model itself should already carry explicit data-sensitivity metadata.

The safe design is:

- `MemoryEntry` gains a `dataSensitivity: DataSensitivityLevel` field.
- The classification is assigned at write time, not inferred later from stored text.
- `restrictedSensitiveData` (`Level 4`) is rejected and must not be stored.
- `.session` vs `.task` scope isolation is necessary, but not sufficient on its own.
- Sensitivity also affects retention and deletion behavior.

This keeps `MemoryStore` aligned with the existing `AuditEvent.dataSensitivity` pattern and prevents unclassified or highly sensitive content from becoming durable memory by accident.

## Why this is the right boundary

The current store only tracks `scope`, `key`, `value`, `createdAt`, and `updatedAt`. That is too little for a later `AgentKernel` wiring because the kernel already reasons in terms of `DataClassification` and `DataSensitivityLevel`.

A memory entry without explicit sensitivity metadata would create two problems:

1. the store could not report what kind of data it holds;
2. retention, deletion and future diagnostics could not distinguish benign memory from sensitive memory.

The repo already uses sensitivity metadata in `AuditEvent`, so extending memory with the same concept is the least surprising and most auditable shape.

## Storage rule

### Allowed

Memory may be stored when the effective classification is:

- `publicData`
- `lowRiskAppData`
- `contextualPrivateData`
- `highlyPrivateData`

### Blocked

Memory must be rejected when the effective classification is:

- `restrictedSensitiveData`

That threshold is strict enough to prevent the highest-risk content from entering durable memory, while still allowing lower-risk operational memory to exist with explicit sensitivity metadata.

## Scope and retention rule

`MemoryScope` continues to matter:

- `.task` is ephemeral and is cleared at the end of the task boundary.
- `.session` may survive longer, but only for data that remains within the allowed storage threshold.

Classification adds a second gate on top of scope:

- higher sensitivity can require shorter retention,
- sensitive entries must be deletable by scope,
- and future kernel wiring must not treat memory presence as permission.

In other words, scope controls the lifetime container; classification controls whether the value may exist at all and how cautiously it may be retained.

## Deletion / retention behavior

- `delete(scope:)` remains valid for all scopes.
- No classification level should make deletion impossible.
- Retention policy may later be tightened per sensitivity, but that must happen in the kernel integration issue, not by silently changing the stub into an authority layer.
- A stored entry never grants delegation, approval, or execution permission.

## Required tests before wiring

Before `MemoryStore` is wired into `AgentKernel`, the implementation issue must include tests for:

- storing each allowed classification level with the expected `dataSensitivity` metadata;
- rejecting `restrictedSensitiveData` at write time;
- preserving `.session` / `.task` separation;
- deleting one scope without affecting the other;
- ensuring the store remains non-authoritative and does not influence approval or delegation decisions;
- ensuring repeated writes update the same entry in the same scope/key without dropping the assigned sensitivity metadata.

## Follow-up implementation shape

The later implementation issue should make `AgentKernel` compute the effective classification, then pass it into `MemoryStore` as explicit metadata.

That issue must still preserve the current contract:

- memory is optional and scoped,
- sensitive data never becomes permission,
- and the kernel remains the sole policy authority.

## Definition of done for this design

- The storage threshold is explicit.
- The retention rule is explicit.
- The test expectations are explicit.
- The document can be used as the exact predecessor for a future `MemoryStore` wiring implementation issue.