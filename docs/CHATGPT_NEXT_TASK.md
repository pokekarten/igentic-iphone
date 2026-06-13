# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

ChatGPT works through the GitHub Connector for repository-control, review, documentation/process changes and narrow pull-request based implementation slices.

Codex can later be used only through explicit narrow Draft PR handoffs. Current active work is still handled directly through ChatGPT because the slice is small and reviewable.

## Recently completed

PR #32 `Issue #26: clarify validation and PR scope evidence` has been completed and merged into `main`.

Status:

- PR #32 was marked Ready for review.
- PR #32 was squash-merged into `main` as `8cfad90d8eae909c6cc61583ce01f732e813ec97`.
- Issue #26 was closed as completed.
- PR scope, privacy, action risk, approval/delegation behavior, safety and validation provenance are now explicit in the PR path.
- No Swift runtime behavior, workflow YAML, secrets, networking, App Intents, external providers, signing files, private data or Pokekartenkiste files were changed.

Validation evidence for PR #32:

- PR-head `0479eb4ba944b0267ca82b585719f25b07b5a9d2` had green GitHub checks:
  - Docs Consistency
  - Pull Request Quality
  - Repo Audit
  - PR Change Scope
  - Swift
  - Phase 0 CI Validation

## Active cycle

Target: Issue #10 `Code: Add DiagnosticSnapshot for Phase 2 readiness`.

Goal: add a small metadata-only `DiagnosticSnapshot` model in AgentCore so the future diagnostic iPhone shell can display safe local status without coupling SwiftUI to internal runtime types.

Current branch:

```text
chatgpt/issue10-diagnostic-snapshot
```

## Current implementation status

Started on branch `chatgpt/issue10-diagnostic-snapshot`:

- Added `ios/Sources/AgentCore/DiagnosticSnapshot.swift`.
- Added a smoke test for metadata-only diagnostic summaries.
- Updated `scripts/validate_repo_structure.py` to require the new core file and `DiagnosticSnapshot` project-state marker.
- Updated `PROJECT_STATE.md` to document the active Issue #10 slice.

## Next task

Open a Draft PR for Issue #10 after final file review:

1. Confirm changed files stay within Issue #10 scope:
   - `ios/Sources/AgentCore/DiagnosticSnapshot.swift`
   - `ios/Tests/AgentCoreTests/SmokeTests.swift`
   - `scripts/validate_repo_structure.py`
   - `PROJECT_STATE.md`
   - `docs/CHATGPT_NEXT_TASK.md`
2. Open a Draft PR against `main`.
3. Let GitHub Actions run.
4. Review failures by log, not by guessing.
5. If checks pass, mark ready and merge.

## Guardrails

- Do not add SwiftUI.
- Do not add App Intents.
- Do not add persistence.
- Do not add networking or external providers.
- Do not add model calls.
- Do not add screenshots or signing files.
- Do not use real private data.
- Do not touch Pokekartenkiste files or references.
