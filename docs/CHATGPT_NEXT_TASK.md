# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

## Just completed

- Added `ios/Sources/AgentCore/SensitiveDataDetector.swift`.
- Added `ios/Sources/AgentCore/RiskScorer.swift`.
- `SensitiveDataDetector` detects only metadata categories for:
  - IBAN-like strings
  - email-like strings
  - phone-like strings
- The detector returns categories and reasons only; it does not retain or expose raw matched sensitive values.
- `RiskScorer` returns a deterministic 1-10 score using:
  - privacy mode
  - data sensitivity level
  - action risk
  - delegation target
  - detected sensitive categories
- Smoke tests now cover sensitive-data category detection, no raw-value retention, low-risk local reads, external-provider risk escalation, critical-action risk and IBAN-like high-risk scoring.
- Existing `MemoryStore` smoke tests remain present.
- Repo structure validation now requires `MemoryStore`, `SensitiveDataDetector` and `RiskScorer`.
- No persistence, networking, external dependencies, model calls, app intents, secrets or real private data were added.

## Current repo review

- Open issues found previously: none.
- Open pull requests found previously: none.
- Main Phase 1 safety stubs now present: policy, approval, tool registry, delegation broker, memory store, sensitive-data detector, risk scorer and scenario runner.
- Latest observed CI problem previously: GitHub Actions runs showed `Startup failure`, so workflows were reduced to shell-only checkout and validation steps.

## Next task

Run and verify the validation suite after the latest safety-bootstrap commits, then record the result.

## Proposed files

```text
PROJECT_STATE.md
docs/CHATGPT_NEXT_TASK.md
```

Only change Swift code in the next task if validation fails or if the smallest safe fix is obvious.

## Required behavior

- Check the latest GitHub Actions result for the latest safety-bootstrap commits, or run locally if working from a clone.
- Confirm repo structure validation, Swift tests and Swift build.
- Do not add app actions, persistence, networking, model calls, CoreML, App Intents or secrets.
- If validation fails, document the exact failing check and propose the smallest safe fix.
- If validation passes, propose a conservative next implementation step: integrate `RiskScorer` into `PolicyEngine` as decision metadata without loosening existing approval/blocking behavior.

## Validation target

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```
