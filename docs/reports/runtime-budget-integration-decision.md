# RuntimeBudget integration decision

Status: decided — estimator implemented, wiring deferred

## Decision

`RuntimeBudget` is intentionally not wired into `AgentKernel` or `DiagnosticSnapshotProducer` at this time. `RuntimeBudgetAssessor` now exists, but the estimator remains detached from runtime wiring.

## Rationale

- The assessor is implemented, but the code still keeps `RuntimeBudget` out of the kernel and snapshot path.
- Wiring `RuntimeBudget` into those paths remains a separate decision from the estimator itself.
- Keeping the component detached preserves the current repository boundary around approval and routing.

## Follow-up

Any future wiring into `AgentKernel` or `DiagnosticSnapshotProducer` must still be justified against the existing policy and delegation layers.

This decision does not authorize further wiring without review.