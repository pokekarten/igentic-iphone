# Model Strategy

Status: Phase 0 research artifact
Last updated: 2026-06-12

This document defines how iGentic iPhone should think about models before any model runtime is integrated.

## Core principle

Models are helpers, not authorities.

A model may propose, classify, summarize, route, or draft. It must not bypass policy, approval, tool metadata, memory boundaries, or audit logging.

## Model roles

| Role | Description | First implementation |
| --- | --- | --- |
| Router helper | Helps map user text to an intent | Later, behind deterministic fallback |
| Summarizer | Summarizes local notes or synthetic diagnostics | Later, local-only first |
| Memory helper | Helps retrieve or rank scoped memory | Later, after `MemoryStore` exists |
| Tool planner | Suggests a tool path | Later, never executes directly |
| Local agent brain | Handles richer reasoning | Later, behind `LocalModelRuntime` |
| Delegated worker | Runs larger tasks on Mac, home server, PCC or external provider | Later, behind `DelegationBroker` |

## Candidate families

| Candidate | Fit | Decision |
| --- | --- | --- |
| Apple Foundation Models | Apple-native language layer | Preferred first Apple-native experiment after diagnostic shell |
| Core AI-compatible models | On-device model experiments | Candidate after runtime adapter protocol |
| Qwen small models | Router/helper candidates | Research only; no weights in repo |
| Llama small models | Router/helper candidates | Research only; license and device tests required |
| Gemma small models | Router/helper candidates | Research only; license and device tests required |
| Phi small models | Router/helper candidates | Research only; license and device tests required |
| External frontier models | Strong delegated reasoning | Only explicit, approval-gated delegation |

## Data rules

- Level 0 and Level 1 data may be used for local tests.
- Level 2 data requires context minimization.
- Level 3 data requires explicit approval before model use.
- Level 4 data must not be delegated automatically.
- Synthetic data should be used for all early tests.

## Runtime rules

- No model weights in the repository.
- No automatic download of large models.
- No external provider keys in the repository.
- No local model claims without device evidence.
- No background-agent claims without iOS background behavior tests.
- PCC is treated as delegation, not local-only execution.

## Evaluation criteria

Every model candidate needs:

- source URL,
- license,
- parameter size,
- expected memory footprint,
- target runtime,
- target device,
- privacy impact,
- prompt/data classes used,
- latency notes,
- battery/thermal notes,
- failure modes,
- rollback plan.

## First model experiment

Not yet.

Before the first model experiment, complete:

1. `MemoryStore` safe stub,
2. `DelegationBroker` policy-gated stub,
3. diagnostic shell,
4. `LocalModelRuntime` protocol,
5. synthetic prompt test harness.

## Phase-0 conclusion

The strategy is Apple-native-first, local-first, and policy-gated. External or delegated models are allowed only when the user explicitly approves and the data classification allows it.
