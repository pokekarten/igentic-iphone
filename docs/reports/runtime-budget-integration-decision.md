# RuntimeBudget integration decision

Status: decided — deliberate pre-integration stub

## Decision

`RuntimeBudget` is intentionally not wired into `AgentKernel` or `DiagnosticSnapshotProducer` at this time. No estimator exists yet.

## Rationale

- No estimation heuristic for deriving execution class, expected locality, or estimated memory class from task properties has been designed or reviewed yet.
- Wiring `RuntimeBudget` without an estimator would mean inventing thresholds ad hoc.
- Keeping the component detached preserves the current repository boundary: `RuntimeBudget` remains a deliberate planning stub until the input contract is specified.

## Follow-up

A future issue must define the estimator's input contract — which `TaskRequest` and `PrivacyMode` fields feed it — before any wiring into `AgentKernel` or `DiagnosticSnapshotProducer`.

This decision does not authorize implementation.