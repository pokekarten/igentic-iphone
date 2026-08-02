# App Action approval policy implementation note

Status: implementation complete for issue #185
Date: 2026-08-02
Related issue: #185

## Implemented policy contract

The local-only policy model in `ios/Sources/AgentCore/AppActionApprovalPolicy.swift` provides:

- a schema version;
- one explicit rule per `AppActionDraft.ActionKind`;
- approval-required and enabled values;
- optional display-only notes;
- a conservative setup default;
- deterministic JSON save/load behavior;
- safe fallback to defaults for missing or invalid local data;
- a deterministic Application Support location.

`AppActionCoordinator` consumes the configured approval requirement only after the existing deterministic allow/block decision. A configured rule cannot turn a blocked action into an allowed action.

## Setup and settings behavior

The diagnostic app now:

- prepares the local policy at startup;
- shows the effective persisted policy in diagnostics;
- provides a local settings page for the four supported action families;
- keeps edits as a draft until the user saves;
- saves changes through `AppActionApprovalPolicyStore`;
- supports restoring and saving the setup defaults;
- requires an explicit first-run confirmation before setup is complete;
- records that confirmation in a separate local versioned marker;
- repeats the confirmation after a missing, recreated, or invalid policy state;
- prevents dismissing the first-run confirmation without a successful save.

The setup confirmation marker contains no private task content, policy values, messages, contacts, files, credentials, or device identifiers.

## Safety boundaries preserved

- `PolicyEngine.isAllowed == false` remains a hard stop.
- Restricted sensitive data remains blocked from automatic external delegation.
- Approval receipts remain bound to the exact app-action draft.
- Models, runtimes, tools, and settings cannot authorize themselves.
- No network-backed policy distribution or administration was added.
- Approval requirements are not inferred from arbitrary task text.

## Validation coverage

The repository includes coverage for:

- setup defaults;
- JSON persistence round trips;
- invalid-file fallback;
- bootstrap loaded/default/fallback states;
- configured approval-required and configured no-approval actions;
- blocked-action semantics;
- local policy editor persistence and reset;
- clearing an existing optional note;
- effective-policy diagnostic presentation;
- setup-confirmation marker persistence and invalid-marker rejection.

Executable validation remains:

- `python3 scripts/validate_repo_structure.py`;
- `cd ios && swift test` on macOS and Linux;
- the iOS App Wrapper simulator build, launch, screenshot, termination, and relaunch smoke test.

## Out of scope

This implementation does not add networking, remote administration, model execution, App Intents side effects, signing, entitlements, or a broader settings architecture.
