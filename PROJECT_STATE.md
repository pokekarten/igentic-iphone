# Project State

Last updated: 2026-08-29

## Current status

`iGentic iPhone` is an open-source, privacy-first iPhone AI Runtime Layer research repository.

- Repository: `pokekarten/igentic-iphone`
- Visibility: public
- Validation: GitHub Actions on macOS and Linux
- Primary target device: iPhone Air as trust/control plane
- Current phase: safety-first agent kernel, diagnostic shell, and evidence-gated local/system-model research

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

The private Brain lane is suspended and the repository is currently in manual mode. Historical target envelopes in Brain issues, this file, task documents or memory must not be treated as active work when they disagree with live GitHub.

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

## Current execution and security frontier

Live GitHub must be re-read before acting, but the post-#330 frontier includes these distinct work classes:

- repository admission/security enforcement, including commit-metadata privacy and public-content leak protection;
- untouched host baseline execution for Qwen3 0.6B;
- untouched host baseline execution for Apple Foundation Models on an eligible Apple-Silicon Mac;
- FunctionGemma transport/decoding provenance before any adapter or training work;
- later physical iPhone evidence before any on-device performance/readiness claim.

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
- A successful compile or host run does not establish physical iPhone readiness.

## Evidence boundary

- Use GitHub and repository files as the source of truth.
- Keep credentials, private prompts, private datasets, real user messages, contacts, files and identifiers out of the public repository.
- Do not treat planning issues as proof of implementation.
- Do not treat desktop conversion, simulator execution, GitHub-hosted compilation or host-model execution as physical iPhone Air evidence.
- Do not promote memory content into authorization or execution authority without a separately reviewed contract.

## Durable next-direction rules

- Exactly one active iGentic implementation target and at most one active implementation PR are allowed.
- Existing open PRs take priority over selecting new implementation work.
- When no implementation PR exists, select one smallest safe source-backed issue after fresh GitHub reconciliation.
- Research execution tasks may require external host evidence but must not silently mutate benchmark/model contracts after results are observed.
- `agentic-dev-playbook` and `agentic-slm-lab` are support repositories, never implicit product targets.
- Preserve the separation between product implementation, security admission, research evidence and cross-repository reuse.
- Prefer bounded changes with explicit acceptance criteria, validation and stop rules.

## Recently completed foundation

- The safety-first kernel includes policy, approval, sensitive-data classification, runtime-budget/model-selection diagnostics, ToolRegistry observability and bounded MemoryStore count-only observability.
- Benchmark/evaluator, baseline-manifest, Qwen host-runner and Apple Foundation Models host-runner/packager contracts exist on `main`.
- The Advanced CodeQL workflow contains an explicit manual Swift build path instead of relying on Swift autobuild; platform migration/enforcement must still be verified separately before claiming CodeQL admission is complete.
- The Explore diagnostic shell supports bundled local Markdown discovery and deterministic local navigation/search behavior.

## Current next-direction boundary

Do not revive old early-kernel tasks merely because they remain in historical notes. The next action must be chosen from live GitHub after checking for open PRs, issue ordering constraints and exact required evidence.

Near-term value should come from closing repository admission gaps, producing untouched model evidence and then proving one narrow end-to-end safe action path. Do not expand memory content, external delegation or broad tool execution ahead of those gates.
