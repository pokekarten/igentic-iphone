# App Action approval policy implementation note

Status: first implementation slice complete
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

## What the slice does not do yet

- no wiring into `AppActionCoordinator`
- no setup screen or admin/settings UI
- no app-wide persistence integration
- no network-backed configuration

## Tests added

`ios/Tests/AgentCoreTests/AppActionApprovalPolicyTests.swift` pins:

- the setup default policy
- the local JSON round trip
- fallback to defaults when the stored file is invalid
- disabled-rule fallback behavior

## Next step

Wire the stored policy into setup/admin configuration and then into the runtime approval path without changing the existing blocked-action semantics.