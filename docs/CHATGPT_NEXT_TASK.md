# ChatGPT Next Task

Repository: `pokekarten/igentic-iphone`

Stand: 2026-06-20

## Source-of-truth contract

This file is the current work source for AI-assisted repository work in `pokekarten/igentic-iphone`.

The private Brain may point here, but detailed live truth must be re-read from this repository. Before reporting or acting, verify current PR state, current `main`, workflow evidence, review threads and issue acceptance criteria.

## Current operating mode

Mode: `IGENTIC_DEFINE_LOCAL_MODEL_RUNTIME_CONTRACT`.

- iGentic is handled by the first half of the continuous ten-slot hourly cycle.
- Pokekartenkiste remains outside this task.
- Public GitHub Actions remain the independent validation environment.
- Exactly one active implementation candidate is allowed.
- Issue #58 is the selected product slice; do not select a parallel implementation target.

## Recently completed

- PR #56 `Clarify current AuditLog privacy behavior` was squash-merged into `main` as `421524c0709de166e0ab1e75ceb8585e3c98e1ef`.
- PR #60 `Issue #59: redact raw task text from AuditLog` passed all current-head workflows and was squash-merged as `ba562376fdb019ab20af19d2d8f68a1e6d626c90`.
- Issue #59 closed automatically as completed.
- Issue #29 remains an owner/device boundary.

## Active target

Issue #58 `MODEL-01: Define local model runtime and derivative model workspace` is the only active iGentic implementation target.

First slice scope:

- `ios/Sources/AgentCore/LocalModelRuntime.swift`
- `ios/Tests/AgentCoreTests/LocalModelRuntimeTests.swift`

Required behavior:

- typed runtime identifier and model family,
- typed local/system/delegated execution kind,
- typed supported capabilities,
- maximum supported data-sensitivity ceiling,
- typed context and memory budget classes,
- typed availability reason,
- deterministic request rejection before any model invocation,
- one fake runtime defined only in tests.

The contract is metadata-only. It must not load, call, download or benchmark any real model.

## Required implementation gate

The first Draft PR must:

1. branch from current `main`,
2. change only the two scoped Swift files unless a source-backed validator fix is required,
3. reject an unavailable runtime deterministically,
4. reject an unsupported capability deterministically,
5. reject requests above the data-class ceiling deterministically,
6. preserve all existing policy, approval, delegation and audit boundaries,
7. include no networking, persistence, model framework, weights, tool execution or device claims.

Required validation:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

Before merge:

- head SHA remains stable,
- changed files remain in scope,
- all current-head workflows pass,
- no unresolved review thread or new blocker remains,
- mark Ready only after the Draft gate passes,
- re-check the same head after Ready.

## Evidence boundary

This slice proves only a software contract for future local/system/delegated model runtimes. It does not prove that Qwen, Apple Foundation Models or another model runs acceptably on iPhone Air. Memory, latency, battery and thermal evidence remain owned by Issue #29.

## Safety rules

Do not add:

- CoreML, MLX, Foundation Models or other real model invocation,
- model weights, automatic downloads or network calls,
- persistence, external providers or real tool execution,
- hardware probing, benchmarks or physical-device success claims,
- secrets, signing material or real private data,
- changes to Pokekartenkiste.

## Expected terminal result

One of:

- `PR_OPENED`
- `MERGED`
- `REVIEW_BLOCKER_FOUND`
- `WAITING_CURRENT_HEAD_CHECKS`
- `FIX_APPLIED`
- `OWNER_DEVICE_STEP`
- `WRITE_SKIPPED`
