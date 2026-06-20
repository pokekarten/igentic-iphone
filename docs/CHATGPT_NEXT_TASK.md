# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-20

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, current `main`, workflow evidence, review threads and issue acceptance criteria.

## Current operating mode

Mode: `IGENTIC_CLOSE_GLOSSARY_PRIVACY_CORRECTION`.

- iGentic is handled by the first half of the continuous ten-slot hourly cycle.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions remain the independent validation environment.
- Exactly one active candidate is allowed.
- Do not select a new implementation slice while the active documentation correction remains open.

## Recently completed

- PR #51 `Add ToolRegistry contract validation` was squash-merged into `main` as `8730b302ef2a30175d4bd6d330ef15d741e29964`.
- PR #52 `Add metadata-only RuntimeBudget model` was merged into `main` as `6ff0c6875cb58560b0a98c4d23dbee91e538319b`.
- PR #55 `Issue #2: add contributor glossary` was squash-merged into `main` as `cbb1ecf8e10b0c8bb7ecd509aba2c35f1670e16f`.
- PR #55 received a post-merge review finding that its AuditLog definition overstated the current privacy behavior.
- Issue #29 remains open for physical-device validation.

## Active target

PR #56 `Clarify current AuditLog privacy behavior` is the only active iGentic target.

Scope:

- `docs/GLOSSARY.md` only.
- Clarify that the full current AuditLog is not metadata-only because task-received events record `task.userText` in `AuditEvent.message`.
- Point metadata-only diagnostics to `AuditEventMetadata` projections.
- No Swift or runtime behavior changes in this correction.

Current head at last verification: `1aabf68a77c9c03ccec46b9fc29360e5b894ab7f`.

## Required close gate for PR #56

Before merge:

1. base remains `main`,
2. head SHA remains stable,
3. changed files remain exactly `docs/GLOSSARY.md`,
4. current-head workflow set completes successfully,
5. no unresolved review thread or new source-backed blocker remains,
6. mark Ready only after the draft gate is satisfied,
7. re-check for newly triggered automated review before merging.

Do not treat an earlier failed superseded workflow run as current if a later run for the same stable head succeeds.

## Next sequence after PR #56

Only after PR #56 is merged or explicitly closed:

1. keep Issue #29 classified as an owner/device boundary,
2. inspect current open product issues and repository state,
3. select exactly one smallest safe deterministic or simulator-verifiable product slice,
4. avoid selecting Dependabot maintenance as the product target unless maintenance is explicitly chosen.

## Selection criteria for the later product slice

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

## Safety rules

Do not add:

- hardware probing or real performance measurements,
- CoreML, MLX, model weights or model loading,
- routing behavior or automatic external delegation without a separately scoped safety design,
- file access, databases or persistence,
- networking, external providers or model calls,
- secrets or real private data,
- App Intents, signing or physical-device success claims.

## Expected terminal result

One of:

- `MERGED`
- `REVIEW_BLOCKER_FOUND`
- `WAITING_CURRENT_HEAD_CHECKS`
- `NEXT_UNBLOCKED_TASK_SELECTED`
- `OWNER_DEVICE_STEP`
- `WRITE_SKIPPED`
