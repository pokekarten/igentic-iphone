# App Action approval policy spec

Status: planning note

## Purpose

This note turns the approval-policy direction into a concrete implementation target.
It follows from Issue #185 and the design note in `docs/reports/app-action-approval-policy-design.md`.

## Minimal model

Represent policy as explicit configuration, not runtime inference.

Suggested fields:
- action kind or action family
- approval required yes/no
- optional admin note / rationale
- enabled yes/no if the policy needs to be temporarily disabled without deletion

## Persistence boundary

Use the existing local app data/store path for the first version.
Do not add network-backed configuration for this step.

## Setup flow

During first-time setup:
- create a default policy set
- show whether approval is required for each action family
- let the user confirm or adjust before finishing setup

## Admin/settings flow

After setup:
- allow policy review and editing
- keep the surface small and explicit
- require the same approval semantics to be reflected in diagnostics

## Runtime contract

The runtime should:
- read the stored policy
- map it into `decision.requiresApproval`
- avoid inventing policy from hidden heuristics
- keep blocked actions blocked

## Tests to add

- policy defaults are created correctly
- configured no-approval action skips approval
- configured approval-required action requests approval
- blocked action remains blocked
- policy changes are visible in diagnostics

## Dependencies

- `ios/Sources/AgentCore/PolicyEngine.swift`
- `ios/Sources/AgentCore/AppActionCoordinator.swift`
- `ios/Sources/AgentCore/AgentKernel.swift`
- `docs/reports/app-action-approval-policy-design.md`
- Issue #185
