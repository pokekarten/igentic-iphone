# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

## Just completed

- `DelegationBroker` is available as a safe policy-gated stub.
- `ScenarioRunner` is available as a dry-run harness.
- Scenario outputs cover synthetic policy, approval, routing and delegation decisions.
- The runner uses metadata-only synthetic examples.
- Smoke tests cover the default scenarios.

## Current repo review

- Open issues found: none.
- Open pull requests found: none.
- Main remaining bootstrap gap: `MemoryStore` safe stub.

## Next task

Add a safe `MemoryStore` stub.

## Proposed files

```text
ios/Sources/AgentCore/MemoryStore.swift
ios/Tests/AgentCoreTests/SmokeTests.swift
scripts/validate_repo_structure.py
PROJECT_STATE.md
docs/CHATGPT_NEXT_TASK.md
```

## Required behavior

- Add scoped in-memory metadata storage only.
- Include scopes such as `session` and `task`.
- Support save, list by scope and delete by scope.
- Do not persist data.
- Do not add model calls, networking, secrets or app actions.

## Validation target

```bash
python scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```
