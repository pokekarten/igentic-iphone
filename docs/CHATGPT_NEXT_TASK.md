# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

## Just completed

- Expanded the safe GitHub-control layer on branch `codex/github-control-dashboard`.
- Added read-only Python control scripts:
  - `scripts/control/collect_repo_state.py`
  - `scripts/control/collect_workflow_runs.py`
  - `scripts/control/render_control_report.py`
- Added GitHub Actions workflows:
  - `.github/workflows/control-dashboard.yml`
  - `.github/workflows/workflow-lint.yml`
- Added `docs/GITHUB_AUTOMATION_STRATEGY.md`.
- Updated `docs/WORKFLOWS.md` with Control Dashboard and Workflow Lint sections.
- No runtime app behavior, persistence, networking, model calls, external providers, CoreML, App Intents, secrets or private data were added.

## Current repo review

- The repo is public and now has stronger open-source collaboration surfaces: README, license, governance, support, security, code of conduct, contributor docs, issue templates, PR template, validation contract, GitHub-control runbook and workflow overview.
- Main Phase 1 safety stubs are present: policy, approval, tool registry, delegation broker, memory store, sensitive-data detector, risk scorer and scenario runner.
- GitHub Actions support validation, repo audit, docs consistency, main-health reporting, project control, issue triage, PR-quality checks, control-dashboard reporting and workflow linting.
- Issue #1 remains the active validation gate.
- Local Swift validation could not be executed in the ChatGPT environment, so validation is not complete yet.

## Next task

Run `.github/workflows/control-dashboard.yml`, inspect the generated report from the workflow summary, then run Phase 0 CI Validation on latest `main`.

Issue #1 must remain open until the required checks are actually executed and documented.

## Proposed files

```text
PROJECT_STATE.md
docs/CHATGPT_NEXT_TASK.md
```

Only change Swift code or validation code if validation fails and the smallest safe fix is obvious.

## Required behavior

- Run the Control Dashboard workflow manually.
- Inspect the latest control report from the workflow summary.
- Run or verify the required validation commands locally or through CI.
- Record exact pass/fail results.
- If a check fails, document the exact command, concise error summary and smallest safe next fix.
- Do not add app actions, persistence, networking, model calls, CoreML, App Intents, external providers, secrets or private data.

## Validation target

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```
