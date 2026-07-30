# MemoryStore integration decision

Status: decided — bounded local store, still pre-integration

## Decision

`MemoryStore` remains intentionally unwired from `AgentKernel` and all live authorization paths. The completed classification design now permits a small local store hardening slice, but it does not authorize kernel integration.

The store may carry explicit `DataSensitivityLevel` metadata and reject `restrictedSensitiveData` at write time. It remains in-memory, scoped, deletable, and non-authoritative.

## Implemented bounded slice

Issue #207 defines and implements the safe pre-integration boundary:

- `MemoryEntry` carries `dataSensitivity`.
- write-time sensitivity is explicit rather than inferred from stored text;
- `restrictedSensitiveData` is rejected before state mutation;
- session/task isolation and same-key update semantics remain intact;
- no disk/network persistence is added;
- no authorization, delegation, or routing decision consumes memory state.

## Why kernel integration remains deferred

The repository still needs a concrete runtime memory use case before `MemoryStore` is connected to `AgentKernel`. That future integration issue must define:

- where the kernel obtains the effective classification for a memory write;
- lifecycle and clearing semantics for task/session memory;
- whether diagnostics should expose aggregate memory metadata;
- how memory reads are scoped to the current task/session;
- tests proving memory state cannot change approval or delegation outcomes.

## Explicit stop rules

- Do not wire `MemoryStore` into `AgentKernel` from this decision.
- Do not add disk or network persistence here.
- Do not infer permissions from memory contents or metadata.
- Do not add retention timers until the concrete lifecycle is specified.
