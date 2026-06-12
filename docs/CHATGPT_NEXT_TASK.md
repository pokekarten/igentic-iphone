# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

## Just completed

- `AuditLog` was made thread-safe with a lock while keeping the synchronous API.
- Smoke tests cover audit log recording and snapshot behavior.
- `ApprovalManager` was added as a safe stub.
- `AgentKernel` now gates routing when policy requires approval.
- Pending approval stops routing; approved status allows routing to continue.

## Next task

Add a safe `ToolRegistry` stub before adding real App Intents.

## Why

The runtime should know which tools exist, what data level they require and what action risk they carry before any real iOS action is wired in. This keeps tool execution policy-aware from the start.

## Proposed files

```text
ios/Sources/AgentCore/ToolRegistry.swift
ios/Tests/AgentCoreTests/SmokeTests.swift
scripts/validate_repo_structure.py
PROJECT_STATE.md
docs/CHATGPT_NEXT_TASK.md
```

## Required behavior

- Add `ToolDefinition` with name, required data level and action risk.
- Add `ToolRegistry` that can register and look up tools by name.
- Do not add real tool execution yet.
- Do not add App Intents yet.
- Keep this as a local metadata registry only.

## Validation target

```bash
python scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

## Stop rules

Stop if the change would require real iOS permissions, App Intents, signing, private data, external providers, or broader runtime rewrites.
