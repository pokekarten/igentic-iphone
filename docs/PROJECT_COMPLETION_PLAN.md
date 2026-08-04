# iGentic Project Completion Plan

Status: canonical completion plan
Date: 2026-07-29
Scope: `pokekarten/igentic-iphone`

## 1. Purpose

This document turns the existing roadmap, safety contracts, implementation state, research tracks and open issue backlog into one executable path from the current early-stage diagnostic shell to a finished, publishable research prototype.

The plan is intentionally designed so that AI agents can execute the engineering cycle through GitHub, CI and repository tooling wherever repository evidence is sufficient. Human/Ben involvement is reserved for late-boundary owner actions the repository cannot manufacture on its own: physical iPhone access, Apple signing/provisioning, legal/licence acceptance, or an explicitly owner-bound product decision.

This is a completion plan, not permission to bypass existing issue scope. Every implementation slice still requires a source-backed GitHub issue, an allowlist, tests, review and current-head CI evidence.

## 2. Source of truth and current baseline

The execution order remains:

1. current GitHub repository/issue/PR/check state;
2. durable contracts in this repository;
3. private operating routing when an authorized automation lane uses it;
4. prior memory;
5. assumptions.

Never revive a closed issue or infer completion from stale documentation.

The 2026-07-29 audit established:

- `main` is public and the repository is still an experimental/research prototype.
- The architecture already contains `AgentKernel`, `PolicyEngine`, `ApprovalManager`, `ApprovalReceipt`, `TaskRouter`, `AuditLog`, `SensitiveDataDetector`, `DelegationBroker`, `ToolRegistry`, `MemoryStore`, `RuntimeBudget`, `RuntimeBudgetAssessor`, `LocalModelRuntime`, `ModelSelectionEngine`, synthetic scenarios and a diagnostic SwiftUI shell.
- The uploaded repository snapshot passes `python3 scripts/validate_repo_structure.py` and `cd ios && swift test` with 138 tests and 0 failures on the available Linux host. This is host evidence, not physical-iPhone evidence.
- Current GitHub `main` has no open implementation PR. The autonomy protocol is therefore a control mechanism, not evidence that an autonomous cycle is currently active.
- The diagnostic path is intentionally synthetic/read-only; there is no real App Intents execution, provider execution or committed model weights.
- `ApprovalReceipt` is already a live `AgentKernel` response contract.
- Effective data classification is shared across kernel, diagnostic snapshot and app-action coordination.
- `AppActionCoordinator` already respects `decision.requiresApproval`; the remaining approval-policy work is configuration/setup/admin behavior, not a universal approval hard-code fix.
- `RuntimeBudgetAssessor` exists as a deterministic producer and is still not authoritative over routing.
- `MemoryStore` remains a deliberate pre-integration stub.
- `ToolRegistry` now has the bounded Phase 1 read-only `AgentKernel` integration: optional dependency plus count-only audit snapshot; no selection or execution path.
- Model selection is deterministic and diagnostic-only, with the smaller request shape documented in the current spec.

## 3. Definition of project completion

The project is considered complete when all of the following are true:

### Safety

- Deterministic policy remains authoritative over every model proposal.
- Approval is explicit, exact-draft-bound and invalidated by target/payload/risk changes.
- Restricted sensitive data cannot be automatically delegated externally.
- No model can authorize itself, execute a tool by implication, or bypass the kernel.
- Audit output is metadata-minimized and does not expose raw private task content.
- Failure, cancellation, stale approval and missing approval produce no external side effect.

### Product/runtime

- The kernel has clear, tested boundaries for tools, memory, runtime budgets and model selection.
- The first runtime adapter is behind a stable protocol and can be removed without changing policy code.
- At least one local model/runtime path is evaluated with immutable benchmark evidence.
- App-action flow is draft-first and safe; any real side-effecting capability remains separately scoped and explicitly approved.
- Controlled delegation, if included, is minimized, policy-gated, approval-gated where required, auditable and result-verified.

### Evidence

- Host/simulator, runtime and physical-device evidence are kept distinct.
- A physical-device report exists for every claim made about iPhone Air execution or performance.
- Model claims cite exact model revisions, runtime revisions, templates and licences.
- Benchmark data is immutable and isolated from training data.

### Release

