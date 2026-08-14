# ToolRegistry routing availability gate design

Status: decided — bounded fail-closed availability gate authorized for a later implementation issue  
Related issue: #260  
Predecessor: `docs/reports/tool-registry-integration-spec.md`

## Purpose

Define the smallest safe step from the current count-only `ToolRegistry` integration toward the Phase 2 `tool missing/invalid` control-plane case.

This decision authorizes **availability validation only** for fixed typed local routes. It does not authorize tool invocation, free-form tool selection, App Intents, execution dispatch, or policy derived from tool metadata.

## Current baseline

- `TaskRequest` carries a typed `TaskIntent`; it does not carry a user-supplied tool name.
- `TaskRouter` deterministically maps known intents to fixed `.localTool(name:reason:)` routes.
- `AgentKernel` owns policy and approval before it calls `TaskRouter`.
- `ToolRegistry` accepts valid normalized definitions, rejects empty names and duplicate names, and supports exact name lookup.
- `AgentKernel` currently uses an optional registry only to emit a count-only audit snapshot. Registry presence does not affect routing.

## Decision

### 1. Request representation

Keep the existing typed `TaskIntent` contract unchanged.

The first routing-gate slice must **not** add `requestedToolName`, arbitrary strings, user-text-to-tool inference, planner-selected tool names, or model-proposed tool identifiers to `TaskRequest`.

The canonical requested tool remains the name already produced by `TaskRouter` for a known typed intent. This avoids creating a second tool-selection authority.

### 2. Resolution point

The availability check belongs in `AgentKernel` **after** all existing authorization gates and after `TaskRouter` has produced a route:

```text
sensitive-data detection
-> effective classification
-> PolicyEngine
-> ApprovalManager when required
-> LocalModelRuntime capability gate when applicable
-> TaskRouter
-> ToolRegistry availability gate for .localTool only when a registry is supplied
-> routeSelected audit / response
```

The registry must never be consulted to make a denied task allowed, to waive approval, or to choose a different route.

### 3. Missing tool behavior

When `toolRegistry != nil` and `TaskRouter` returns `.localTool(name: ...)`, `AgentKernel` must require `toolRegistry.tool(named: name)` to exist.

If the lookup fails:

- fail closed with `.blocked(reason: "Required local tool is unavailable.")`;
- record one `.blocked` audit event using the existing effective data-sensitivity level;
- do not emit `.routeSelected`;
- do not fall back to another tool;
- do not repair, normalize beyond the registry's existing lookup behavior, or infer an alternative from user text;
- do not expose raw task text, tool descriptions, or registry contents in the failure message.

The generic failure reason is intentional. The typed tool name is already deterministic public metadata, but omitting it from the new blocked event preserves the current metadata-minimization posture and avoids widening the count-only audit surface in the same slice.

### 4. Invalid tool behavior

Invalid definitions remain a **registration-time** concern.

`ToolRegistry.register` already rejects invalid empty-name definitions and duplicate canonical names. The routing gate must not accept raw `ToolDefinition` values, silently repair an invalid definition, or introduce a second validation implementation.

Therefore the Phase 2 `tool missing/invalid` evidence is split deliberately:

- invalid definitions: proven by `ToolRegistryValidationTests` at registry construction/registration time;
- missing required typed tool: proven by the later `AgentKernel` availability-gate tests.

### 5. Tool metadata authority

`ToolDefinition.requiredDataLevel` and `ToolDefinition.actionRisk` remain **non-authoritative metadata** in this first routing-gate slice.

They must not:

- lower or raise the task's `DataClassification`;
- lower or raise `TaskRequest.actionRisk`;
- alter `PolicyEngine` inputs;
- create, remove, or satisfy an approval requirement;
- create permission to delegate or execute.

The repository does not yet define safe merge semantics between task risk/classification and tool metadata. Inventing those semantics inside an availability-gate PR would expand scope and risk creating a second policy path.

A separate source-backed design issue is required before tool metadata may influence policy or approval.

### 6. Compatibility when no registry is supplied

`toolRegistry == nil` preserves current behavior exactly.

A nil registry means the new availability gate is not active. Existing callers and tests must continue to route typed local actions exactly as they do today.

This compatibility rule keeps the change incremental and prevents the diagnostic dependency from becoming a mandatory global catalog without a migration plan.

### 7. Audit and privacy contract

Existing count-only registry snapshot behavior remains unchanged.

For the new missing-tool failure:

- one generic `.blocked` event is sufficient;
- use the effective classification already computed by `AgentKernel`;
- do not log task text, registry contents, tool description, target text, model output, or private identifiers;
- do not add a second registry inventory event;
- successful local-tool availability continues to produce the existing `.routeSelected` event only after the gate passes.

### 8. Required implementation tests

The later implementation issue must change only the minimum Swift files needed and pin at least these cases:

1. **Nil registry compatibility** — a typed local route is unchanged when `toolRegistry == nil`.
2. **Required tool present** — an explicitly supplied registry containing the typed route's canonical tool preserves the existing local route.
3. **Required tool missing** — an explicitly supplied registry lacking that tool returns the generic blocked route and emits no `.routeSelected` event.
4. **Unrelated tool present** — a registry containing other valid tools does not satisfy the required typed tool.
5. **Unknown intent** — clarification behavior remains unchanged and does not become a registry failure.
6. **Authorization precedence** — a policy denial or pending approval still stops before routing; registry availability cannot override those outcomes.
7. **Audit minimization** — missing-tool evidence contains no task text, tool descriptions, or registry inventory beyond the pre-existing count-only snapshot.
8. Existing `ToolRegistryValidationTests`, `AgentKernelToolRegistryWiringTests`, TaskRouter tests and repository-wide Swift tests remain green without weakening expectations.

## Bounded implementation slice

A later implementation issue may:

- add one private `AgentKernel` helper, or equivalent small inline check, that validates only `.localTool` routes against an explicitly supplied registry;
- add focused `AgentKernel` regression tests for the cases above;
- update this design/spec only if necessary to point to the implementation.

The preferred implementation does **not** change `TaskRequest`, `TaskIntent`, `TaskRouter`, `PolicyEngine`, `ApprovalManager`, `ToolRegistry` validation semantics, or public response types.

## Explicit non-goals

This decision does not authorize:

- tool invocation or execution;
- App Intents;
- arbitrary or model-selected tool names;
- registry-driven policy or approval;
- tool metadata risk/classification merging;
- fallback to another tool;
- networking, persistence, providers, credentials, or model execution;
- physical-device claims.

## Follow-up

After this design is reviewed and merged, open one implementation issue for the bounded availability gate. Only after that implementation is green may the completion plan's `tool missing/invalid` Phase 2 evidence be considered satisfied: invalid at registration time plus missing required typed tool at kernel routing time.