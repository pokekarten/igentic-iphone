# iGentic Roadmap

Last updated: 2026-08-03

## Roadmap principle

Build trust infrastructure before autonomy.

The roadmap favors safe, reviewable slices over broad app claims. Every phase should improve privacy, policy, auditability or contributor clarity.

## Current status

- Repository is public.
- Project is experimental / research prototype.
- GitHub is the source of truth.
- ChatGPT can make small direct repo edits through the GitHub Connector.
- Codex is paused unless a narrow Draft PR task is explicitly prepared.
- Initial Swift package and safety components exist.
- Community, brand, social, governance and contributor-onboarding foundation exist in the repo.
- The model candidate manifest and immutable German/English action-routing benchmark are on `main`.
- Backend-neutral evaluator, dataset/training governance and runtime/device evidence contracts are on `main`.
- No model training, runtime integration or physical iPhone Air result is implied by those contracts.

## Phase 0 — Research and project foundation

**Goal:** Make the project understandable, safe and contribution-ready.

### Done / in progress

- README with thesis, architecture, brand, community links and new-contributor quick start.
- Source verification rules.
- Apple API review.
- Local runtime review.
- Model strategy.
- Canonical knowledge map and model-research index.
- Model candidate and license manifest.
- Immutable action-routing benchmark and backend-neutral evaluator contract.
- Dataset and training-run governance.
- Runtime compatibility and physical-device evidence protocols.
- Community health docs.
- Apache 2.0 license.
- Brand foundation.
- Design system.
- Logo brief and usage rules.
- Initial SVG brand assets and asset README.
- Community strategy.
- Communication channel policy.
- Social media playbook.
- Contributor starter guide.
- Good-first-issue backlog.
- Lightweight governance.
- Issue templates for feature, model, security, design, device test, good-first-issue and social content proposals.
- Issue template chooser links for the starter guide, good-first-issue ideas, logo rules and security policy.
- Pull request template with privacy, approval and delegation checklist.
- Repo structure validation requiring community/brand docs and accessible SVG metadata.

### Next

- Keep high-level documents synchronized with canonical contracts.
- Convert selected good-first-issue backlog items into small GitHub issues.
- Review initial SVG assets and decide whether to set a GitHub social preview.
- Create first Instagram carousel template based on `docs/community/SOCIAL_MEDIA_PLAYBOOK.md`.
- Keep `PROJECT_STATE.md` current without copying live PR/check state into durable summaries.
- Decide whether to enable GitHub Discussions after repeated outside community questions.

## Phase 1 — Local Agent Kernel

**Goal:** Implement a minimal, testable local control layer.

Core components:

- `DataClassification`
- `PolicyEngine`
- `ApprovalManager`
- `TaskRouter`
- `AuditLog`
- `ToolRegistry`
- `MemoryStore` safe stub
- `DelegationBroker` policy-gated stub

Exit criteria:

- Tests cover approval-gated routing.
- Tests cover blocked Level 4 delegation.
- Audit log behavior is deterministic and thread-safe.
- Tool execution remains stubbed unless policy and approval paths are clear.

## Phase 2 — Diagnostic iPhone Shell

**Goal:** Build a minimal SwiftUI shell for real-device research.

Features:

- local-only diagnostic report,
- visible operating mode,
- policy decision preview,
- approval simulation,
- audit log viewer,
- no real private-data integrations yet.

Exit criteria:

- Runs on real iPhone test device.
- Makes no unsupported performance claims.
- Produces a reproducible device test report.

## Phase 3 — Local Model Runtime Evaluation

**Goal:** Compare proposal-generation backends without moving policy or execution authority into a model.

Canonical entry points:

- strategy overview: `MODEL_STRATEGY.md`
- research index: `docs/model-research/README.md`
- candidate manifest: `docs/model-research/IPHONE_AIR_MODEL_CANDIDATES.md`
- immutable benchmark: `docs/model-research/IGENTIC_ACTION_BENCHMARK_V0.md`
- evaluator contract: `docs/model-research/EVALUATOR_CONTRACT_V0.md`
- dataset/training governance: `docs/model-research/DATASET_GOVERNANCE.md` and `docs/model-research/TRAINING_RUN_CONTRACT.md`
- runtime/device evidence: `docs/model-research/RUNTIME_EVIDENCE_MATRIX.md` and `docs/model-research/IPHONE_AIR_DEVICE_EVIDENCE_PROTOCOL.md`

Research order:

1. evaluate Apple Foundation Models as an independent system backend;
2. record an untouched FunctionGemma 270M baseline as the first specialization candidate;
3. record an untouched Qwen3 0.6B non-thinking baseline as the first Apache-2.0 multilingual comparison;
4. compare the same immutable benchmark and normalized proposal schema;
5. select at most one specialization candidate only when comparable evidence justifies it;
6. document export and runtime compatibility for exact pinned artifacts;
7. collect physical iPhone Air evidence only under the canonical device protocol.

Larger, tool-specific or multimodal candidates advance only after smaller candidates fail a defined quality gate and license/runtime requirements are satisfied.

Exit criteria:

- Untouched backend comparisons use the same benchmark, evaluator and prompt/output profiles.
- Models remain proposal generators; deterministic Swift owns policy, approval, validation, audit and execution.
- No private data is used in public experiments.
- No model weights, adapters or checkpoints are committed.
- Cancellation, timeout, failure recovery and rollback evidence exist for any advancing runtime artifact.
- Compile, host and simulator evidence are not represented as physical-device evidence.
- Device constraints are documented from exact physical-device tests rather than inferred from model size or vendor claims.

## Phase 4 — App Intents and safe actions

**Goal:** Explore action integration with strict approval and audit rules.

First action pattern:

1. understand request,
2. classify data,
3. prepare draft action,
4. ask for approval,
5. execute only if approved,
6. write audit log.

Allowed early actions:

- synthetic examples,
- draft-only actions,
- local test actions,
- non-destructive demo flows.

Blocked early actions:

- sending real messages,
- deleting real data,
- moving money,
- sharing credentials,
- health/finance/legal automation,
- external AI delegation of Level 4 data.

## Phase 5 — Controlled Delegation

**Goal:** Delegate larger tasks to trusted devices or external AI only after policy checks.

Delegation targets:

- Mac worker,
- home server worker,
- private cloud path if policy allows,
- external AI only by explicit per-task opt-in.

Required safeguards:

- minimization,
- redaction,
- data class checks,
- user approval,
- audit log,
- result verification.

## Phase 6 — Public demo and community release

**Goal:** Publish a clear research demo that invites careful contributions.

Deliverables:

- tagged GitHub release,
- release notes,
- architecture diagram,
- device test report,
- social launch post,
- good first issues,
- contribution guide refresh.

## Community roadmap

### Now

- Keep decisions in GitHub.
- Use Instagram/X/LinkedIn only to point people back to GitHub.
- Invite narrow, careful contributors.
- Use design, device-test, good-first-issue and social-content issue templates for early community participation.

### Later

- Enable GitHub Discussions when Issues become too crowded.
- Consider Discord only after repeated real contributor activity.
- Add monthly community digest if progress becomes consistent.

## Brand roadmap

### Now

- Use `iGentic` as master brand.
- Use `iGentic iPhone` as current research track.
- Avoid Apple trade dress.
- Build own visual system around control ring, local identity and policy line.
- Keep SVG assets in `assets/brand/` and brand rules in `docs/brand/`.
- Require accessibility metadata for committed SVG brand assets.

### Later

- Refine official SVG logo pack after design feedback.
- Set GitHub social preview after asset review.
- Create Instagram carousel templates.
- Create website landing page.

## Maintainer rule

When in doubt, choose the path that is:

1. more private,
2. more auditable,
3. easier to review,
4. easier for contributors to understand,
5. less likely to imply unsafe autonomy.
