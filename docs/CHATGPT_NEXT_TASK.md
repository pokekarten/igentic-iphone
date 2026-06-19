# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-19

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, head SHA, changed files, checks, review threads and issue scope.

## Current operating mode

Mode: `IGENTIC_LIMITED_AUTONOMOUS_BURST`.

- iGentic is the only active repository lane.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions are the primary independent validation environment.
- Use exactly one active PR or issue target at a time.
- Four scheduled roles are active for three hourly cycles: director, worker, gate-and-merge, review-and-stop.
- Old product, support, research and Pokekartenkiste slots remain disabled.
- Codex remains paused.

## Recently completed

PR #40 `Guard SwiftUI and validate the package on Linux` was squash-merged into `main` as `1f13a0c3bf7d4d9625a9adb2a52a62a06e00c1c6`.

Before merge:

- PR Change Scope passed.
- Pull Request Quality passed.
- Docs Consistency passed.
- Repo Audit passed.
- Workflow Lint passed.
- macOS Swift build and tests passed.
- Linux Swift build and tests passed.
- Phase 0 CI Validation passed.
- No unresolved review threads remained.

The cross-platform SwiftUI import regression is fixed and now covered by Linux CI.

## Current repository state

- No open pull request was present at the latest verification.
- The tested `AgentCore` and `iGenticApp` package products remain the current product baseline.
- Real-device validation remains pending.
- An installable Xcode app target, bundle identifier, Apple signing and a physical-device run remain owner boundaries.

## Autonomous burst target order

Select exactly one target per cycle:

1. Verify Issue #11 against the merged deterministic `ScenarioReport` implementation and close it only if all acceptance criteria are satisfied.
2. Verify Issue #7 against `docs/device-test-checklist.md`, the device-test issue template and the validation report template; close it only if all acceptance criteria are satisfied.
3. Synchronize `PROJECT_STATE.md` or another project-local pointer only when current GitHub truth materially changed.
4. If no safe autonomous cleanup remains, stop at the owner boundary rather than opening speculative product work.

Issue #29 must remain open for the actual physical-device validation boundary.

## Worker rules

- Re-read current GitHub source before every write.
- Never create parallel implementation PRs.
- For issue cleanup, cite the current files and merged validation evidence.
- For a code or workflow change, use one narrow Draft PR and require current-head checks.
- Do not repeat comments, handoffs or status reports without new evidence.

## Owner boundary

Do not autonomously start or configure:

- an installable Xcode app wrapper,
- bundle identifier or Apple Developer Team,
- signing or provisioning,
- physical-device installation or test claims,
- GitHub rulesets or repository-owner UI settings,
- networking, providers, persistence, App Intents, model calls, secrets or real private data.

## Required repository validation

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

Linux package validation is additionally represented by the `Swift package Linux build and test` CI job.

## Expected terminal result

One of:

- `CLEANUP_DONE`
- `PR_OPENED`
- `FIX_APPLIED`
- `MERGED`
- `WAITING_RUNNER`
- `OWNER_BOUNDARY`
- `BEN` only for the explicit owner/signing/device boundary
