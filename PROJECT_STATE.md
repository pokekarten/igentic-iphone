# Project State

This file stores durable project state only. It must not store a live PR number, current PR head SHA, mergeability result or lane stage. A completed target must never be revived from this file.

## Required status markers

- Master brand: `iGentic`
- Community model: GitHub-first, social-supported
- `docs/brand/BRAND.md`
- `docs/brand/BRAND_ASSET_MANIFEST.md`
- `assets/social/instagram-profile-v3.svg`
- `docs/community/COMMUNITY_STRATEGY.md`

## Recently completed

- PR #156 / issue #156 (`Consolidate trivial duplicated helpers and remove orphaned placeholder files`) is merged on GitHub; `ios/Tests/iGenticAppTests/DiagnosticViewStateTests.swift`, `scripts/evaluate_action_proposals.py`, `__branch_init__`, and `__noop_check__` are closed out.
- PR #158 / issue #158 (`Consolidate effective-classification logic and close sensitive-data scan gap in AppActionCoordinator`) is merged on GitHub; `DataClassification.effectiveClassification` now feeds `AgentKernel`, `DiagnosticSnapshotProducer`, and `AppActionCoordinator`.
- MemoryStore integration decision: intentionally left as a pre-integration stub, matching DelegationBroker's pattern. See docs/reports/memory-store-integration-decision.md.
- Phase 2 model-selection PR #99 (`phase2/model-selection-engine-v3`) is closed on GitHub and was not merged; it is no longer the active implementation target.
- Metadata-only RuntimeBudget, ApprovalReceipt, DiagnosticSnapshot and LocalModelRuntime contracts are on `main`.
- `ios/Tests/AgentCoreTests/RiskScorerTests.swift` now covers the full approval-gate scoring surface: baseline score, action-risk contributions, delegation-target contributions including the `trustedDevices` + `externalProvider` coupling, sensitive-data accumulation, clamping to 10, and the approval threshold boundary.
- `ios/Tests/AgentCoreTests/SensitiveDataDetectorTests.swift` now includes the regression coverage for the `containsGermanPhoneLikePattern` length cap, plus reset and no-reset behavior around accumulation.
- `ios/Tests/AgentCoreTests/AgentKernelSensitiveDataWiringTests.swift` now covers the end-to-end sensitive-data wiring in `AgentKernel.handle()` and audit propagation.
- Raw task text was removed from task-received AuditLog events.
- ApprovalRequest no longer carries raw user task text; task summary is now metadata-only (classification/risk only).
- LocalModelRuntime.assess() is called from AgentKernel.handle(); rejection blocks routing and is recorded in the audit log. Covered end-to-end by AgentKernelLocalModelRuntimeWiringTests.swift.
- The workflow dependency reference used by the bootstrap ZIP workflow was updated from `actions/checkout@v6` to `@v7`.
- Repository hygiene now treats undocumented root placeholder artifacts as cleanup candidates rather than durable content.
- Issues #25, #29, #58 and #59 are closed for their documented scope.
- CoreML feasibility spike Issue #111 is blocked pending an owner-supplied local model artifact; no network/download automation was attempted and no runtime wiring was changed.

## Current next task

There is currently no active implementation target; the repo is in manual mode. Read `docs/CHATGPT_NEXT_TASK.md` and Brain issue #25 as the current control record before taking any action.
