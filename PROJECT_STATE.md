# Project State

Last updated: 2026-08-04

## Current status

`iGentic iPhone` is an open-source, privacy-first iPhone AI Runtime Layer research repository.

- Repository: `pokekarten/igentic-iphone`
- Visibility: public
- Validation: GitHub Actions on macOS and Linux
- Primary target device: iPhone Air as trust/control plane
- Current phase: diagnostic shell, local policy configuration, and evidence-gated local-model research

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

The only mutable source for an explicitly authorized iGentic target and lane stage is:

```text
pokekarten/agentic-private-brain issue #25
```

That lane is suspended and the repository is currently in manual mode. Historical target envelopes in the Brain issue must not be treated as active work.

## Current verified baseline

- There is no active iGentic implementation pull request.
- Issue #185 is closed as completed. PR #215 merged the local AppAction approval-policy settings, persistence, effective-policy diagnostics and related regression coverage.
- The model-research product packages for canonical navigation, benchmark/evaluator contracts, dataset governance, runtime/device evidence and high-level document synchronization are complete on `main`.
- PR #236 added the runtime and physical-device evidence contracts.
- PR #237 synchronized the high-level model-research overviews with the canonical contracts.
- Knowledge-export parent Issue #79 remains open only for terminal cross-repository evidence in `agentic-dev-playbook` and the private Brain lane.
- CoreML feasibility Issue #111 remains blocked pending an owner-supplied local model artifact. No runtime integration is authorized by that issue.
- Research parent Issue #74 remains an open planning and evidence roadmap, not an active implementation target.

## Current safety posture

- Deterministic Swift policy, approval, schema validation, routing and audit remain authoritative.
- Models may propose; they do not authorize or execute.
- AppAction approval configuration cannot turn a blocked action into an allowed action.
- No physical-device performance or readiness claim is valid without exact artifact, runtime, configuration and physical-device evidence.
- Do not revive completed targets from this file, Brain history or memory.

## Active-work lookup

When determining what to work on next, check sources in this order:

1. Current GitHub repository state.
2. `docs/CHATGPT_NEXT_TASK.md`.
3. `pokekarten/agentic-private-brain` issue #25.
4. The durable notes in this file.

If the sources diverge, current GitHub source wins.

## Validation contract

- GitHub Actions on macOS and Linux are the primary validation signals.
- `python3 scripts/validate_repo_structure.py` is the baseline repository validation.
- Swift changes require `cd ios && swift test` unless the scoped issue documents why Swift tests are not applicable.
- Validation evidence must match the exact pull-request head being reviewed.

## Evidence boundary

- Use GitHub and repository files as the source of truth.
- Keep mutable PR, branch, check and lane state out of this durable file.
- Do not treat planning issues as proof of implementation.
- Do not treat desktop conversion, simulator execution or runtime documentation as physical iPhone Air evidence.
- Public repository content must not contain credentials, private prompts, private datasets, real user messages, contacts, files or identifiers.

## Durable next-direction rules

- Exactly one active iGentic implementation target and at most one active implementation PR are allowed.
- Existing open PRs take priority over selecting new work.
- When no PR exists, select one smallest safe source-backed product issue before creating a branch.
- `agentic-dev-playbook` and `agentic-slm-lab` are support repositories, never implicit product targets.
- Preserve the separation between product implementation, research evidence and cross-repository reuse.
- Prefer bounded changes with explicit acceptance criteria, validation and stop rules.

## Recently completed

- PR #215 completed the local AppAction approval-policy settings and persistence slice; Issue #185 is closed as completed.
- PR #236 defined runtime compatibility evidence classes, the physical iPhone Air measurement protocol and a public-safe result template.
- PR #237 synchronized the model-research overview documents with the canonical candidate, benchmark, evaluator, governance, runtime and device-evidence contracts.
- The Explore diagnostic shell now supports bundled local Markdown discovery, local detail navigation, deterministic search excerpts, accessible match highlighting and result counts.
- MemoryStore restricted-data write protection, live `DiagnosticSnapshot` production, diagnostic-only model selection, local-model assessment wiring and `ApprovalReceipt` wiring remain on `main`.

## Current next task

There is no active implementation target or product PR. The repository remains in manual mode until one smallest safe source-backed product issue is selected explicitly.

Issue #111 is not actionable without the owner-supplied model artifact. Issue #79 has only cross-repository completion work remaining and must not be used to introduce unrelated product changes. Any next product implementation must therefore begin with fresh GitHub reconciliation and a bounded issue rather than reviving the completed #185 lane or a historical Brain target.