- CI is green on the release commit.
- Security/privacy checks pass.
- Documentation matches implementation.
- No secrets, signing files, private identifiers, model weights or unreviewed experiment dumps are committed.
- A reproducible tagged release can be built and its limitations are clearly stated.

## 4. Critical path

The shortest safe path is:

```text
Baseline reconciliation
  -> architecture gates closed
  -> kernel boundary hardening
  -> diagnostic shell truthfulness/completeness
  -> runtime benchmark + adapter
  -> safe action demo
  -> controlled delegation (only if justified)
  -> physical-device evidence
  -> release hardening
  -> tagged research release
```

The following tracks may run in parallel when they do not create a second active implementation PR:

- model research/evaluation;
- Explore/discovery content;
- community/brand documentation;
- CoreML feasibility research;
- release-documentation preparation.

They must never outrank a blocking safety/architecture gate on the critical path.

## 5. Phase 0 — Reconcile the control plane

**Goal:** remove stale status and establish one machine-readable completion target.

### AI-owned work

1. Verify `main`, open issues, closed issues, recent merges and required workflows.
2. Reconcile `docs/reports/issue-status-matrix.md` with current GitHub state.
3. Reconcile stale issue text, especially #185, with current `AppActionCoordinator` behavior.
4. Keep `PROJECT_STATE.md` durable rather than turning it into mutable task routing.
5. Maintain this completion plan as the canonical end-to-end direction.
6. For each next slice, create or update one narrowly scoped issue with explicit allowed files, acceptance criteria, validation and stop rules.

### Exit gate

- Exactly one active implementation target exists.
- No stale closed target is selected.
- The next issue is source-backed and small enough for one PR.

### Human needed?

No.

## 6. Phase 1 — Close architecture decision gates

**Goal:** eliminate ambiguous pre-integration stubs before adding real runtime capability.

### 1A. MemoryStore decision and implementation

Issues: #120 / #142.

First produce the final classification/retention decision. It must answer:

- classification at write time;
- whether `MemoryEntry` stores sensitivity metadata;
- storage rejection threshold;
- session/task isolation;
- retention/deletion behavior;
- audit expectations;
- tests for every threshold and scope boundary.

Then implement the smallest safe memory slice. Do not add broad persistence. Keep values scoped, deletable and non-authoritative. Sensitive memory must never silently become a delegation permission.

**AI:** design, code, tests, review, CI, docs.

**Ben:** not required unless a product policy question remains unresolved after the design evidence is assembled.

### 1B. ToolRegistry integration boundary

Issues: #137 and #121 — **completed**.

The boundary is now implemented as a read-only diagnostic dependency:

- `AgentKernel` accepts optional `toolRegistry: ToolRegistry?`;
- `handle()` emits one count-only registry snapshot when present;
- routing and approval behavior remain unchanged;
- no tool selection, invocation, App Intents or dynamic authorization was added;
- `AgentKernelToolRegistryWiringTests` pins present/absent registry behavior and metadata minimization.

Any future tool-selection or execution capability requires a separate design issue.

**AI:** all repository work.

**Ben:** no.

### 1C. RuntimeBudget boundary

Issue #181 — **completed**.

`RuntimeBudgetAssessor` is deterministic and non-authoritative. Keep budget estimation non-blocking until a dedicated policy decision exists.

**AI:** all repository work.

**Ben:** no.

### 1D. Model-selection decision trace

Issue #144 — **specification completed**. Issues #145–#149 remain the implementation/diagnostic follow-up sequence.

The trace schema now defines:

- request summary;
- surviving candidates;
- hard-constraint rejection reasons;
- weighted score components;
- deterministic tie-break reason;
- safe-refusal/fallback reason.

Keep it diagnostic-only. It must never become policy authority.

**AI:** all repository work.

**Ben:** no.

### Phase 1 exit gate

- Memory classification/retention is decided and tested.
- ToolRegistry boundary is decided and metadata integration is tested.
- RuntimeBudget estimation is deterministic and tested.
- Model-selection trace schema is deterministic and diagnostic-only; implementation and rendering remain.
- All existing 138+ tests remain green after each slice.

## 7. Phase 2 — Make the kernel production-shaped without making it autonomous

**Goal:** turn the current safety components into one coherent, testable control plane while still keeping real side effects disabled.

