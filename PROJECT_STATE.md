# Project State

Last updated: 2026-07-21

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

This file stores durable project state only. It must not store a live PR number, current PR head SHA, mergeability result or lane stage. A completed target must never be revived from this file.

## Recently completed

- PR #156 / issue #156 (`Consolidate trivial duplicated helpers and remove orphaned placeholder files`) is merged on GitHub; `DiagnosticViewState.swift`, `scripts/evaluate_action_proposals.py`, `__branch_init__`, and `__noop_check__` are closed out.
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

## Current baseline

`main` includes:

- AgentCore policy, approval, audit, routing, risk, memory and delegation components,
- lock-protected AuditLog storage and metadata projections,
- metadata-only runtime and diagnostic contracts,
- deterministic pre-invocation rejection tests,
- synthetic scenario and diagnostic UI support,
- an unsigned simulator wrapper and automated validation workflows,
- a privacy-safe physical-device checklist and report template.

## Current safety posture

- Policy and approval remain authoritative before action.
- Diagnostic and runtime contracts remain metadata-only.
- Restricted sensitive data remains blocked before automatic external delegation.
- No real model loading, networking, persistence, provider call, tool execution or App Intents execution exists.
- Software contracts are not physical-device performance evidence.
- No signing, installation, launch or physical-device result is claimed.

## Active-work lookup

Before acting:

1. Read Brain issue #25 for the active target and expected role.
2. Re-read the named GitHub PR or issue.
3. Treat merged or closed targets as stale regardless of any remembered context.
4. Perform only the mutation allowed by the current lane stage.
5. Re-read the exact resource after writing.

## Validation contract

```bash
python3 scripts/validate_repo_structure.py
python3 scripts/validation_summary.py
cd ios && swift test
cd ios && swift build
```

`python3 scripts/validation_summary.py` is a read-only preflight helper. It does not replace the canonical checks; it keeps the validation path easy to copy into PRs and comments.

Documentation-only work requires repository-structure validation when required files or links change. Swift validation is required when Swift source changes.

## Evidence boundary

The repository proves deterministic software contracts and simulator-tested behavior. It does not yet prove actual model compatibility, memory use, latency, battery, thermal behavior, signing, App Intents execution or physical-device readiness. Those observations remain owner/device evidence.

## Durable next-direction rules

- Existing open PRs take priority over new implementation work.
- When no open PR exists, select one smallest safe source-backed issue.
- Prefer safety, validation, documentation accuracy and metadata-only boundaries.
- Do not create parallel implementation targets.
- Signing, entitlements, real actions and physical-device execution stay outside autonomous claims.

## Current next task

There is currently no active implementation target; the repo is in manual mode. Read `docs/CHATGPT_NEXT_TASK.md` and Brain issue #25 as the current control record before taking any action.