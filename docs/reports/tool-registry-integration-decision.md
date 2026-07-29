# ToolRegistry integration decision

Status: decided — pre-integration boundary specified, wiring deferred

## Decision

`ToolRegistry` remains a read-only, diagnostic-only component until the dedicated wiring issue is implemented. The repository now has a concrete boundary for how it may be surfaced later without turning metadata into execution permission.

## Phase 1 integration boundary

For the next implementation slice, `ToolRegistry` may only be threaded into `AgentKernel` as an optional, read-only dependency. The only permitted runtime effect is a single audit event that records the registry size, for example:

`toolRegistryToolCount=\(toolRegistry.allTools().count)`

This keeps the registry visible in diagnostics without changing routing or approval behavior.

### Explicit non-goals for this phase

- No tool invocation.
- No tool selection logic.
- No changes to `TaskRequest`, `TaskIntent`, `TaskRoute`, `AgentResponse`, `PolicyEngine`, or `ApprovalManager`.
- No App Intents integration.
- No dynamic authorization based on tool metadata.
- No attempt to infer a tool from user text.

### Tool selection rule

There is intentionally **no** tool-selection algorithm in this phase. Tool selection is a separate design problem and must not be invented by the registry wiring stub. If a future feature wants explicit tool choice, that future work must add a dedicated design issue and define the request field(s), validation, policy interaction, and failure behavior first.

### Policy and approval interaction

`ToolRegistry` metadata does not create permission. `PolicyEngine` and `ApprovalManager` remain authoritative for the task, and the presence of registry metadata must not alter allow/deny outcomes.

### Diagnostic and audit surface

The audit surface for this phase is count-only. It must never expose tool names, descriptions, action risk, required data level, or raw task content.

## Follow-up implementation scope

A future implementation issue may safely unblock `#121` if it:

- adds `toolRegistry: ToolRegistry?` as an optional `AgentKernel` dependency,
- records the registry count in audit history when `handle()` runs,
- keeps all routing, approval, and response behavior unchanged,
- adds tests that pin the read-only behavior and ensure the audit event is emitted only when a registry is present.

## Acceptance criteria for this decision

- A clear written boundary exists for tool-registry visibility.
- The future wiring scope is narrow enough to be tested without tool execution.
- The design explicitly keeps tool selection, approval interaction, and runtime invocation out of this phase.

This decision does not authorize tool execution or any direct runtime tool invocation path.