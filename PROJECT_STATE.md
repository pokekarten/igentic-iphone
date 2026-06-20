# Project State

Last updated: 2026-06-20

## Current status

`iGentic iPhone` is an open-source, privacy-first iPhone AI Runtime Layer research repository.

- Repository: `pokekarten/igentic-iphone`
- Visibility: public
- Validation: GitHub Actions on macOS and Linux
- Primary target device: iPhone Air as trust/control plane
- Master brand: `iGentic`
- Community model: GitHub-first, social-supported
- Current phase: diagnostic shell and safe local-model boundary design

## Canonical sources

- `docs/brand/BRAND.md`
- `docs/brand/BRAND_ASSET_MANIFEST.md`
- `assets/social/instagram-profile-v3.svg`
- `docs/community/COMMUNITY_STRATEGY.md`

## Recently completed

- PR #52 added metadata-only RuntimeBudget planning.
- PR #56 corrected AuditLog privacy documentation.
- PR #60 removed raw task text from task-received audit events and merged as `ba562376fdb019ab20af19d2d8f68a1e6d626c90`.
- Issue #59 is closed as completed.
- Issue #29 remains open for physical-device evidence.

## Current baseline

`main` includes:

- AgentCore policy, approval, audit, routing, risk, memory and delegation components,
- lock-protected AuditLog storage and metadata projections,
- task-received audit events that do not retain raw task text,
- validated ToolRegistry definitions,
- metadata-only RuntimeBudget, ApprovalReceipt and DiagnosticSnapshot models,
- synthetic scenario and diagnostic UI support,
- an installable unsigned simulator wrapper and automated validation workflows.

## Current safety posture

- Policy and approval remain authoritative before action.
- AuditLog task-received events use a fixed metadata-safe message.
- Diagnostic projections remain metadata-only.
- Restricted sensitive data remains blocked before automatic external delegation.
- No real model loading, networking, persistence or tool execution exists.
- RuntimeBudget is planning metadata, not hardware measurement.

## Current active target

Issue #58 `MODEL-01: Define local model runtime and derivative model workspace` is the only active implementation target.

First slice:

- add `ios/Sources/AgentCore/LocalModelRuntime.swift`,
- add `ios/Tests/AgentCoreTests/LocalModelRuntimeTests.swift`,
- define typed runtime metadata, execution kind, capabilities, data ceiling, context and memory classes, availability and rejection reasons,
- reject unavailable runtimes, unsupported capabilities and excessive data sensitivity before any model invocation,
- keep the deterministic fake runtime in tests only.

This slice adds no model framework, model artifact, network access, persistence, provider call, hardware probe or performance claim.

## Validation contract

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

Merge requires a stable head, scoped changed files, successful current-head workflows and no unresolved review blocker. A Ready transition must be followed by another check of the same head.

## Evidence boundary

The repository can prove deterministic software contracts and simulator-tested behavior. It does not yet prove actual model compatibility, memory use, latency, battery, thermal behavior, signing or physical-device readiness. Those observations remain owned by Issue #29.

## Next sequence

1. Implement the two-file LocalModelRuntime contract.
2. Open one Draft PR from current `main`.
3. Run repository and Swift validation.
4. Apply only source-backed fixes.
5. Mark Ready and merge only with clean evidence.

## Current next task

See `docs/CHATGPT_NEXT_TASK.md`.
