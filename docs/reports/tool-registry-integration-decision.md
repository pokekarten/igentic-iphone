# ToolRegistry integration decision

Status: decided — deliberate pre-integration stub

## Decision

`ToolRegistry` is intentionally not wired into `AgentKernel` or any other
live authorization path at this time. It remains a read-only, diagnostic-
only component that is built ahead of integration.

## Rationale

- Avoids prematurely coupling tool catalog state to routing or approval
  behavior before the tool-selection design is settled.
- Keeps the current repository boundary clear: `ToolRegistry` can be
  validated in isolation without implying execution wiring.
- Preserves room for a future design decision about how tools should be
  selected, filtered, and authorized before any runtime integration.

## Follow-up

A future issue must be opened before `ToolRegistry` is wired into
`AgentKernel`. That issue must specify:

- how a task would select a tool,
- how tool metadata should interact with policy and approval checks,
- whether `ToolRegistry` needs any additional diagnostic surface beyond
  its current tested API,
- test coverage for any new integration boundary.

This decision does not authorize implementation.