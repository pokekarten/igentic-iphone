# ToolRegistry integration spec

Status: draft specification for issue #137

## Purpose

This document defines the integration boundary that must exist before `ToolRegistry` can be wired into `AgentKernel` or any other live authorization path.

This spec is deliberately non-implementing. It does **not** authorize Swift changes, kernel wiring, runtime tool invocation, or any policy-path mutation. It exists only to remove ambiguity so a later implementation issue can be reviewed cleanly.

## Current baseline

The existing decision note already establishes that `ToolRegistry` is a read-only, diagnostic-only component and is not part of any live authorization path yet. This spec only fills in the follow-up questions named there.

## Integration boundary

### 1) How a task selects a tool

Tool selection must remain outside `ToolRegistry` itself.

The registry may provide the catalog of available tools and their metadata, but it must not decide which tool a task should use.

A future task planner or router may use these inputs to choose a tool:
- task intent or task type,
- declared capability requirements,
- privacy / locality constraints,
- availability of a matching tool in the registry.

Selection remains a planning concern, not a registry concern. The registry is a source of truth for what exists; it is not an execution oracle.

### 2) How tool metadata interacts with PolicyEngine / ApprovalManager

Tool metadata may inform policy review, but it must not replace policy review.

The following metadata is relevant for policy analysis and approval decisions:
- tool identifier and display name,
- capability category,
- required data level / sensitivity expectations,
- action risk or side-effect risk,
- locality or execution constraints, if present.

The interaction contract should be:
- `PolicyEngine` remains authoritative for allow / deny / approval-needed decisions,
- `ApprovalManager` remains authoritative for recording and enforcing approval receipts,
- tool metadata may be read as input to those components or to a future planner,
- tool metadata must never auto-authorize a task by itself.

In other words, tool metadata can annotate a decision, but it cannot make the decision.

### 3) Whether ToolRegistry needs an additional diagnostic surface

The current tested API is sufficient as the baseline diagnostic surface.

A future implementation may add a read-only diagnostic snapshot if, and only if, the kernel integration needs a stable way to report registry state in audit output.

Any additional diagnostic surface must remain:
- read-only,
- side-effect free,
- non-authorizing,
- non-executing.

Examples of acceptable diagnostic signals include:
- tool count,
- tool identifiers,
- a compact summary of capability categories.

Examples of unacceptable additions include:
- tool invocation entry points,
- task-to-tool execution dispatch,
- policy bypass helpers,
- implicit approval shortcuts.

### 4) Test coverage for the future integration boundary

A later implementation issue that wires `ToolRegistry` into `AgentKernel` must include explicit tests for the boundary.

Minimum expected coverage:
- the registry remains accessible in read-only form,
- the kernel can surface registry state without changing routing behavior,
- tool metadata does not bypass `PolicyEngine` or `ApprovalManager`,
- no direct tool execution path appears unless a separate issue authorizes it,
- boundary behavior is stable under existing documentation and audit workflows.

The tests should prove that the new integration is observational first, not operational first.

## Non-goals

This spec does not:
- implement `ToolRegistry` wiring,
- add tool execution,
- add App Intents integration,
- change `AgentKernel`, `TaskRouter`, `PolicyEngine`, or `ApprovalManager`,
- define a concrete per-tool dispatch algorithm,
- authorize any runtime behavior beyond read-only diagnostics.

## Follow-up required before implementation

A separate implementation issue must be opened before `ToolRegistry` is wired into `AgentKernel`.
That follow-up issue should reference this spec and may only implement the bounded read-only boundary described here.

That later issue is the one that can unblock issue #121.

## Validation notes

Documentation-only validation should follow the repository project-control workflow:
- `python3 scripts/validate_repo_structure.py`
- Docs Consistency
- Repo Audit
- Phase 0 CI Validation

## Safety note

This is a specification document only.
It introduces no network/provider changes, no signing changes, no kernel wiring, and no production execution path.