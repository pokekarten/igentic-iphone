# Project State

Last updated: 2026-07-23

## Current status

`iGentic iPhone` is an open-source, privacy-first iPhone AI Runtime Layer research repository.

- Repository: `pokekarten/igentic-iphone`
- Visibility: public
- Validation: GitHub Actions on macOS and Linux
- Primary target device: iPhone Air as trust/control plane
- Current phase: diagnostic shell and safe local-model boundary design

## Identity and community anchors

- Master brand: `iGentic`
- Community model: GitHub-first, social-supported
- Brand guidance: `docs/brand/BRAND.md`
- Brand asset manifest: `docs/brand/BRAND_ASSET_MANIFEST.md`
- Social profile asset: `assets/social/instagram-profile-v3.svg`
- Community strategy: `docs/community/COMMUNITY_STRATEGY.md`

These are durable project anchors required by repository validation. They do not describe a live work target.

## Source-of-truth contract

Current GitHub source is authoritative for pull requests, issues, branches, checks and merged state.

The only mutable source for the active iGentic target and lane stage is:

```text
pokekarten/agentic-private-brain issue #25
```

## Current baseline

- The repository baseline is the last verified GitHub state on `main` plus the durable project-state record in this file.
- PR #156 / issue #156 (`Consolidate trivial duplicated helpers and remove orphaned placeholder files`) is merged on GitHub.
- PR #158 / issue #158 (`Consolidate effective-classification logic and close sensitive-data scan gap in AppActionCoordinator`) is merged on GitHub.
- There is no live implementation PR encoded in this file.

## Current safety posture

- Treat this file as durable state only.
- Do not revive completed targets from this file.
- Do not infer active work from memory when GitHub or repo files provide the current answer.
- Keep the active work constrained to the current control record and the existing validation contract.

## Active-work lookup

When determining what to work on next, check sources in this order:

1. Current GitHub repository state.
2. `docs/CHATGPT_NEXT_TASK.md`.
3. `pokekarten/agentic-private-brain` issue #25.
4. The durable notes in this file.

## Validation contract

- GitHub Actions on macOS and Linux are the primary validation signals.
- Local verification should stay aligned with the repository’s existing scripts and test suites.
- Keep validation changes scoped to the files under active work.

## Evidence boundary

- Use GitHub and repository files as the source of truth.
- Do not rely on stale memory when an issue, PR, or file can be checked directly.
- Do not treat this file as evidence of a currently open implementation target.

## Durable next-direction rules

- Preserve the distinction between durable state and active work.
- Keep completed work recorded here only as completed work.
- Prefer the smallest safe next step that matches the current control record.
- If the control record and GitHub diverge, GitHub wins.

## Recently completed

- PR #156 / issue #156 (`Consolidate trivial duplicated helpers and remove orphaned placeholder files`) is merged on GitHub; `ios/Tests/iGenticAppTests/DiagnosticViewStateTests.swift`, `scripts/evaluate_action_proposals.py`, `__branch_init__`, and `__noop_check__` are closed out.
- PR #158 / issue #158 (`Consolidate effective-classification logic and close sensitive-data scan gap in AppActionCoordinator`) is merged on GitHub; `DataClassification.effectiveClassification` now feeds `AgentKernel`, `DiagnosticSnapshotProducer`, and `AppActionCoordinator`.
- MemoryStore integration decision: intentionally left as a pre-integration stub, matching DelegationBroker's pattern. See `docs/reports/memory-store-integration-decision.md`.
- Phase 2 model-selection PR #99 (`phase2/model-selection-engine-v3`) is closed on GitHub and was not merged; it is no longer the active implementation target.
- Metadata-only `RuntimeBudget`, `ApprovalReceipt`, `DiagnosticSnapshot` and `LocalModelRuntime` contracts are on `main`.
- `ios/Tests/AgentCoreTests/RiskScorerTests.swift` now covers the full approval-gate scoring surface: baseline score, action-risk contributions, delegation-target contributions including the `trustedDevices` + `externalProvider` coupling, sensitive-data accumulation, clamping to 10, and the approval threshold boundary.
- `ios/Tests/AgentCoreTests/SensitiveDataDetectorTests.swift` now includes the regression coverage for the `containsGermanPhoneLikePattern` length cap, plus reset and no-reset behavior around accumulation.
- `ios/Tests/AgentCoreTests/AgentKernelSensitiveDataWiringTests.swift` now covers the end-to-end sensitive-data wiring in `AgentKernel.handle()` and audit propagation.
- Raw task text was removed from task-received `AuditLog` events.
- `ApprovalRequest` no longer carries raw user task text; task summary is now metadata-only (classification/risk only).
- `LocalModelRuntime.assess()` is called from `AgentKernel.handle()`; rejection blocks routing and is recorded in the audit log. Covered end-to-end by `ios/Tests/AgentCoreTests/AgentKernelLocalModelRuntimeWiringTests.swift`.
- The workflow dependency reference used by the bootstrap ZIP workflow was updated from `actions/checkout@v6` to `@v7`.
- Repository hygiene now treats undocumented root placeholder artifacts as cleanup candidates rather than durable content.
- Issues #25, #29, #58 and #59 are closed for their documented scope.
- CoreML feasibility spike Issue #111 is blocked pending an owner-supplied local model artifact; no network/download automation was attempted and no runtime wiring was changed.

## Current next task

There is currently no active implementation target; the repo is in manual mode. Read `docs/CHATGPT_NEXT_TASK.md` and Brain issue #25 as the current control record before taking any action.
