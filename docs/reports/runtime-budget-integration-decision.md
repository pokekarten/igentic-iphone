# RuntimeBudget integration decision

Status: implemented — bounded advisory `AgentKernel` wiring and diagnostic metadata contract  
Related issues: #264, #270

## Decision

`AgentKernel` may accept an optional `RuntimeBudgetAssessor` and record its result as planning metadata after deterministic policy and approval gates have succeeded.

This wiring is **advisory only**. A `RuntimeBudget` cannot allow or deny a task, create or waive approval, select a route, select a tool, authorize delegation, select a model, or override `LocalModelRuntime` capability and sensitivity checks.

The kernel may additionally expose a compact `RuntimeBudgetSummary` on `AgentResponse` so diagnostics can consume the exact result of the kernel-owned assessment rather than re-running the assessor independently. The summary contains only execution class, expected locality, estimated memory class and reason count.

## Placement in the kernel lifecycle

The bounded ordering is:

```text
sensitive-data detection
-> effective classification
-> PolicyEngine
-> ApprovalManager when required
-> RuntimeBudgetAssessor when configured (advisory metadata only)
-> ModelSelection proposal when explicit input is supplied (advisory only)
-> LocalModelRuntime capability gate when configured/applicable
-> TaskRouter
-> ToolRegistry availability gate when configured/applicable
-> routeSelected
```

Policy denial and pending/rejected approval return before budget assessment. The budget result itself never changes a later gate.

## Effective-classification rule

The assessor's existing API accepts a `TaskRequest` and reads `task.dataClassification.level`. `AgentKernel`, however, may raise a caller-supplied classification through `SensitiveDataDetector` before policy evaluation.

The kernel therefore reconstructs the assessor input from the typed task while replacing only `dataClassification` with the already-computed `effectiveDataClassification`. Intent, action risk and requested delegation target remain unchanged.

This prevents planning metadata from observing a lower sensitivity than the policy/approval/runtime stages for the same request.

## Audit and privacy contract

When an assessor is configured and the lifecycle reaches it, the kernel records exactly one `runtimeBudgetSnapshot` event after authorization gates succeed.

The bounded snapshot and `RuntimeBudgetSummary` contain only:

- execution class;
- expected locality;
- estimated memory class;
- reason count.

They do **not** include:

- raw task text;
- budget reason strings;
- model output or model identifiers;
- tool descriptions or registry contents;
- private target text or other task identifiers.

The audit event uses the same effective data-sensitivity level already computed by the kernel.

## `AgentResponse` diagnostic metadata contract

`AgentResponse.runtimeBudgetSummary` is optional and defaults to `nil` for compatibility.

It is populated only when the configured `RuntimeBudgetAssessor` actually ran. Therefore:

- policy denial returns `nil`;
- pending or rejected approval returns `nil`;
- later LocalModelRuntime or ToolRegistry failure may still return the summary because the budget stage already occurred;
- a successful route may return the summary when the assessor was configured.

The summary is observational evidence only. Consumers must not interpret its presence or values as permission, approval, routing authority, model selection authority, tool selection authority, delegation permission or execution authorization.

## Compatibility

`runtimeBudgetAssessor == nil` preserves prior kernel behavior, emits no runtime-budget event and returns no runtime-budget summary. Existing `AgentResponse` initializers remain source-compatible because the new summary parameter defaults to `nil`.

## Relationship to ModelSelectionEngine

Model selection remains advisory and separately bounded. The repository still does not define a source-backed automatic mapping from task/runtime-budget state to `ModelSelectionRequest.latencyBudget`, `contextSize`, `toolUsageRequired`, candidates or scores.

RuntimeBudget diagnostic metadata must therefore not be used to invent ModelSelection inputs.

## DiagnosticSnapshotProducer

Issue #270 adds the separately reviewed diagnostic metadata contract required by the original RuntimeBudget decision.

`DiagnosticSnapshotProducer` configures the kernel with the existing `RuntimeBudgetAssessor` and consumes `AgentResponse.runtimeBudgetSummary`. It does **not** call `RuntimeBudgetAssessor.assess` a second time.

`DiagnosticSnapshot` carries the optional compact summary and the diagnostic view renders it as planning information only. If policy or approval prevents the lifecycle from reaching RuntimeBudget, diagnostics explicitly report that the stage was not reached instead of fabricating an estimate.

The current default `critical-reminder` preview remains approval-pending, so its runtime-budget fields intentionally show `Not reached` / unavailable values.

## Non-goals

This wiring does not authorize:

- budget-driven blocking or fallback;
- changes to `RuntimeBudgetAssessor` estimation semantics;
- automatic ModelSelection input derivation;
- model execution;
- tool selection or execution;
- App Intents;
- persistence, networking or provider integration;
- changes to policy, approval or delegation authority.

## Validation contract

Focused tests must pin:

- nil-summary compatibility before the budget stage;
- one kernel-owned advisory summary with unchanged routing;
- effective-classification propagation into the assessor;
- policy and approval precedence;
- metadata minimization;
- diagnostic rendering when the summary exists;
- truthful `Not reached` diagnostics when policy/approval stops before RuntimeBudget.

Repository-wide RuntimeBudget/Assessor and Swift tests remain required exact-head evidence.
