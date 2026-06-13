# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

ChatGPT works through the GitHub Connector for repository-control, review and small documentation/process changes. Runtime/code changes should stay narrow and use pull requests before merge.

Codex remains paused until the validation and PR-scope path is stable enough for repeatable Draft PR handoffs.

## Recently completed

PR #31 `Issue #18: add ApprovalReceipt metadata` has been completed and merged into `main`.

Status:

- PR #31 was marked Ready for review.
- PR #31 was squash-merged into `main` as `c4e8bb137201382e73b86b81a69a465db87cc559`.
- Issue #18 was closed as completed.
- ApprovalReceipt is now part of AgentCore metadata.
- Pending and rejected receipts keep routing blocked; approved/notRequired receipts may continue routing.
- No persistence, networking, model calls, telemetry, secrets or private raw data were added.

Validation evidence for the PR:

- PR-head `d9cec48838bf31ce3e872c3d03a6eb9a25441334` had green GitHub checks:
  - Pull Request Quality
  - Docs Consistency
  - PR Change Scope
  - Repo Audit
  - Swift
  - Phase 0 CI Validation
- Local ZIP snapshot evidence was also recorded for:
  - `python3 scripts/validate_repo_structure.py`
  - `python3 scripts/validation_summary.py`
  - `cd ios && swift test`
  - `cd ios && swift build`

## Active cycle

Target: Issue #26 `MVP-01: Make validation and PR scope checks the default contributor path`.

Goal: make every future PR easier to review by making scope, validation provenance and exact evidence visible by default.

Current branch:

```text
chatgpt/issue26-validation-scope-control
```

## Next task

Create a small process/documentation PR for Issue #26:

1. Update `.github/PULL_REQUEST_TEMPLATE.md` so every PR records:
   - changed files,
   - scope category,
   - privacy/data class impact,
   - action risk,
   - approval/delegation behavior,
   - exact validation provenance.
2. Update `scripts/validation_summary.py` so it prints a copy-pasteable validation evidence block and clearly states that it does not execute Swift or GitHub Actions.
3. Update `PROJECT_STATE.md` to reflect:
   - PR #31 merged,
   - Issue #18 completed,
   - Issue #26 is the active control task.
4. Open a Draft PR against `main`.

## Guardrails

- Do not change Swift runtime code for this task.
- Do not change workflows unless directly required by Issue #26.
- Do not add secrets, network calls, external providers, App Intents, signing files or private data.
- Do not touch Pokekartenkiste files or references.
- Do not claim Swift build/test success unless backed by a specific local run or GitHub Actions run.
- Keep the change documentation/process-only.