### Required work

1. Define one canonical task lifecycle:

```text
input
-> sensitive-data detection
-> effective classification
-> policy decision
-> approval decision/receipt
-> runtime budget
-> model selection proposal
-> tool metadata resolution
-> route
-> audit
```

2. Ensure every stage is observable through metadata, not raw private content.
3. Ensure model selection and runtime budgeting are advisory only.
4. Ensure ToolRegistry metadata cannot create permission.
5. Ensure MemoryStore data cannot create permission.
6. Ensure approval receipts are exact-draft-bound where an action draft exists.
7. Add a comprehensive synthetic scenario matrix covering:
   - local-only allow;
   - local-only non-local block;
   - highly private approval;
   - restricted external block;
   - risky action approval;
   - stale approval;
   - changed payload;
   - changed target;
   - changed risk/classification;
   - runtime unavailable;
   - tool missing/invalid;
   - safe model fallback;
   - cancellation/no-side-effect outcome.

### Exit gate

A single synthetic scenario can demonstrate the complete control-plane chain and prove that no model/tool/runtime shortcut can bypass policy or approval.

**Owner:** AI agents.

**Ben:** not required.

## 8. Phase 3 — Finish the diagnostic shell

**Goal:** make the app a truthful inspection tool rather than a static showcase.

### Required work

- Keep the default snapshot generated from synthetic scenario execution.
- Remove wording that can be interpreted as live device evidence when it is synthetic.
- Finish model-selection decision-trace rendering.
- Add a compact policy/approval explanation that makes `blocked` versus `approval required` unambiguous.
- Surface runtime-budget metadata as planning information only.
- Surface ToolRegistry and MemoryStore state only as metadata and only after their contracts are closed.
- Keep user text out of diagnostics.
- Add accessibility identifiers/labels where practical.
- Ensure empty/error states are understandable.

### Setup/admin approval policy

Issue #185 is **completed**. The local configuration lane now provides:

- conservative setup defaults with durable first-run confirmation;
- explicit approval requirements by action kind/family;
- later review and editing in settings/admin;
- runtime consumption of the persisted policy rather than hidden policy;
- hard blocking regardless of configuration when deterministic policy denies an action;
- effective-policy diagnostics without private task content.

This lane remains local-only. Any real App Intents or AppAction execution capability requires a new source-backed issue and must not reopen or silently widen #185.

### Exit gate

The diagnostic shell tells the truth about every displayed state, is entirely synthetic/local, and is covered by deterministic tests.

**Owner:** AI agents.

**Ben:** optional product review only.

## 9. Phase 4 — Establish the model/runtime evidence chain

**Goal:** choose a runtime based on evidence, not enthusiasm.

Use the existing research order and preserve the distinction between candidate research, backend support, runtime execution and device evidence.

### Sequence

1. Freeze an exact candidate revision and licence record.
2. Run untouched baseline on the immutable synthetic German/English action-routing benchmark.
3. Compare at least the first-wave candidates according to the current research plan, beginning with the smallest specialized router where evidence supports it.
4. Measure:
   - valid action/schema rate;
   - policy-preserving behavior;
   - malformed argument rate;
   - German/English behavior;
   - latency;
   - memory footprint;
   - cancellation;
   - timeout behavior;
   - output-token limits;
   - refusal/fallback behavior.
5. Only then consider one specialization/fine-tuning run.
6. Keep model output as a proposal object; convert to a deterministic schema before any kernel consideration.
7. Add a `LocalModelRuntime` adapter for the selected backend only after baseline evidence exists.

### Runtime candidates

The research track currently considers Apple-native Foundation Models/Core AI surfaces, Core ML as a supporting path, MLX Swift, MLC-LLM and llama.cpp-derived paths. The exact first runtime is an evidence decision, not a predetermined architecture commitment.

### CoreML rule

Issue #111 is bounded to compile-only feasibility. It may produce a success/failure/blocked report for the named candidate artifact, but it does not authorize runtime integration.

### Exit gate

One runtime/backend/artifact combination has reproducible host evidence and a documented rollback path. No model weights are committed to this repository.

**AI:** research, benchmark, evaluation, adapter code and documentation.

**Ben:** only if a licence, account, proprietary SDK or other owner boundary cannot be resolved from public evidence.

