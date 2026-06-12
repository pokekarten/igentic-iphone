# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

## Just completed

- Added `docs/VALIDATION.md` as the validation contract and Issue #1 closure rule.
- Added `docs/GITHUB_CONTROL.md` as the GitHub-first control runbook.
- Strengthened `.github/PULL_REQUEST_TEMPLATE.md` with explicit validation evidence and safety checklist sections.
- Added `.github/ISSUE_TEMPLATE/validation_task.md` for CI/build/test verification tasks.
- Added `.github/dependabot.yml` for weekly GitHub Actions dependency review PRs.
- Linked the new control and validation docs from `README.md`.
- Corrected one accidental placeholder commit on `main`; no placeholder content remains.

## Current repo review

- The repo is public and now has stronger open-source collaboration surfaces: README, license, governance, support, security, code of conduct, contributor docs, issue templates, PR template, validation contract and GitHub-control runbook.
- Main Phase 1 safety stubs are present: policy, approval, tool registry, delegation broker, memory store, sensitive-data detector, risk scorer and scenario runner.
- Issue #1 remains the active validation gate.
- Local checks could not be executed in the ChatGPT environment, so validation is not complete yet.

## Next task

Run and verify the validation suite after the latest safety-bootstrap, contributor-onboarding, cleanup and GitHub-control commits, then record the result.

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
- Do not add app actions, persistence, networking, model calls, CoreML, App Intents, external providers or private data.
- If validation passes, propose the next conservative code step:
  - Issue #5: add PolicyEngine edge-case tests, or
  - Issue #9: integrate `RiskScorer` into `PolicyEngine` as metadata without loosening approval/blocking behavior.

## Validation target

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```
