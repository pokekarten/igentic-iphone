# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-19

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, head SHA, changed files, checks, review threads and issue scope.

## Current operating mode

Mode: `IGENTIC_OWNER_BOUNDARY_READY`.

- iGentic remains the active repository context.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions remain the independent validation environment.
- Codex remains paused.
- The limited four-slot burst has completed its safe autonomous targets and all four scheduled roles are paused.
- Do not open speculative implementation work while the next decisions require repository-owner or Apple/Xcode input.

## Recently completed

- PR #40 `Guard SwiftUI and validate the package on Linux` was squash-merged into `main` as `1f13a0c3bf7d4d9625a9adb2a52a62a06e00c1c6` after macOS, Linux, workflow, documentation, scope and repository checks passed.
- PR #41 `Sync project state after PR #40` was squash-merged into `main` as `adb8b61c87e3207be2e33da917db2336d9aa4d54` after all applicable checks passed.
- Issue #11 `ScenarioReport exporter` was verified against current implementation and closed as completed.
- Issue #7 `device test checklist` was verified against the checklist, issue template and report template and closed as completed.
- Issue #29 remains open for actual physical-device execution and evidence.

## Current repository state

- `AgentCore` and `iGenticApp` compile and test through public GitHub Actions on macOS and Linux.
- `ScenarioReport` provides deterministic metadata-only diagnostic output.
- `DiagnosticView` provides the tested SwiftUI diagnostic surface.
- The real-device checklist and report template are ready.
- The repository still contains a Swift package library, not an installable signed iOS application.

## Current owner boundary

The next meaningful product step requires joint decisions:

1. Configure the `main` repository ruleset and merge settings in GitHub UI.
2. Decide whether to add the minimal installable Xcode app wrapper.
3. Choose the bundle identifier and Apple Developer Team locally in Xcode.
4. Configure signing without committing credentials, profiles or account identifiers.
5. Run the physical-device checklist and complete Issue #29 evidence.

## Stop rules

Do not autonomously start or configure:

- an installable Xcode app wrapper without explicit approval,
- bundle identifier, Apple Developer Team, signing or provisioning,
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

Until the owner session occurs:

- `OWNER_BOUNDARY`
- `BEN` only for the explicit repository-owner, Xcode, signing or physical-device step
