# ToolRegistry integration spec

Status: implemented boundary — diagnostic-only wiring complete
Related issues: #137, #121

## Purpose

This document defines the safe integration boundary for `ToolRegistry` in `AgentKernel`.

## Current baseline

The repository has implemented the bounded Phase 1 integration described by the decision note:

- `AgentKernel` accepts an optional `toolRegistry: ToolRegistry?` dependency.
- When present, `handle()` records exactly one count-only `.toolRegistrySnapshot` audit event.
- Routing, approval, policy decisions and response shape are unchanged by registry presence.
- When no registry is supplied, no registry snapshot event is emitted.
- Tests pin both paths.

## Integration boundary

### 1) How a task selects a tool

Tool selection remains outside `ToolRegistry` itself.

The registry provides the catalog of available tools and metadata; it does not decide which tool a task should use. A future planner/router may use task intent, declared capabilities, privacy/locality constraints and registry availability, but that is separate work.

### 2) PolicyEngine / ApprovalManager interaction

Tool metadata does not create permission.

- `PolicyEngine` remains authoritative for allow/deny/approval-needed decisions.
- `ApprovalManager` remains authoritative for approval receipts.
- Registry presence does not alter policy outcomes.
- No tool metadata is used as an authorization shortcut.

### 3) Diagnostic surface

The implemented Phase 1 diagnostic surface is intentionally count-only:

`toolRegistryToolCount=<count>`

It does not expose tool names, descriptions, action risk, required data level, or task content.

### 4) Test boundary

`AgentKernelToolRegistryWiringTests` covers:

- registry count is emitted when a registry is present;
- exactly one registry snapshot is emitted;
- routing remains unchanged;
- registry names/descriptions are not leaked into audit output;
- no snapshot is emitted when the registry is absent.

## Explicit non-goals

The current integration does not add:

- tool invocation;
- tool selection logic;
- App Intents integration;
- changes to `TaskRequest` or `TaskIntent`;
- dynamic authorization from tool metadata;
- user-text-to-tool inference;
- runtime execution dispatch.

## Future boundary

Any future tool execution or task-to-tool selection requires a new, source-backed design issue. It must define request representation, validation, policy/approval interaction, execution failure behavior and audit requirements before implementation.

This document therefore no longer requires a follow-up issue merely to expose registry state: the bounded read-only integration is already implemented and tested.