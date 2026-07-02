# Model Selection Engine (Phase 2)

## Purpose

This system selects the optimal model for a given task based on:

- registry constraints
- evaluation scores
- runtime requirements

No manual or chat-based selection is allowed in production mode.

## Inputs

- task_type
- latency_budget
- context_size
- tool_usage_required
- safety_level_required
- language_requirements

## Selection Logic

1. Hard constraint filtering
2. Capability match scoring
3. Evaluation score ranking
4. Latency constraint check
5. Fallback resolution

## Hard Rule

A model that fails constraints is never considered.
