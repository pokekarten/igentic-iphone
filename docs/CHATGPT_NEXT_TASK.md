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
- `ToolRegistry` was added as a metadata-only registry.
- Tool registry tests cover lookup and sorted snapshot behavior.

## Next task

Add a safe `MemoryStore` stub before adding local RAG, embeddings or real private memory.

## Why

The runtime needs a clear memory boundary before it stores any context. Memory must be scoped, deletable and metadata-only at first. No real user data should be stored in this phase.

## Proposed files

```text
ios/Sources/AgentCore/MemoryStore.swift
ios/Tests/AgentCoreTests/SmokeTests.swift
scripts/validate_repo_structure.py
PROJECT_STATE.md
docs/CHATGPT_NEXT_TASK.md
```

## Required behavior

- Add `MemoryScope` with local-only-safe scopes.
- Add `MemoryRecord` with id, scope, data level, title and synthetic content.
- Add `MemoryStore` that can save, list by scope and delete by id.
- Keep storage in-memory only.
- Do not add embeddings, vector search, file access or real private data yet.

## Validation target

```bash
python scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

## Stop rules

Stop if the change would require real user data, files, contacts, calendars, embeddings, model runtimes, persistence, encryption APIs or broader runtime rewrites.
