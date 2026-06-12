# iGentic Roadmap

Last updated: 2026-06-12

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
- Community and brand foundation are now being added.

## Phase 0 — Research and project foundation

**Goal:** Make the project understandable, safe and contribution-ready.

### Done / in progress

- README with thesis and architecture.
- Source verification rules.
- Apple API review.
- Local runtime review.
- Model strategy.
- Community health docs.
- Apache 2.0 license.
- Brand foundation.
- Community strategy.
- Social media playbook.

### Next

- Add initial brand assets under `assets/brand/`.
- Add GitHub social preview asset.
- Add issue templates for design feedback and device test reports.
- Add a `GOVERNANCE.md` file when outside contributors appear.
- Keep `PROJECT_STATE.md` current.

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

**Goal:** Evaluate local model/router options without committing model weights.

Research candidates:

- Apple-native APIs,
- MLX Swift,
- MLC-LLM,
- llama.cpp-derived paths,
- small router models,
- embedding models for local RAG.

Exit criteria:

- Runtime comparison doc is source-linked.
- No private data is sent externally by default.
- No model weights committed.
- Device constraints are documented from real tests.

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

### Later

- Publish official SVG logo pack.
- Add GitHub social preview.
- Create Instagram carousel templates.
- Create website landing page.

## Maintainer rule

When in doubt, choose the path that is:

1. more private,
2. more auditable,
3. easier to review,
4. easier for contributors to understand,
5. less likely to imply unsafe autonomy.
