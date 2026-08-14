# ModelSelectionEngine integration decision

Status: implemented — bounded advisory `AgentKernel` proposal wiring  
Related issue: #266

## Decision

`AgentKernel` may compute a deterministic `ModelSelectionEngine` proposal from an explicitly supplied, typed `ModelSelectionProposalInput` after policy and approval gates have succeeded.

The proposal is **advisory evidence only**. The selected model ID, selection reason, eligible-candidate count and fallback reason cannot alter policy, approval, delegation, `LocalModelRuntime`, tool availability, routing or execution.

## Exact input contract

The first kernel integration accepts a precomputed envelope containing exactly the current v1 Swift selection inputs:

- `request: ModelSelectionRequest`;
- `candidates: [ModelCandidate]`;
- `policy: ModelSelectionPolicy`.

The kernel does not infer, repair or mutate these values.

In particular, this slice does **not** derive:

- `latencyBudget` from `RuntimeBudget`;
- `contextSize` from user text or prompt length;
- `toolUsageRequired` from `TaskIntent` or ToolRegistry;
- candidates from providers, runtime discovery or networking;
- evaluation, latency or capability scores from live model behavior.

The repository does not yet define canonical rules for those derivations. Inventing them inside kernel wiring would make diagnostics appear task-grounded when they are not.

## Relationship to the broader selection policy

`docs/model-selection/SELECTION_POLICY_v1.yaml` describes broader desired request fields including task type, safety level and language requirements. The current Swift `ModelSelectionRequest` implements only `latencyBudget`, `contextSize` and `toolUsageRequired`.

This integration is therefore explicitly bounded to the **currently implemented Swift v1 contract**. It does not claim that the broader desired policy schema is fully represented in runtime code.

## Lifecycle placement

The bounded ordering is:

```text
sensitive-data detection
-> effective classification
-> PolicyEngine
-> ApprovalManager when required
-> RuntimeBudgetAssessor when configured (advisory)
-> ModelSelection proposal when explicit input is supplied (advisory)
-> LocalModelRuntime capability gate when configured/applicable
-> TaskRouter
-> ToolRegistry availability gate when configured/applicable
-> routeSelected
```

Policy denial and pending/rejected approval return before proposal generation. When RuntimeBudget is configured, its snapshot precedes the model-selection proposal.

The proposal is discarded after audit evidence is recorded. It is not passed to `LocalModelRuntime` or `TaskRouter`.

## Deterministic proposal semantics

The kernel reuses `ModelSelectionDecisionTraceGenerator`, which in turn reuses the existing deterministic `ModelSelectionEngine` behavior and trace schema.

This preserves the existing hard constraints, ranking, tie-break and safe-refusal behavior without duplicating selection logic in the kernel.

The safe-refusal model remains a **proposal result**, not a block/allow decision. A task that otherwise passes deterministic kernel gates continues along its existing route even when the model-selection proposal returns the safe-refusal model.

## Audit and privacy contract

When explicit proposal input is supplied after authorization gates succeed, the kernel records exactly one `modelSelectionProposal` audit event containing only:

- selected model ID;
- stable selection reason code;
- eligible candidate count;
- fallback reason code or `none`.

The event uses the task's already-computed effective data-sensitivity level.

The audit event does not include:

- raw task text or prompts;
- candidate evaluation/latency/capability scores;
- weighted score components;
- approval receipts;
- tool execution output;
- private task content.

The full deterministic trace remains available through the existing trace generator when a caller needs diagnostic evidence outside the kernel audit surface.

## Compatibility

`modelSelectionProposalInput == nil` preserves previous kernel behavior and emits no model-selection proposal event.

The input is optional because the repository still lacks a canonical task-to-selection-input adapter. The kernel must not fabricate one merely to make proposal generation mandatory.

## Trust boundary

A proposal event proves only what the deterministic engine returned for the explicit typed envelope supplied to the kernel. It does **not** prove that the envelope was correctly derived from the current task.

A later source-backed adapter issue is required before task/runtime-budget state may automatically produce `ModelSelectionRequest` or candidates.

## Non-goals

This wiring does not authorize:

- selected-model configuration of `LocalModelRuntime`;
- model loading or execution;
- candidate discovery or provider/network access;
- mapping RuntimeBudget fields to selection request fields;
- changes to ranking weights or fallback semantics;
- model-driven policy, approval, delegation, tool selection or routing;
- App Intents, persistence or credentials.

## Validation contract

Focused kernel tests must pin:

- nil-input compatibility;
- deterministic eligible proposal with unchanged route;
- safe-refusal proposal with unchanged route;
- policy and approval precedence;
- RuntimeBudget-before-proposal ordering;
- audit metadata minimization.

Existing ModelSelectionEngine/DecisionTrace and repository-wide Swift tests remain required exact-head evidence.
