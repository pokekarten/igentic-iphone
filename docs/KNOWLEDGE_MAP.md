# iGentic Knowledge Map

Status: canonical navigation and knowledge-routing contract

## Purpose

This file identifies the authoritative source for each kind of durable iGentic knowledge and defines the evidence required before a claim becomes part of the project record. It is an index, not a replacement for the linked contracts.

## Source order

```text
current verified GitHub source
> durable product contract
> private operating memory
> remembered context
> explicit assumption
```

A merged pull request or closed issue must never be revived by an older document or remembered conversation.

## Repository roles

| Role | Canonical content |
| --- | --- |
| iGentic product repository | architecture, safety contracts, model strategy, research manifests, benchmarks, evaluator rules, runtime evidence and public decisions |
| Private Brain | compact operating state and durable private coordination rules |
| Public development playbook | sanitized reusable methods proven across projects |
| Private SLM lab | abstracted and redacted schemas, labels and evaluation examples |

Product truth stays in the product repository. The Brain is not a second product source of truth. The playbook contains generic methods rather than project history. The SLM lab contains abstractions rather than copied product benchmark records.

A new repository is justified only when an artifact needs an independent lifecycle, access boundary and release process that cannot be represented safely in these roles.

## Durable knowledge and mutable state

Durable knowledge includes architecture, safety boundaries, benchmark schemas, validation rules, source standards and evidence requirements. It belongs in versioned files with one canonical home.

Mutable state includes the current pull request, branch, head revision, workflow result, mergeability and lane stage. It belongs in the current GitHub resource and, when needed, the private operating lane. It must not be copied into durable product documents.

## Canonical product sources

| Topic | Canonical source |
| --- | --- |
| Product thesis and contributor entry | `README.md` |
| Durable project baseline | `PROJECT_STATE.md` |
| Phases and exit criteria | `ROADMAP.md` |
| General model roles and safety | `MODEL_STRATEGY.md` |
| Source quality and claim wording | `docs/SOURCE_VERIFICATION.md` |
| Apple API research | `docs/apple-api-review.md` |
| Local runtime research | `docs/local-runtime-review.md` |
| App Intents safety | `docs/app-intents-safety.md` |
| iPhone Air model selection | `docs/model-research/IPHONE_AIR_MODEL_CANDIDATES.md` |
| Benchmark contract | `docs/model-research/IGENTIC_ACTION_BENCHMARK_V0.md` |
| Immutable benchmark records | `docs/model-research/igentic-action-benchmark-v0.jsonl` |
| Model-research navigation | `docs/model-research/README.md` |
| Validation | `docs/VALIDATION.md` |
| Repository workflow | `docs/GITHUB_CONTROL.md` and `docs/WORKFLOWS.md` |
| Live task state | current GitHub issue or pull request plus the private operating lane |

Summary files should link to detailed contracts instead of copying them.

## Evidence classes

Evidence classes are not interchangeable.

| Class | Proves | Does not prove |
| --- | --- | --- |
| Source claim | what a primary source states | that iGentic reproduced it |
| Software contract | deterministic types, rules, validators and tests | model quality or device performance |
| Simulator or host result | behavior in the named host environment | physical iPhone Air execution |
| Runtime result | an exact artifact works with an exact runtime and configuration | another artifact, runtime or device works |
| Physical-device result | measured behavior for an exact build and configuration on a physical device class | general readiness across devices |
| Assumption | a hypothesis for the next test | a verified claim |

```text
runtime source support != successful export
successful export != host execution
host execution != physical iPhone execution
physical execution != acceptable product behavior
```

Unknown values remain `unknown`, `unverified` or `none`.

## Model authority boundary

Models may propose an intent, tool call, clarification, refusal, summary or draft. Deterministic Swift remains authoritative for schema validation, data classification, policy, approval, audit, execution authorization and rollback.

## Model-research flow

```text
candidate manifest
-> immutable benchmark
-> validator and backend-neutral evaluator
-> untouched baselines
-> dataset and training governance
-> optional specialization
-> export and runtime evidence
-> physical iPhone Air measurement
-> product decision
```

The first independent comparison paths are:

1. Apple Foundation Models as a system-provided backend;
2. FunctionGemma 270M as the first specialization candidate;
3. Qwen3 0.6B as the first Apache-2.0 multilingual comparison.

Larger or multimodal candidates advance only when smaller baselines, license gates and runtime evidence justify them.

## Benchmark and training separation

Immutable evaluation records are never training data. Do not copy, paraphrase or use them as generation seeds for training examples. Record dataset provenance, revisions and hashes. Compare untouched baselines before selecting a training run. Model artifacts do not belong in this repository.

## Publication boundary

Public project sources may contain synthetic examples, public source links, schemas, validators, evaluation rules and metadata-only evidence. They must not contain real user content, access material, raw conversations, repository dumps, unredacted personal logs or model artifacts.

## Update rules

1. Read the canonical source before editing a summary.
2. Verify fast-moving claims against current primary sources.
3. Change the canonical contract first, then update links and summaries.
4. Do not create duplicate status or research files.
5. Do not make timestamp-only knowledge commits.
6. Re-read every changed GitHub resource.
7. Record uncertainty instead of guessing.
8. Keep product truth, operating memory, reusable methods and abstract evaluation data separated.

## Stale-knowledge repair

When documents disagree, verify current GitHub source, identify the canonical topic owner, correct it, replace copied details in summaries with links, then synchronize private operating state. Reusable lessons must be sanitized before entering the public playbook; evaluation structures must be abstracted before entering the SLM lab.

## Active work lookup

This map never stores the live pull request, branch, workflow state or lane revision. Read current GitHub issues and pull requests, then verify the private operating lane named by `PROJECT_STATE.md`.