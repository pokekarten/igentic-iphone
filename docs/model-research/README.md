# iGentic Model Research

Status: canonical index for local-model research artifacts

## Purpose

This directory contains public-safe, source-backed contracts for selecting, evaluating and eventually adapting local model backends for iGentic on the iPhone Air.

It does not contain model weights, adapters, checkpoints, private prompts, real user data or physical-device performance claims.

## Current artifacts

### Candidate manifest

`docs/model-research/IPHONE_AIR_MODEL_CANDIDATES.md`

Defines:

- the deterministic Swift authority boundary;
- Apple Foundation Models as an independent system-backend path;
- custom open-weight candidates and license gates;
- runtime research order;
- the untouched baseline plan;
- free-tier training and rollback requirements;
- the difference between runtime evidence and physical iPhone Air evidence.

### Immutable benchmark contract

`docs/model-research/IGENTIC_ACTION_BENCHMARK_V0.md`

Defines the first source-aligned action-routing benchmark for the current iGentic intents and proposal schema. It includes deterministic component metrics and an immutable-test policy.

### Immutable benchmark data

`docs/model-research/igentic-action-benchmark-v0.jsonl`

Contains exactly 40 synthetic records:

- 20 German;
- 20 English;
- 8 per current intent group;
- clear, missing-argument, ambiguous, unsupported, no-tool and refusal cases.

These records are evaluation-only and must never be copied, paraphrased or used as generation seeds for training data.

## Current candidate order

The paths are compared independently rather than treated as one linear model ranking.

1. **Apple Foundation Models** — system-provided backend comparison without shipping an iGentic-owned base model.
2. **FunctionGemma 270M** — first specialization candidate for constrained action routing, subject to the Gemma license gate.
3. **Qwen3 0.6B** — first Apache-2.0 multilingual comparison.
4. Larger, multimodal or custom-license candidates — only after smaller untouched baselines, license review and runtime evidence justify them.

A newer, larger or more heavily advertised model does not automatically advance.

## Research sequence

```text
source verification
-> candidate manifest
-> immutable benchmark
-> benchmark validator
-> backend-neutral evaluator
-> untouched backend baselines
-> dataset and training governance
-> optional LoRA or QLoRA experiment
-> export and runtime compatibility
-> physical-device evidence
-> product decision
```

## Planned contracts

The knowledge-export roadmap is tracked by the parent GitHub issue for this research track. Planned artifacts include:

- a machine-checkable benchmark validator;
- a backend-neutral proposal evaluator;
- dataset provenance and contamination controls;
- a provider-independent training-run manifest;
- runtime compatibility and rollback evidence;
- a physical iPhone Air measurement protocol;
- synchronization of high-level project summaries after the canonical contracts exist.

Future issues are planning artifacts until a single active implementation target is selected. They do not prove that a model was downloaded, run, trained, exported or tested on a device.

## Model proposal boundary

A model may return a constrained proposal such as:

- `tool_call`;
- `clarify`;
- `no_tool`;
- `refuse`.

The model does not own data classification, policy, approval, audit, execution authorization or rollback. Those remain deterministic Swift responsibilities.

## Evidence rules

Use `docs/KNOWLEDGE_MAP.md` for the complete evidence ladder.

At minimum:

- a model card is a source claim;
- runtime source support is not successful export evidence;
- desktop or simulator success is not physical iPhone Air evidence;
- physical execution is not automatically acceptable product behavior;
- every result must identify the exact artifact, revision, runtime and configuration.

## Immutable benchmark rule

Benchmark V0 is immutable after merge. Corrections require a new version and migration note. Training and validation datasets must be developed independently and checked for duplicate or near-duplicate contamination.

## Repository safety rules

- No model weights, adapters or checkpoints.
- No automatic large-model downloads.
- No provider credentials or access material.
- No real messages, contacts, files or device identifiers.
- No unsupported performance or readiness claims.
- No model output may bypass deterministic validation and policy.

## Related project sources

- `MODEL_STRATEGY.md`
- `docs/SOURCE_VERIFICATION.md`
- `docs/local-runtime-review.md`
- `docs/apple-api-review.md`
- `docs/KNOWLEDGE_MAP.md`
- `PROJECT_STATE.md`
- `ROADMAP.md`