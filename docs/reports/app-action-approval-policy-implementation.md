# App Action approval policy implementation note

Status: runtime wiring in progress
Date: 2026-07-30
Related issue: #185

## What is implemented

A small local-only policy model now exists in `ios/Sources/AgentCore/AppActionApprovalPolicy.swift`:

- schema version
- per-`AppActionDraft.ActionKind` rule entries
- approval required yes/no
- enabled yes/no
- optional note/rationale
- default setup policy
- JSON save/load store with fallback to defaults

`AppActionCoordinator` now accepts an optional configured policy and uses it as the approval gate after the existing allow/blocked policy decision has passed.

## What the slice does not do yet

- no setup screen or admin/settings UI
- no app-wide persistence integration
- no network-backed configuration

## Tests added

`ios/Tests/AgentCoreTests/AppActionApprovalPolicyTests.swift` pins:

- the setup default policy
- the local JSON round trip
- fallback to defaults when the stored file is invalid
- disabled-rule fallback behavior

`ios/Tests/AgentCoreTests/AppActionCoordinatorTests.swift` now also pins:

- configured approval-required sendMessage flow
- blocked-action semantics still remain blocked

## Next step

Wire the stored policy into setup/admin configuration and make the app load/save it from a real local persistence path, then surface the effective policy in diagnostics.