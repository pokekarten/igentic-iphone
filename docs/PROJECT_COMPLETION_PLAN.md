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

Issue #185 is the product decision lane. The final shape should be:

- setup creates a conservative default policy;
- the user can explicitly configure approval requirements by action kind/family;
- settings/admin can review and change the policy later;
- runtime consumes the stored policy rather than inventing hidden policy;
- blocked actions remain blocked regardless of configuration;
- diagnostics show the effective configured policy without exposing private content.

The first implementation should be local-only configuration. No network-backed administration is required.

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
