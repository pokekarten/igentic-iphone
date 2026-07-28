# Model Selection Engine (Phase 2)

## Purpose

This system selects the best model for a task from a fixed candidate list using runtime constraints.

It stays selection-only:

- it may rank candidates,
- it may reject candidates that fail constraints,
- it may not perform authorization,
- it may not execute runtime actions,
- it may not bypass `PolicyEngine` or `ApprovalManager`.

Current implementation notes:

- the engine evaluates a provided candidate list,
- there is no registry lookup yet,
- `safety_level_required` is not modeled yet,
- `language_requirements` is not modeled yet,
- Issue #103 remains the tracking item for the fuller safety-aware expansion.

## Inputs

The current request shape is intentionally small:

- `latency_budget`
- `context_size`
- `tool_usage_required`

## Selection Logic

1. Filter hard constraints.
2. Score capability match.
3. Rank evaluation score.
4. Apply latency checks.
5. Resolve fallbacks.

## Hard Rule

A model that fails a hard constraint is never considered.
