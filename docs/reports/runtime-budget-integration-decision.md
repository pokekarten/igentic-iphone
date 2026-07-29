# RuntimeBudget integration decision

Status: decided — estimator added, wiring still deferred

## Decision

`RuntimeBudget` is intentionally not wired into `AgentKernel` or `DiagnosticSnapshotProducer` at this time. `RuntimeBudgetAssessor` now exists as the deterministic planning helper that produces `RuntimeBudget` values from the documented input contract.

## Rationale

- The estimator now exists, so the remaining decision is about wiring and visibility, not about inventing the estimator itself.
- Wiring `RuntimeBudget` deeper into the kernel without a separate visibility decision would still create an ad hoc dependency on planning metadata.
- Keeping the component detached preserves the current repository boundary: `RuntimeBudget` remains a deliberate planning stub until a separate wiring decision is authorized.

## Follow-up

A future issue must decide whether runtime-budget metadata should be surfaced through diagnostics or kernel wiring before any `AgentKernel` or `DiagnosticSnapshotProducer` integration is attempted.

This decision does not authorize new wiring by itself.