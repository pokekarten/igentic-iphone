# Project State

Last updated: 2026-08-29

## Current status

`iGentic iPhone` is an open-source, privacy-first iPhone AI Runtime Layer research repository.

- Repository: `pokekarten/igentic-iphone`
- Visibility: public
- Validation: GitHub Actions on macOS and Linux
- Primary target device: iPhone Air as trust/control plane
- Current phase: safety-first agent kernel, diagnostic shell, Safe Action pre-save boundaries, and evidence-gated local/system-model research

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

The private Brain lane and historical five-slot autonomy controller are suspended. The repository is in manual GitHub-first mode. Historical target envelopes in Brain issues, task documents or memory must not be treated as active work when they disagree with live GitHub.

## Current verified architecture baseline

- Deterministic Swift policy, approval, schema validation, routing and audit remain authoritative.
- `ApprovalReceipt` keeps approval state bound to the approved action path; model output does not replace approval authority.
- `DiagnosticSnapshot`/`DiagnosticSnapshotProducer` expose diagnostic state without becoming authorization authority.
- Models may propose; they do not authorize or execute.
- `ToolRegistry` is observational/non-authoritative at the current integration boundary.
- `MemoryStore` is optionally attached to `AgentKernel` for aggregate session/task count observability only. Memory keys and values are not injected into task, policy, approval, routing, delegation, model-selection or tool-authorization inputs.
- Restricted-sensitive memory writes remain rejected before store mutation.
- AppAction approval configuration cannot turn a blocked action into an allowed action.
- Runtime/model research remains evidence-gated and separate from physical-device readiness claims.

## Safe Action V0 pre-save foundation

The bounded `createReminder` path now has a reviewed pre-save authority chain on `main`:

- canonical reminder title and DST-safe due-date identity;
- separate `ActionDataDestination` and opaque target binding in the canonical draft/fingerprint;
- fail-closed destination policy for Local Only, restricted-sensitive data and unknown destinations;
- fingerprint-bound human approval/capability authority with synthetic approval rejected for production capability issuance;
- one-shot process-local capability consumption;
- a real user-driven SwiftUI approval surface that remains side-effect-free;
- a read-only EventKit target resolver that classifies the configured default reminder target from coarse source metadata;
- pre-save TOCTOU recheck of destination class and opaque target identity;
- an application-level non-read boundary that does not fetch or enumerate existing reminders merely because Reminders Full Access permits reads.

This foundation does **not** authorize a real reminder save. EventKit permission setup and any first `EKReminder` creation/save remain separate side-effect boundaries. Repository admission prerequisites — required default-branch enforcement followed by the planned public-content admission gate — must be satisfied before a real side-effect path is enabled.

## Current execution and security frontier

Live GitHub must be re-read before acting. The remaining work classes include:

- repository admission/security enforcement, including required commit-metadata privacy protection and the follow-on public-content admission gate;
- continued healthy CodeQL Default Setup evidence; Advanced Setup remains optional hardening unless a concrete customization need emerges;
- untouched host baseline execution for Qwen3 0.6B;
- untouched host baseline execution for Apple Foundation Models on an eligible Apple-Silicon Mac;
- FunctionGemma transport/decoding provenance before any adapter or training work;
- physical-Mac autonomous-worker activation/evidence before relying on unattended host execution;
- later physical iPhone evidence before any on-device performance/readiness claim;
- only after required repository admission gates, a separately reviewed first real Safe Action side-effect slice.

Planning or execution issues are not proof that these results already exist.

## Active-work lookup

When determining what to work on next, check sources in this order:

1. Current GitHub repository state.
2. Open pull requests and exact-head checks.
3. Current open issue acceptance criteria and ordering constraints.
4. `docs/CHATGPT_NEXT_TASK.md` and `docs/CODEX_NEXT_TASK.md` for durable execution rules.
5. Historical Brain/task context only when it still matches live GitHub.

If the sources diverge, current GitHub source wins.

## Validation contract

- GitHub Actions on macOS and Linux are the primary validation signals.
- `python3 scripts/validate_repo_structure.py` is the baseline repository validation.
- Swift changes require `cd ios && swift test` unless the scoped issue documents why Swift tests are not applicable.
- Validation evidence must match the exact pull-request head being reviewed.
- iOS simulator compilation/smoke evidence proves the scoped app path can build/run in that simulator environment; it does not establish physical iPhone readiness.
- A successful host-model run remains host evidence only.

## Evidence boundary

- Use GitHub and repository files as the source of truth.
- Keep credentials, private prompts, private datasets, real user messages, contacts, files and identifiers out of the public repository.
- Do not treat planning issues as proof of implementation.
- Do not treat desktop conversion, simulator execution, GitHub-hosted compilation or host-model execution as physical iPhone Air evidence.
- Do not promote memory content into authorization or execution authority without a separately reviewed contract.
- Do not log or publish raw EventKit calendar/source/account identifiers as generic diagnostics or audit data.

## Durable next-direction rules

- Exactly one active iGentic implementation target and at most one active implementation PR are allowed.
- Existing open PRs take priority over selecting new implementation work.
- When no implementation PR exists, select one smallest safe source-backed issue after fresh GitHub reconciliation.
- Respect explicit issue ordering. Do not work around a GitHub setting, physical-host, license or upstream-access blocker by creating unrelated product code.
- Research execution tasks may require external host evidence but must not silently mutate benchmark/model contracts after results are observed.
- `agentic-dev-playbook`, `agentic-slm-lab` and `agentic-private-brain` are support repositories, never implicit product targets.
- Preserve the separation between product implementation, security admission, research evidence and cross-repository reuse.
- Prefer bounded changes with explicit acceptance criteria, validation and stop rules.

## Recently completed foundation

- The safety-first kernel includes policy, approval, sensitive-data classification, runtime-budget/model-selection diagnostics, ToolRegistry observability and bounded MemoryStore count-only observability.
- Benchmark/evaluator, baseline-manifest, Qwen host-runner and Apple Foundation Models host-runner/packager contracts exist on `main`.
- GitHub CodeQL Default Setup currently has successful real PR evidence for actions, Python and Swift. The staged Advanced workflow preserves an explicit manual Swift build as a hardening/fallback option, not a current product prerequisite.
- The Explore diagnostic shell supports bundled local Markdown discovery and deterministic local navigation/search behavior.
- Safe Action V0 now has the side-effect-free human approval surface and the read-only EventKit destination/TOCTOU boundary described above.

## Current next-direction boundary

Do not revive old early-kernel or old slot-controller tasks merely because they remain in historical notes.

The next action must be chosen from live GitHub after checking for open PRs, issue ordering constraints and exact required evidence. Until the repository admission gates are satisfied, do not add a real Reminder save merely because the pre-save Safe Action chain is now present.

Near-term value should come from closing repository admission gaps, producing untouched model evidence, activating/proving the bounded Mac worker, and preparing physical-device evidence. Do not expand memory content, external delegation or broad tool execution ahead of those gates.
