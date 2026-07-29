# Model-selection decision trace schema v1

Status: decided for diagnostic implementation
Related issue: #144

## Purpose

Define the smallest deterministic trace needed to explain one `ModelSelectionEngine.select(...)` run without changing selection, policy, authorization, or runtime behavior.

The trace is diagnostic evidence only. It must never be treated as a policy decision or execution authorization.

## Trace shape

A trace contains these fields:

- `schemaVersion`: `v1`
- `request`: the exact selection inputs currently supported by `ModelSelectionRequest`
  - `latencyBudget`
  - `contextSize`
  - `toolUsageRequired`
- `candidates`: one trace record per input candidate, preserving deterministic input order
- `selectedModelID`: the resulting `ModelSelectionResult.selectedModelID`
- `selectionReason`: the resulting `ModelSelectionResult.reason`
- `selectedScore`: the resulting score, when present

Each candidate record contains:

- `modelID`
- `eligible`: whether all current hard constraints pass
- `rejectionReasons`: zero or more deterministic reason codes
- `weightedScore`: present only when the candidate is eligible
- `scoreComponents`: evaluation, latency and capability contributions when scored
- `latencyMS`

The trace must not add new selection inputs that are not already part of `ModelSelectionRequest` or `ModelCandidate`.

## Hard-constraint rejection reason codes

Use stable machine-readable codes:

- `contextSizeExceedsMaxContextTokens`
- `latencyBudgetExceedsCandidateClass`
- `toolUsageRequiredButUnsupported`

A candidate may have multiple rejection reasons; they are ordered in the same deterministic order as the current constraint checks: context size, latency budget, then tool support.

## Selection reason codes

Map the current `ModelSelectionReason` cases exactly:

- `highestWeightedScore`
- `lowestLatencyValidModel`
- `safeRefusalModel`

No new reason code is introduced by the trace layer.

## Score components

The trace records the three existing weighted contributions independently:

- `evaluation = evaluationScore * evaluationWeight`
- `latency = latencyScore * latencyWeight`
- `capability = capabilityMatch * capabilityWeight`

`weightedScore` is their sum. The policy weights come from `ModelSelectionPolicy` and remain the selection engine's existing source of truth.

## Tie-break semantics

The current engine has one deterministic tie-break:

1. highest weighted score;
2. among equal scores, lowest `latencyMS`;
3. if latency is also equal, return the configured safe-refusal model.

Trace reason codes should therefore distinguish:

- `highestWeightedScore`
- `lowestLatencyValidModel`
- `safeRefusalModel`

The trace must not introduce a random, input-order-dependent, or model-name-dependent tie-break.

## Fallback semantics

There are two existing safe-refusal paths:

1. no candidate satisfies the hard constraints;
2. candidates remain tied after score and latency tie-breaking.

Both produce `selectionReason = safeRefusalModel`, with `selectedModelID` equal to `ModelSelectionPolicy.safeRefusalModelID`.

The diagnostic trace should expose which of these occurred with a separate non-authoritative fallback detail, for example:

- `noEligibleCandidates`
- `unresolvedScoreAndLatencyTie`

These are explanatory trace details, not new `ModelSelectionReason` cases.

## Determinism requirements

For identical inputs and policy:

- candidate ordering is stable;
- rejection reason ordering is stable;
- score components are reproducible;
- the selected model and reason are identical;
- no timestamps, UUIDs, random values, locale-dependent formatting, or hidden runtime state are included.

## Privacy and safety boundary

The trace is allowed to contain model identifiers and numeric selection metadata needed to explain the diagnostic result. It must not contain user task text, raw prompts, private content, approval receipts, tool execution results, or authorization decisions.

A trace cannot authorize a model, tool, delegation target, or action.

## Compact example

```text
request: latencyBudget=low, contextSize=2048, toolUsageRequired=true
candidate model-alpha: eligible=true, score=0.73
candidate model-beta: eligible=true, score=0.73
candidate model-gamma: eligible=false, rejection=[toolUsageRequiredButUnsupported]
selectedModelID=model-beta
selectionReason=lowestLatencyValidModel
selectedScore=0.73
```

## Follow-up implementation boundary

Issue #146 may now implement the trace value type and generator using this schema.

It must remain:

- read-only;
- deterministic;
- diagnostic-only;
- independent of `PolicyEngine`, `ApprovalManager`, and runtime execution;
- based on the current model-selection inputs and behavior rather than introducing new selection logic.

Issue #145/#148/#149 may then consume this trace for the diagnostic preview and its regression coverage.