## 10. Phase 5 — Safe action execution boundary

**Goal:** prove the transition from proposal to action without introducing unsafe autonomy.

Start with one non-destructive synthetic action.

### Required pipeline

```text
request
-> classify
-> policy
-> draft
-> exact preview
-> approval policy
-> fresh approval receipt if required
-> revalidate draft fingerprint
-> synthetic/local executor
-> metadata audit
```

### Mandatory tests

- missing approval blocks;
- rejected approval blocks;
- stale receipt blocks;
- changed payload blocks;
- changed target blocks;
- changed risk/classification blocks;
- cancellation produces no side effect;
- policy-disabled action remains blocked;
- configured no-approval action does not unnecessarily call approval;
- successful synthetic action records outcome without raw private content.

### App Intents

Only after the internal action boundary is correct, add one synthetic/non-destructive App Intent. The App Intent is an outer interface, not an authority layer.

Do not add real messaging, deletion, payments, health, credential access or destructive automation as part of the first release.

### Exit gate

A real App Intent is not required for the research release. A synthetic App Intent may be included only if it can be proven to preserve the same draft/policy/approval/audit contract.

**AI:** all code and test work.

**Ben:** Apple signing/provisioning/device execution if the environment requires it.

## 11. Phase 6 — Controlled delegation

**Goal:** prove that delegation is a controlled capability, not an implicit escape hatch.

Implement adapters in this order:

1. trusted Mac/local worker, if justified;
2. home-server/trusted-device path, if justified;
3. private cloud path, only if policy and privacy evidence justify it;
4. external AI provider last.

For every target require:

- explicit target identity;
- minimum necessary data;
- classification check;
- redaction/minimization;
- approval where required;
- timeout/cancellation;
- audit metadata;
- result schema validation;
- result verification before downstream use;
- safe refusal on unsupported capability;
- rollback/fallback to local behavior.

Level 4 data remains blocked from automatic external delegation.

No provider integration is required for the project to be considered complete if local execution and the safe control-plane demo are sufficient evidence. Delegation is a separate capability, not a release prerequisite.

**AI:** adapters, tests, documentation and synthetic validation.

**Ben:** only provider/account credentials or owner-bound contracts, if any, and never by committing secrets.

## 12. Phase 7 — Physical iPhone Air evidence

**Goal:** convert the software prototype into an evidence-backed device research result.

This is the first phase where Ben may be genuinely necessary because an AI agent cannot truthfully claim access to a physical device it cannot access.

### AI prepares everything before device access

- deterministic test bundle;
- device-test checklist;
- exact build/revision manifest;
- runtime/model artifact hashes;
- test scenarios;
- expected results;
- evidence template;
- performance capture script/instructions;
- rollback instructions.

### Device evidence to collect

At minimum:

- exact iPhone model identifier;
- iOS version;
- app/build revision;
- artifact/runtime revisions and hashes;
- cold/warm load time;
- time to first result/token where applicable;
- throughput where meaningful;
- peak/observed memory;
- battery start/end and elapsed time;
- thermal behavior;
- cancellation and timeout behavior;
- offline behavior;
- permissions and failure states;
- policy/approval boundary tests;
- no-network/no-external-data verification where applicable.

Never convert simulator, Mac or source-code support into device evidence.

### Human boundary

Ben is optional if a trusted automated device lab with auditable evidence is available. Otherwise Ben performs the physical test session and returns only synthetic/metadata-only evidence. The AI then validates, normalizes and commits the report.

## 13. Phase 8 — Security, privacy and reliability hardening

Run a dedicated final audit across every path.

### Security

- no secrets or credentials;
- no unsafe URL/network fallback;
- no hidden external delegation;
- no arbitrary tool execution;
- no bypass from App Intent/SwiftUI/model path into side effects;
- no stale approval reuse;
- no target/payload mismatch acceptance;
- no Level 4 automatic external delegation.

### Privacy

- raw user text absent from audit output;
- diagnostic UI contains metadata only;
- sensitive detector findings contain categories/reasons, not raw values;
- memory classification is explicit;
- external delegation is minimized and gated;
- public repository contains no private Brain state or device identifiers.

### Reliability

