# ModelSelectionEngine integration decision

Status: decided — deliberate pre-integration stub

## Decision

`ModelSelectionEngine` is intentionally not wired into `AgentKernel` or
`TaskRouter` at this time. In the current repository it appears only as a
diagnostic preview surface via `DiagnosticViewState` and `DiagnosticView`
(PR #177).

## Rationale

- Avoids coupling model-selection policy to runtime routing before the real
  selection contract is defined.
- Keeps the preview-only usage isolated from live kernel behavior.
- Preserves the current boundary so the component can continue to be validated
  in diagnostics without implying execution wiring.

## Follow-up

A future issue must be opened before `ModelSelectionEngine` is wired into
`AgentKernel` or `TaskRouter`. That issue must specify:

- the exact input contract for model selection,
- how the selected model influences routing, policy, or approval behavior,
- whether any additional diagnostic surface is needed beyond the current
  preview wiring,
- test coverage for the first real integration boundary.

This decision does not authorize implementation.
