# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

## Just completed

- `MemoryStore` is available as a safe in-memory stub.
- `MemoryScope` currently supports `session` and `task`.
- Entries are stored in process memory only and grouped by scope.
- The store supports save, list by scope and delete by scope.
- No persistence, networking, external dependencies, model calls, app intents or secrets were added.
- Smoke tests cover saving, scoped listing, overwriting within a scope and deleting only the requested scope.
- Repo structure validation now requires `ios/Sources/AgentCore/MemoryStore.swift`.
- GitHub Actions workflows were hardened to avoid marketplace checkout/setup actions during CI startup.

## Current repo review

- Open issues found previously: none.
- Open pull requests found previously: none.
- Main Phase 1 safety stubs now present: policy, approval, tool registry, delegation broker, memory store and scenario runner.
- Latest observed CI problem: GitHub Actions runs showed `Startup failure`, so workflows were reduced to shell-only checkout and validation steps.

## Next task

Run and verify the validation suite after the latest workflow hardening commit, then record the result.

## Proposed files

```text
PROJECT_STATE.md
docs/CHATGPT_NEXT_TASK.md
```

## Required behavior

- Check the latest GitHub Actions result for the workflow-hardening commit, or run locally if working from a clone.
- Confirm repo structure validation, Swift tests and Swift build.
- Do not add app actions, persistence, networking, model calls or secrets.
- If CI still fails, document the exact failing check and propose the smallest safe fix.

## Validation target

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```
