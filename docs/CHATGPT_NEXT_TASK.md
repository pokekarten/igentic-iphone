# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

## Current operating mode

Codex is paused for now. ChatGPT works directly through the GitHub Connector on small, safe repository changes.

## Just completed

- Added and linked contributor-facing onboarding improvements:
  - `docs/community/CONTRIBUTOR_STARTER_GUIDE.md`
  - `docs/community/GOOD_FIRST_ISSUES.md`
  - `assets/brand/README.md`
  - `.github/ISSUE_TEMPLATE/good_first_issue.md`
  - `.github/ISSUE_TEMPLATE/config.yml`
- Updated `README.md` with a New contributors section and safe contribution lanes.
- Updated `CONTRIBUTING.md` with starter-guide, good-first-issue, design-style and brand guidance.
- Expanded `scripts/validate_repo_structure.py` so repo validation now checks:
  - brand and community docs,
  - issue and PR templates,
  - required README and PROJECT_STATE markers,
  - non-empty required files,
  - accessible SVG metadata for brand assets.
- Updated `PROJECT_STATE.md` to record the contributor-onboarding and design/repo-validation hardening.
- No app actions, persistence, networking, model calls, secrets, real private data or external dependencies were added.

## Current repo review

- Open issues found previously: none.
- Open pull requests found previously: none.
- Main Phase 1 safety stubs are present: policy, approval, tool registry, delegation broker, memory store, sensitive-data detector, risk scorer and scenario runner.
- Latest observed CI problem previously: GitHub Actions runs showed `Startup failure`, so workflows were reduced to shell-only checkout and validation steps.

## Next task

Run and verify the validation suite after the latest safety-bootstrap and contributor-onboarding commits, then record the result.

## Proposed files

```text
PROJECT_STATE.md
docs/CHATGPT_NEXT_TASK.md
```

Only change Swift code or validation code in the next task if validation fails or if the smallest safe fix is obvious.

## Required behavior

- Check the latest GitHub Actions result for the latest commits, or run locally if working from a clone.
- Confirm repo structure validation, Swift tests and Swift build.
- Do not add app actions, persistence, networking, model calls, CoreML, App Intents or secrets.
- If validation fails, document the exact failing check and propose the smallest safe fix.
- If validation passes, propose a conservative next implementation step: integrate `RiskScorer` into `PolicyEngine` as decision metadata without loosening existing approval/blocking behavior.
- Optional follow-up after validation: convert 3-5 entries from `docs/community/GOOD_FIRST_ISSUES.md` into real GitHub issues.

## Validation target

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```
