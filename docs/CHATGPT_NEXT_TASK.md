# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

## Just completed

- Removed the accidental empty root file `DUMMY` on branch `chatgpt/cleanup-validation-state`.
- Re-reviewed current repo state through the GitHub Connector:
  - project files could be read,
  - open GitHub issues could be inspected,
  - active task source remains this file.
- Updated `PROJECT_STATE.md` with a conservative validation status.
- No runtime code, policy behavior, tests, networking, providers, persistence, secrets, model calls or private data were changed.

## Current repo review

- Main Phase 1 safety stubs are present: policy, approval, tool registry, delegation broker, memory store, sensitive-data detector, risk scorer and scenario runner.
- Open issues now exist and should be treated as the public task backlog.
- Issue #1 remains the active validation gate.
- Local checks could not be executed in the ChatGPT environment, so validation is not complete yet.

## Next task

Run and verify the validation suite after the latest safety-bootstrap, contributor-onboarding and cleanup commits, then record the result.

Issue #1 must remain open until the required checks are actually executed and documented.

## Proposed files

```text
PROJECT_STATE.md
docs/CHATGPT_NEXT_TASK.md
```

Only change Swift code or validation code if validation fails and the smallest safe fix is obvious.

## Required behavior

- Run the required validation commands locally or through CI.
- Record exact pass/fail results.
- If a check fails, document the exact command, concise error summary and smallest safe next fix.
- Do not add app actions, persistence, networking, model calls, CoreML, App Intents, external providers, secrets or real private data.
- If validation passes, propose the next conservative code step:
  - Issue #5: add PolicyEngine edge-case tests, or
  - Issue #9: integrate `RiskScorer` into `PolicyEngine` as metadata without loosening approval/blocking behavior.

## Validation target

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```
