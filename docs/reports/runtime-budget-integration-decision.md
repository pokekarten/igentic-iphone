# RuntimeBudget integration decision

Status: implemented — bounded advisory `AgentKernel` wiring  
Related issue: #264

## Decision

`AgentKernel` may accept an optional `RuntimeBudgetAssessor` and record its result as planning metadata after deterministic policy and approval gates have succeeded.

This wiring is **advisory only**. A `RuntimeBudget` cannot allow or deny a task, create or waive approval, select a route, select a tool, authorize delegation, select a model, or override `LocalModelRuntime` capability and sensitivity checks.

## Placement in the kernel lifecycle

The bounded ordering is:

```text
sensitive-data detection
-> effective classification
-> PolicyEngine
-> ApprovalManager when required
-> RuntimeBudgetAssessor when configured (advisory metadata only)
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

When an assessor is configured, the kernel records exactly one `runtimeBudgetSnapshot` event after authorization gates succeed.

The first bounded snapshot contains only:

- execution class;
- expected locality;
- estimated memory class;
- reason count.

The snapshot does **not** include:

- raw task text;
- budget reason strings;
- model output or model identifiers;
- tool descriptions or registry contents;
- private target text or other task identifiers.

The event uses the same effective data-sensitivity level already computed by the kernel.

## Compatibility

`runtimeBudgetAssessor == nil` preserves the prior kernel behavior and emits no runtime-budget event. The dependency is optional so this slice does not make planning infrastructure mandatory for every existing caller.

## Relationship to ModelSelectionEngine

`ModelSelectionEngine` remains deliberately detached from `AgentKernel` in this issue.

The repository currently does not define a source-backed mapping from task/runtime-budget state to `ModelSelectionRequest.latencyBudget`, `contextSize`, or `toolUsageRequired`. Those values must not be invented as part of RuntimeBudget wiring.

A later source-backed issue must define that input mapping and preserve model selection as a proposal/advisory stage before any real kernel integration.

## DiagnosticSnapshotProducer

This decision does not wire `RuntimeBudget` into `DiagnosticSnapshotProducer`. The kernel audit event is the first bounded integration surface. Any diagnostic-shell presentation should consume a separately reviewed metadata contract rather than duplicating assessment logic.

## Non-goals

This wiring does not authorize:

- budget-driven blocking or fallback;
- changes to `RuntimeBudgetAssessor` estimation semantics;
- model selection or model execution;
- tool selection or execution;
- App Intents;
- persistence, networking or provider integration;
- changes to policy, approval or delegation authority.

## Validation contract

Focused kernel tests must pin:

- nil-assessor compatibility;
- one advisory snapshot with unchanged routing;
- effective-classification propagation into the assessor;
- policy and approval precedence;
- metadata minimization.

Repository-wide RuntimeBudget/Assessor and Swift tests remain required exact-head evidence.
