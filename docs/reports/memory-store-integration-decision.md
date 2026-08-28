# MemoryStore integration decision

Status: decided — bounded read-only kernel metadata integration
Related issues: #120, #142, #207, #329

## Decision

`MemoryStore` may now be attached to `AgentKernel` as an optional, observational dependency for aggregate metadata only.

The bounded integration exposes exactly one count-only audit snapshot per handled task when a store is present:

`memoryStoreSessionCount=<n>,memoryStoreTaskCount=<n>`

This integration does not authorize memory reads into task context, automatic memory writes, lifecycle automation, persistence, or any memory-driven policy, approval, routing, delegation, tool, model, or execution decision.

## Completed prerequisites

The classification and store-hardening predecessors remain authoritative:

- Issues #120/#142 define the classification and retention design.
- `MemoryEntry` carries explicit `dataSensitivity` metadata assigned at write time.
- `restrictedSensitiveData` is rejected before store mutation.
- Session/task isolation and same-key update semantics remain intact.
- Issue #207 implements that bounded local-store contract without kernel wiring.

These rules are unchanged by the read-only integration.

## Implemented read-only boundary

Issue #329 defines the first `AgentKernel` connection:

- `AgentKernel` accepts optional `memoryStore: MemoryStore?`.
- When present, `handle()` reads only the counts of `.session` and `.task` entries.
- The kernel records one `.memoryStoreSnapshot` event containing only those two counts.
- Memory keys, values, per-entry sensitivity levels, identifiers and timestamps are not copied into audit output.
- When no store is supplied, no memory snapshot is emitted and the previous behavior is preserved.
- Memory presence does not change the `AgentResponse` for an otherwise identical request.
- Pending approval still stops later advisory/routing stages; memory metadata cannot create permission.

This follows the already-established ToolRegistry pattern of optional count-only observability while keeping the underlying component non-authoritative.

## Why content integration remains deferred

A concrete runtime memory use case is still required before stored values can participate in task execution.

Any later issue that proposes reading values into task/model context or writing task-derived values must separately define:

- the exact write trigger and source of the effective classification;
- task/session ownership and clearing semantics;
- read scoping and minimization rules;
- retention/deletion behavior per sensitivity;
- how stored text is prevented from becoming authorization or delegation authority;
- tests proving memory content cannot bypass policy or approval;
- diagnostic and audit redaction requirements.

None of those capabilities are implied by count-only observability.

## Explicit stop rules

- Do not automatically save task text or model output.
- Do not inject memory values into `TaskRequest`, policy inputs, approval requests, model-selection inputs, tool-selection inputs, routing inputs, or delegation inputs.
- Do not expose keys, values, IDs, timestamps or per-entry sensitivity metadata through the new audit snapshot.
- Do not add disk/network persistence or retention timers from this decision.
- Do not infer permission from memory presence, count, content, scope, or sensitivity.

## Validation contract

The read-only boundary requires regression coverage proving:

- aggregate session/task counts are emitted exactly once when a store is present;
- stored keys and values do not appear in audit messages;
- the same request produces the same route, policy and approval response with or without memory attached;
- no snapshot is emitted when the dependency is absent;
- pending approval prevents downstream RuntimeBudget/model-selection/routing stages even when memory is populated.

`MemoryStore` therefore moves from a completely unwired stub to a bounded observability dependency only. It is still not a source of task context or authority.