- deterministic tests;
- concurrency tests for shared state;
- cancellation/timeout tests;
- empty/invalid input tests;
- unavailable runtime tests;
- malformed model output tests;
- missing tool and duplicate tool tests;
- reproducible benchmark results;
- reproducible build/test commands.

### AI execution

Use static search plus tests to audit every public entry point and every path capable of producing an action, delegation or model call. Do not rely on documentation alone.

## 14. Phase 9 — Release hardening

**Goal:** produce a clean, reproducible research release.

### Repository checks

At minimum, for the release candidate:

- `python3 scripts/validate_repo_structure.py`;
- `python3 scripts/validation_summary.py`;
- `cd ios && swift build`;
- `cd ios && swift test`;
- all required GitHub Actions checks;
- docs consistency;
- workflow lint when workflows changed;
- security/repo audit;
- exact-head PR review.

Do not report a check as passed without actual local or GitHub evidence.

### Documentation

Update only canonical documents:

- `PROJECT_STATE.md` for durable baseline facts;
- `ROADMAP.md` for phase-level direction;
- `docs/PROJECT_COMPLETION_PLAN.md` for this end-to-end plan;
- `docs/reports/issue-status-matrix.md` for the short live audit companion;
- model/runtime evidence docs for exact experiment evidence;
- device evidence report for physical claims;
- README for concise public orientation.

Do not duplicate full technical contracts into README or status files.

### Release package

Prepare:

- tagged release;
- release notes;
- architecture diagram;
- safety/limitations summary;
- benchmark/evidence summary;
- device evidence report if device work was performed;
- contributor guidance;
- good-first issues that are genuinely still open.

## 15. Phase 10 — Final closure

The project is not closed merely because CI is green. The final closure transaction is:

1. Freeze the release candidate commit.
2. Run all required CI and repository audits.
3. Run the complete synthetic safety matrix.
4. Re-run the exact device evidence set for the release build if a physical claim is made.
5. Review model/runtime licences and exact revisions.
6. Confirm no open high-risk architecture gate remains.
7. Confirm all release claims have matching evidence classes.
8. Confirm no unresolved security/privacy finding remains.
9. Create the release tag and notes.
10. Mark the implementation issues completed only after their acceptance criteria are actually met.
11. Record the terminal evidence in the canonical docs.
12. Stop automatic feature expansion and move the repository into maintenance/research mode.

### Final state

```text
SAFE KERNEL
  + deterministic policy
  + exact approval
  + metadata-minimized audit
  + classified memory
  + bounded tools
  + advisory runtime/model selection
  + synthetic action proof
  + evidence-backed runtime
  + optional controlled delegation
  + physical-device evidence where claimed
  + reproducible release
```

The final product remains a **privacy-first research prototype**, not an unrestricted autonomous agent.

## 16. Issue/backlog execution map

| Track | Current items | Order | Critical? |
| --- | --- | --- | --- |
| Memory | #120, #142 | decision -> implementation -> tests -> kernel boundary | Yes |
| Tools | #137 -> #121 | spec -> metadata integration -> later execution issue | Yes |
| Runtime budget | #181 | estimator -> tests -> diagnostic visibility decision | Yes |
| Model trace | #144 -> #146 -> #147 -> #145/#148/#149 | schema -> value/generator -> tests -> UI | Yes for diagnostics, not runtime |
| App-action policy | #185 — completed | keep the configuration lane closed; scope any future AppAction execution separately | Completed |
| TaskRouter bypass | #101 | already resolved; keep regression coverage | Guard |
| Model selection | #103 | expand only after evidence-backed need | Yes before runtime selection |
| Runtime research | #74, #82, #83, #111 | benchmark -> governance -> runtime evidence -> bounded feasibility | Yes for model/runtime claims |
| Explore | #150 -> #151 -> #152 | validator -> index -> SwiftUI shell | No; parallel |
| Community | #114, #117, #136 | docs/UX polish | No; parallel |

Closed/resolved work must stay closed. The map is a planning view, not permission to reopen old issues.

## 17. AI-agent operating model

The repository can be driven almost completely by agents if the following roles are kept separate.

### Director agent

- reconciles current GitHub state;
- chooses one smallest safe target;
- checks dependency gates;
- never writes product code for its own target;
- never self-approves.

### Producer agent

