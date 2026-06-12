# Codex Next Task

Repository: `pokekarten/igentic-iphone`

## Task

Bootstrap the first minimal Swift AgentCore package for the privacy-first iPhone AI Runtime Layer.

## Base branch

`main`

## Working branch

`codex/bootstrap-agent-core`

## Goal

Create or complete the smallest useful Swift package under `ios/` with a policy-first agent kernel.

This is not a full iOS app yet. Do not add Xcode project files, signing, model weights or app-store configuration.

## Allowed files

Codex may only create or modify:

```text
AGENTS.md
PROJECT_STATE.md
docs/CODEX_NEXT_TASK.md
docs/SPARSAMKEIT.md
docs/SOURCE_VERIFICATION.md
scripts/validate_repo_structure.py
ios/Package.swift
ios/Sources/AgentCore/*.swift
ios/Tests/AgentCoreTests/*.swift
```

## Required Swift types

- `DataSensitivityLevel`
- `DataClassification`
- `PrivacyMode`
- `ActionRisk`
- `DelegationTarget`
- `PolicyRequest`
- `PolicyDecision`
- `PolicyEngine`
- `TaskIntent`
- `TaskRequest`
- `TaskRoute`
- `TaskRouter`
- `AuditEvent`
- `AuditLog`
- `AgentKernel`

## Required behavior

- Local Only blocks external provider delegation.
- Restricted sensitive data blocks automatic delegation.
- Highly private data requires explicit approval.
- Unknown intent asks clarification.
- Reminder creation routes to a local tool only when policy allows it.
- AgentKernel writes audit events for received tasks and policy decisions.

## Required validation

```bash
python scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

## Stop conditions

Stop and report clearly if:

- `ios/` cannot be created,
- Swift tests cannot run because Swift is unavailable,
- unexpected secrets, model weights or build artifacts are present,
- implementing the task would require an Xcode project or signing credentials,
- the change exceeds the allowed files.

## Draft PR body must include

- summary,
- changed files,
- data classes touched,
- validation output,
- limitations,
- next recommended task.
