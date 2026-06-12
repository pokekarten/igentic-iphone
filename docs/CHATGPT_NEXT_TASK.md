# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

All future work should follow `docs/PROJECT_OPERATING_MODEL.md` once that PR is merged.

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
- Started a process-improvement PR on branch `chatgpt/project-operating-model` to make the ChatGPT/Codex/contributor workflow durable in the repo.
- Integrated `RiskScorer` into `PolicyEngine` on branch `codex/risk-scorer-policy-metadata` as decision metadata only.
- Added smoke-test coverage showing safe decisions stay safe, local-only/restricted/critical approval behavior is preserved, risk metadata is present, and risk-score metadata alone does not add approval behavior.
- No runtime app behavior, persistence, networking, model calls, external providers, CoreML, App Intents, secrets or private data were added.

## Current repo review

- The repo is public and now has stronger open-source collaboration surfaces: README, license, governance, support, security, code of conduct, contributor docs, issue templates, PR template, validation contract, GitHub-control runbook and workflow overview.
- Main Phase 1 safety stubs are present: policy, approval, tool registry, delegation broker, memory store, sensitive-data detector, risk scorer and scenario runner.
- GitHub Actions support validation, repo audit, docs consistency, main-health reporting, project control, issue triage, PR-quality checks, control-dashboard reporting and workflow linting.
- Issue #1 remains the active validation gate.
- Local validation passed in the Codex environment for `codex/risk-scorer-policy-metadata`; Issue #1 remains open until latest `main` validation is recorded.

## Next task

Review the `codex/risk-scorer-policy-metadata` Draft PR first. Merge it only if the diff remains limited to the allowed files, tests stay green, and approval/blocking behavior is confirmed unchanged.

After that, review and merge the `chatgpt/project-operating-model` PR only if checks pass and the scope remains documentation/process only. Then run `.github/workflows/control-dashboard.yml`, inspect the generated report from the workflow summary, and run Phase 0 CI Validation on latest `main`.

Issue #1 must remain open until the required checks are actually executed and documented.

## Proposed files for the next review

```text
ios/Sources/AgentCore/PolicyEngine.swift
ios/Sources/AgentCore/RiskScorer.swift
ios/Tests/AgentCoreTests/SmokeTests.swift
PROJECT_STATE.md
docs/CHATGPT_NEXT_TASK.md
```

Only change Swift code or validation code if validation fails and the smallest safe fix is obvious. Keep `RiskScorer` output metadata-only unless a future explicit policy task changes approval behavior with tests.

## Required behavior

- Keep `main` clean: no direct commits.
- Use one branch per task and one PR per branch.
- Run or verify relevant GitHub Actions before merge.
- Run the Control Dashboard workflow manually after process PR merge.
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