- implements only the allowlisted slice;
- creates one draft PR;
- runs/records validation;
- re-reads the exact changed files;
- never reviews or merges its own work.

### Review/validation agent

- checks current head, complete diff and issue scope;
- runs or verifies required CI;
- checks semantic safety invariants;
- rejects stale or over-broad changes;
- never implements or merges.

### Closer agent

- acts only after exact-head review and required checks are green;
- rechecks mergeability and head SHA;
- merges one PR with expected-head protection;
- verifies terminal state and updates durable docs if required.

### Sequencer agent

- reconciles completed work;
- detects duplicate targets and stale instructions;
- selects the next legal target only after the previous cycle is terminal;
- never implements/reviews/merges.

### Specialist agents

Research, security, documentation, model-evaluation and device-evidence agents may advise or prepare artifacts, but they do not bypass the core Director -> Producer -> Review -> Closer sequence.

## 18. What Ben should and should not have to do

### Prefer AI-only

- repository inspection;
- issue/PR creation and updates;
- Swift/Python/docs implementation;
- tests and static analysis;
- benchmark harnesses;
- model-selection research;
- licence/source verification from public sources;
- CI reconciliation;
- semantic review;
- release documentation;
- synthetic action tests;
- preparation of device-test procedures.

### Ben only when genuinely unavoidable

- physical iPhone access when no automated device lab exists;
- Apple developer account/signing/provisioning actions unavailable to the agent environment;
- accepting a licence/legal term that requires the owner;
- choosing between materially different product policies when existing written requirements do not decide the question;
- final public release approval if the owner wants that as a governance boundary.

Every Ben boundary must be explicit, minimal and documented. It must never become a reason for an agent to stop work that can be completed safely without him.

## 19. Per-task execution template

Every implementation issue should follow this exact loop:

```text
1. Verify issue and current GitHub state.
2. Verify predecessor gates are terminal.
3. Define allowlisted files and stop rules.
4. Implement the smallest independent slice.
5. Add/retain regression tests.
6. Run exact validation commands.
7. Open one draft PR with Summary / Scope / Validation / Safety / Follow-up.
8. Review the exact current head independently.
9. Fix only concrete findings.
10. Re-run required checks.
11. Merge with expected-head protection.
12. Verify main.
13. Close the implementation issue if and only if acceptance criteria are met.
14. Update the short issue-status matrix.
15. Select the next smallest legal target.
```

## 20. Stop rules for the entire completion program

Stop and create a narrower decision issue instead of guessing when:

- a safety invariant is ambiguous;
- two canonical documents disagree;
- an issue's allowed files do not cover the needed change;
- a model/runtime claim lacks exact evidence;
- a physical-device claim lacks physical-device evidence;
- a licence is unclear;
- a tool could execute outside the policy/approval boundary;
- approval could be reused after the draft changes;
- a proposed change needs networking, signing, entitlements or real user data without explicit scope;
- CI failure is not attributable to the current head;
- a second implementation PR would be required.

Never solve uncertainty by silently widening scope.

## 21. Completion scorecard

The Director should track these gates as binary evidence, not subjective percentages:

- [ ] baseline reconciled;
- [ ] MemoryStore classification/retention decision closed;
- [ ] MemoryStore implementation/tests closed;
- [ ] ToolRegistry integration spec closed;
- [ ] ToolRegistry metadata integration/tests closed;
- [ ] RuntimeBudget estimator/tests closed;
- [ ] model-selection decision trace closed;
- [x] setup/admin approval policy closed;
- [ ] complete synthetic kernel matrix green;
- [ ] diagnostic shell truthful and complete;
- [ ] immutable benchmark green;
- [ ] selected runtime has reproducible host evidence;
- [ ] model/runtime evidence contract complete;
- [ ] safe synthetic action boundary proven;
- [ ] App Intent, if included, preserves the same boundary;
- [ ] delegation, if included, is minimized/approved/audited/verified;
- [ ] physical-device report exists for every device claim;
- [ ] final security/privacy audit green;
- [ ] release CI green;
- [ ] release documentation complete;
- [ ] tagged release published;
- [ ] all high-risk architecture gates terminal;
- [ ] project moved to maintenance/research mode.

This scorecard is complete only when every checked item has source-backed evidence in GitHub or an explicitly identified owner boundary.
