# Local Runtime Review

Status: Phase 0 research artifact
Last updated: 2026-06-12

This document compares likely runtime paths for local or delegated AI in iGentic iPhone. It is intentionally conservative: no runtime is integrated until policy, approval, audit, tools, memory boundaries, and a diagnostic shell are stable.

## Decision summary

The first runtime target is not a model. The first runtime target is a safe kernel that can decide whether a model is allowed to see data at all.

## Runtime candidates

| Runtime | Fit | Strength | Risk | Current decision |
| --- | --- | --- | --- | --- |
| Apple Foundation Models framework | High | Native Swift API, Apple models, on-device/PCC path | Availability, changing API surface, device/region limits | Prototype candidate after diagnostic shell |
| Core AI | High | On-device AI path designed for Apple Silicon | Newer surface, needs device testing | Prototype candidate after Phase 2 |
| Core ML | Medium | Mature Apple ML integration, good for traditional models | Not first choice for LLM-style agent brain | Keep as supporting runtime |
| MLX Swift | Medium | Swift API for MLX, Apple Silicon research path | iPhone deployment and Metal shader build constraints need testing | Research candidate |
| MLC-LLM | Medium | Universal LLM deployment engine | Integration complexity, iOS packaging risk | Later candidate |
| llama.cpp | Medium | Broad LLM inference ecosystem | Native iOS integration and performance need careful testing | Later candidate |
| External AI provider | Low by default | Strong models | Privacy, cost, data exposure | Only policy-gated delegation |
| Mac/Home Server worker | Medium | More compute than iPhone | Trust, sync, local network complexity | Later trusted-device delegation |

## What must be true before runtime integration

Before any model runtime is added, the repo must have:

- `PolicyEngine` for allow/deny decisions,
- `ApprovalManager` for user gates,
- `AuditLog` for traceability,
- `ToolRegistry` for metadata-only tool definitions,
- `MemoryStore` for scoped and deletable memory boundaries,
- `DelegationBroker` for explicit delegation decisions,
- a diagnostic UI/test shell,
- a device test plan.

## Apple-native path

### Foundation Models framework

Best fit for an Apple-native agent layer once available and tested in the target environment. It should be hidden behind a `LocalModelRuntime` protocol so policy stays independent of Apple API changes.

Rules:

- Never call it before classification and policy evaluation.
- Never pass Level 4 data automatically.
- Log prompts and decisions carefully without dumping private raw data.
- Treat PCC-backed execution as delegation, not local execution.

### Core AI

Best candidate for future on-device AI model experiments. It should be evaluated with synthetic inputs first.

Rules:

- Device tests required before performance claims.
- Thermal and battery notes required.
- No model weights committed.
- No background-agent assumptions.

### Core ML

Useful for traditional ML or converted models, but not the primary LLM path. Good for small classifiers, routing helpers, or non-generative tasks.

## Open-source runtime path

### MLX Swift

Promising for Apple Silicon research and Swift-native experimentation. It may be useful for Mac-side research first, then possibly iOS experiments.

Current caution:

- Do not add dependency yet.
- Do not assume iPhone performance.
- Use only after a small runtime adapter task.

### MLC-LLM

Useful to watch for iOS and mobile deployment, but integration should wait until the kernel has delegation and memory boundaries.

### llama.cpp

Useful as a broad baseline for local LLM inference and delegated Mac/Home Server experiments. iOS integration should remain later-stage.

## External path

External providers are not a local runtime. They are delegation targets.

Rules:

- Default deny for sensitive data.
- Approval required.
- Minimize prompt content.
- Audit decision and target.
- Prefer synthetic tests.

## Phase-0 conclusion

Runtime work should not start yet. The next safe build order is:

1. `MemoryStore` safe stub,
2. `DelegationBroker` policy-gated stub,
3. diagnostic shell,
4. local runtime adapter protocol,
5. Apple-native experiment,
6. open-source runtime experiment.
