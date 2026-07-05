# Model Selection Engine (Phase 2)

## Purpose

This system selects the best model for a task using the current registry and runtime constraints.

It stays selection-only:

- it may rank candidates,
- it may reject candidates that fail constraints,
- it may not perform authorization,
- it may not execute runtime actions,
- it may not bypass `PolicyEngine` or `ApprovalManager`.

## Inputs

- `task_type`
- `latency_budget`
- `context_size`
- `tool_usage_required`
- `safety_level_required`
- `language_requirements`

## Selection Logic

1. Filter hard constraints.
2. Score capability match.
3. Rank evaluation score.
4. Apply latency checks.
5. Resolve fallbacks.

## Hard Rule

A model that fails a hard constraint is never considered.
