# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

## Just completed

- `DelegationBroker` was added as a safe policy-gated stub.
- Delegation decisions are metadata-only.
- Local Only blocks delegation.
- External provider targets require explicit approval.
- Critical action risk requires explicit approval.
- Safe trusted-device paths can be allowed only as metadata decisions.

## Next task

Add a Diagnostic Shell / Scenario Runner as a dry-run test harness.

## Proposed files

```text
ios/Sources/AgentCore/ScenarioRunner.swift
ios/Tests/AgentCoreTests/SmokeTests.swift
scripts/validate_repo_structure.py
PROJECT_STATE.md
docs/CHATGPT_NEXT_TASK.md
```

## Validation target

```bash
python scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```
