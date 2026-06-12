# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

## Just completed

- Expanded `.github/workflows/repo-audit.yml` with weekly scheduled audits and public control-file checks.
- Added `.github/workflows/docs-consistency.yml` to verify local documentation references and validation markers.
- Added `.github/workflows/main-health.yml` to report and fail on failed upstream workflow completions.
- Added `.github/workflows/project-control.yml` for manual, scheduled and repository-dispatch project-control summaries.
- Added `.github/workflows/issue-triage.yml` to label and comment on public issues that are missing planning fields.
- Added `.github/workflows/pr-quality.yml` to require useful PR body structure and validation evidence.
- Added `docs/WORKFLOWS.md` and linked it from `README.md`.

## Current repo review

- The repo is public and now has stronger open-source collaboration surfaces: README, license, governance, support, security, code of conduct, contributor docs, issue templates, PR template, validation contract, GitHub-control runbook and workflow overview.
- Main Phase 1 safety stubs are present: policy, approval, tool registry, delegation broker, memory store, sensitive-data detector, risk scorer and scenario runner.
- GitHub Actions now support validation, repo audit, docs consistency, main-health reporting, project control, issue triage and PR-quality checks.
- Issue #1 remains the active validation gate.
- Local checks could not be executed in the ChatGPT environment, so validation is not complete yet.

## Next task

Run and verify the validation suite on the latest `main` commit after the workflow setup, then record the result.

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
