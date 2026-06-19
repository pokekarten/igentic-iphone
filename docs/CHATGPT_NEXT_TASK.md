# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-19

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, current `main`, workflow evidence, review threads and issue acceptance criteria.

## Current operating mode

Mode: `IGENTIC_SELECT_NEXT_SAFE_SLICE`.

- iGentic is handled by the first half of the continuous ten-slot hourly cycle.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions remain the independent validation environment.
- Exactly one active implementation candidate is allowed.
- Unrelated maintenance PRs must not displace an explicitly selected product target.

## Recently completed

- PR #51 `Add ToolRegistry contract validation` was squash-merged into `main` as `8730b302ef2a30175d4bd6d330ef15d741e29964`.
- PR #52 `Add metadata-only RuntimeBudget model` was merged into `main` as `6ff0c6875cb58560b0a98c4d23dbee91e538319b`.
- PR #52 passed the declared current-head workflow set, including Swift, Phase 0 CI, PR scope, PR quality, docs consistency, repo audit and iOS app-wrapper validation.
- Issue #14 is closed with source-backed acceptance evidence.
- Issue #29 remains open for physical-device validation.

## Active target

No new implementation candidate is selected yet.

The next iGentic director/context cycle must:

1. keep Issue #29 classified as an owner/device boundary,
2. inspect current open product issues and repository state,
3. select exactly one smallest safe deterministic or simulator-verifiable product slice,
4. avoid selecting Dependabot PR #49 as the product target unless maintenance is explicitly chosen.

## Selection criteria

Prefer a target that:

- is metadata-only, deterministic or simulator-verifiable,
- has narrow Swift/test scope,
- strengthens privacy, policy, approval, diagnostics or local-runtime planning,
- requires no real private data or external provider,
- can be validated by the repository structure validator plus Swift build/tests,
- does not require signing or a physical iPhone.

## Required validation for a new Swift slice

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

Before any new candidate can merge:

- base must remain `main`,
- head SHA must remain stable during the final gate,
- changed files must match the declared scope,
- required current-head workflows must pass,
- no unresolved review thread or source-backed blocker may remain.

## Safety rules

Do not add:

- hardware probing or real performance measurements,
- CoreML, MLX, model weights or model loading,
- routing behavior or automatic external delegation without a separately scoped safety design,
- file access, databases or persistence,
- networking, external providers or model calls,
- secrets or real private data,
- App Intents, signing or physical-device success claims.

## Evidence boundary

The merged RuntimeBudget slice proves only that runtime capability assumptions can be represented as typed, deterministic metadata.

It does not prove actual iPhone capacity, memory use, latency, model compatibility, signing, physical-device behavior, accessibility or production readiness. Issue #29 remains open.

## Expected terminal result

One of:

- `NEXT_UNBLOCKED_TASK_SELECTED`
- `PR_OPENED`
- `OWNER_DEVICE_STEP`
- `WRITE_SKIPPED`
