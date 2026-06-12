# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

## Just completed

- `AuditLog` was made thread-safe with a lock while keeping the synchronous API.
- Smoke tests now cover audit log recording and snapshot behavior.

## Next task

Implement the approval-state guard before adding real App Intents or external delegation.

## Why

The agent kernel must not treat `.pending` or `.rejected` approval states as executable results. Approval must become a first-class gate before any runtime action layer exists.

## Proposed files

```text
ios/Sources/AgentCore/ApprovalManager.swift
ios/Sources/AgentCore/AgentKernel.swift
ios/Tests/AgentCoreTests/SmokeTests.swift
PROJECT_STATE.md
docs/CHATGPT_NEXT_TASK.md
```

## Required behavior

- Add `ApprovalStatus` with at least `.approved`, `.pending`, `.rejected`.
- Add `ApprovalRequest` and `ApprovalManager` as a safe stub.
- If `PolicyDecision.requiresApproval == true`, `AgentKernel` must return an approval-required or blocked response before routing to a tool.
- Do not add real App Intents or external actions yet.

## Validation target

```bash
python scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

## Stop rules

Stop if the change would require async app UI, signing, Apple Developer credentials, real user data, or broader runtime rewrites.
