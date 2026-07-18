# RuntimeBudget estimator specification

Status: proposed — documentation only, no implementation authorized.

## Purpose

This document specifies the input contract and behavioral shape for the future
`RuntimeBudgetAssessor` referenced by Issue #122. It does not add the
assessor, does not wire `RuntimeBudget` into `AgentKernel` or
`DiagnosticSnapshotProducer`, and does not change `RuntimeBudget.swift`.

The design must remain consistent with `docs/reports/runtime-budget-integration-decision.md`,
which states that `RuntimeBudget` is a deliberate pre-integration stub until
an input contract exists.

## Input contract

The estimator must be fed only from the current task metadata and the current
privacy mode:

- `TaskRequest.intent`
- `TaskRequest.dataClassification`
- `TaskRequest.actionRisk`
- `TaskRequest.requestedDelegationTarget`
- `PrivacyMode`

`TaskRequest.intent` is the primary signal. The other four fields are
escalation or guard signals that can make the estimate more conservative, but
they must not introduce an independent routing decision path.

## Heuristic shape

The assessor must return a `RuntimeBudget` with three enum fields plus a
`reasons: [String]` trail:

- `executionClass`: `.tiny`, `.small`, or `.large`
- `expectedLocality`: `.localOnly`, `.trustedDevice`, or `.externalRequired`
- `estimatedMemoryClass`: `.low`, `.moderate`, or `.high`

The mapping is intentionally conservative and monotonic:

1. Start from `intent`.
2. Escalate based on `dataClassification`, `actionRisk`,
   `requestedDelegationTarget`, and `PrivacyMode`.
3. Never reduce a conservative estimate once a higher-risk signal has been
   observed.

### Recommended baseline by intent family

The exact `TaskIntent` enum cases may evolve, but the assessor should group
those cases into the following families:

- **Lookup / retrieval / find / read**
  - `executionClass`: `.tiny`
  - `expectedLocality`: `.localOnly`
  - `estimatedMemoryClass`: `.low`
- **Bounded summarization / transformation / short synthesis**
  - `executionClass`: `.small`
  - `expectedLocality`: `.localOnly` or `.trustedDevice` when the task is
    already delegated inside the trusted-device boundary
  - `estimatedMemoryClass`: `.moderate`
- **Broad synthesis / multi-step planning / fan-out / large payload handling**
  - `executionClass`: `.large`
  - `expectedLocality`: `.trustedDevice` unless policy already makes the task
    `externalRequired`
  - `estimatedMemoryClass`: `.high`

### Escalation rules

`dataClassification`, `actionRisk`, `requestedDelegationTarget`, and
`PrivacyMode` are used to escalate the baseline conservatively:

- `dataClassification` may raise `estimatedMemoryClass` one step.
- `actionRisk` may raise `executionClass` one step when the intent family is
  otherwise ambiguous.
- `requestedDelegationTarget` may raise `expectedLocality` from
  `.localOnly` to `.trustedDevice` when the request is already allowed inside
  the trusted-device boundary.
- `PrivacyMode` must cap permissiveness:
  - local-only tasks must not be described as more permissive than
    `.localOnly` unless the existing policy layer already classifies the task
    as `externalRequired`;
  - trusted-device mode may use `.trustedDevice` but must not silently imply
    an external runtime;
  - external-AI mode may use `.externalRequired` when the policy/delegation
    path already resolves to an external runtime.

`expectedLocality == .externalRequired` must not be invented as a second
policy decision. It must mirror the existing policy/delegation outcome for
cases that are already external by policy.

## `requiresExternalRuntime`

`RuntimeBudget.requiresExternalRuntime` currently means
`expectedLocality == .externalRequired`.
The assessor must not compute a separate external-runtime rule.
Instead, any future implementation must derive `expectedLocality` from the
same policy result that `PolicyEngine` / `DelegationBroker` already use for
external-required cases.

That means:

- the assessor may reflect an external-required decision,
- the assessor may not independently decide that a task needs an external
  runtime,
- the policy layer remains the source of truth for whether a task is allowed,
  blocked, or requires approval.

## `reasons`

`reasons` must behave like `RiskScorer.reasons`: one stable, human-readable
reason per factor, appended in deterministic order.

Required ordering:

1. one baseline reason describing the intent family,
2. one reason for each escalation caused by data classification,
3. one reason for each escalation caused by action risk,
4. one reason for each locality change caused by requested delegation target,
5. one reason for each privacy-mode constraint,
6. one final reason when the task is classified as `externalRequired` through
   the existing policy/delegation result.

Reason strings should be short, factual, and enum-derived. They should not
contain task content.

Examples of acceptable style:

- `Intent family: lookup -> tiny.`
- `Data classification escalates memory to high.`
- `Action risk escalates execution class to large.`
- `Requested delegation target maps locality to trusted-device.`
- `Privacy mode constrains locality to local-only.`
- `Policy result requires an external runtime.`

## Test coverage required before any wiring issue is allowed

Before any `AgentKernel` or `DiagnosticSnapshotProducer` wiring work is
considered, the future implementation issue must add tests that cover:

- intent-family mapping to each of the three execution classes,
- locality mapping for local-only, trusted-device, and external-required
  outcomes,
- memory-class escalation for higher data sensitivity,
- reasons ordering and determinism,
- external-required consistency with the existing policy/delegation logic,
- a regression case proving that the assessor does not become a second
  independent routing policy.

The tests should stay synthetic and metadata-only.
They must not use real private data, runtime measurement, hardware probing, or
model execution.

## Non-goals

- No Swift implementation in this issue.
- No change to `RuntimeBudget.swift`.
- No change to `AgentKernel`, `DiagnosticSnapshotProducer`, `PolicyEngine`,
  `DelegationBroker`, or any approval path.
- No invented thresholds without a follow-up implementation issue that owns
  the concrete code.

## Follow-up

After this specification lands, open a separate implementation issue titled:
`Feature: implement RuntimeBudgetAssessor estimator`

That follow-up issue is the first issue allowed to add the assessor type,
its Swift tests, and any eventual wiring.

Until then, Issue #122 remains documentation-only.
