# iGentic Model Research

Status: canonical research index  
Last reviewed: 2026-06-22

This directory contains public-safe, source-backed contracts for selecting, evaluating and eventually testing local models for iGentic on the iPhone Air. It does not prove that any custom model currently runs on the device.

## Read in this order

1. [`../../MODEL_STRATEGY.md`](../../MODEL_STRATEGY.md) — permanent safety and model-authority rules.
2. [`../local-runtime-review.md`](../local-runtime-review.md) — runtime prerequisites and comparison boundary.
3. [`IPHONE_AIR_MODEL_CANDIDATES.md`](IPHONE_AIR_MODEL_CANDIDATES.md) — candidate, license, runtime and evidence manifest.
4. [`IGENTIC_ACTION_BENCHMARK_V0.md`](IGENTIC_ACTION_BENCHMARK_V0.md) — immutable action-routing benchmark contract.
5. [`igentic-action-benchmark-v0.jsonl`](igentic-action-benchmark-v0.jsonl) — 40 synthetic German/English V0 cases.
6. Parent research issue `#74` and knowledge-export roadmap `#79` — current source-backed follow-up sequence.

The product-wide routing rules are in [`../KNOWLEDGE_MAP.md`](../KNOWLEDGE_MAP.md).

## Fixed safety boundary

- Models may propose, classify, summarize, route or draft.
- `PolicyEngine`, `ApprovalManager`, schema validation, audit and execution remain deterministic authority.
- No model may authorize or directly execute a side-effectful action.
- Early research uses synthetic public-safe data only.
- No model weights, adapters, provider keys or private prompts belong in this repository.
- Runtime, Mac, simulator, Android and vendor results are not physical iPhone Air evidence.

## Current research lanes

### Apple system-model comparison

Evaluate Apple Foundation Models as a system-provided backend without shipping iGentic-owned weights. Availability, locale, OS and device behavior must be checked in the app. It remains behind the same deterministic proposal boundary as every other backend.

### FunctionGemma 270M specialization candidate

FunctionGemma is the first very-small task-specialization candidate for a fixed action router. It is license-gated, is not treated as a general dialogue model and must first be measured untouched against the common benchmark.

### Qwen3 0.6B multilingual comparison

Qwen3 0.6B is the first Apache-2.0 multilingual custom-model comparison. Use non-thinking mode and short router profiles first. Runtime support or conversion does not establish acceptable iPhone Air memory, latency, battery or thermal behavior.

The newest, largest or most multimodal model does not advance automatically. License, structured-output reliability, deterministic stopping, export compatibility and physical-device evidence are mandatory gates.

## Versioned research flow

```text
candidate manifest
→ immutable benchmark
→ validator and normalized proposal schema
→ untouched backend baselines
→ select at most one specialization candidate
→ dataset and training contract
→ reproducible LoRA/QLoRA run when justified
→ export/runtime comparison
→ physical iPhone Air test report
```

Do not fine-tune before comparable untouched baselines exist.

## Benchmark V0

V0 is a deliberately small immutable core:

- 40 synthetic cases;
- 20 German and 20 English;
- eight cases for each current intent group;
- clear, missing-argument, ambiguous, unsupported, no-tool and refusal cases;
- no real user content.

The earlier 120-case research target is a later versioned expansion, not permission to edit V0 in place. Corrections or added cases require a new benchmark version and migration note. V0 cases must never be copied, paraphrased or generated into training data.

## Planned contracts

Tracked from roadmap issue `#79`:

1. **Knowledge map and index** — this index and `docs/KNOWLEDGE_MAP.md`.
2. **Benchmark validator and evaluator** — issue `#81`; machine-check V0 and score backend-neutral normalized proposals without model dependencies or network access.
3. **Dataset and training governance** — versioned public-safe training splits, contamination prevention, run manifests and `KEEP`, `REWORK` or `REJECT` decisions.
4. **Runtime/export evidence** — exact model revision, tokenizer/template, quantization, artifact format, cancellation and rollback.
5. **Physical-device evidence** — named iPhone, OS, build, package size, cold/warm load, latency, memory where observable, battery, thermal state, cancellation and crash/OOM behavior.
6. **Existing-document reconciliation** — only after the canonical contracts exist; do not duplicate live status.

## Evidence record requirements

Every future model or training result must identify:

- exact model repository and immutable revision;
- license reference and review date;
- dataset and split hashes;
- prompt or chat-template revision;
- dependency lock or exported environment;
- decoding, context and output limits;
- quantization and adapter settings where applicable;
- benchmark version;
- execution environment;
- result artifact and explicit decision;
- evidence class and known limitations.

Unknown values stay `unknown` or `unverified`. Do not infer iPhone Air readiness from model size, advertised context length or another device's benchmark.

## Change rules

- Keep this file navigational; put detailed facts in the relevant canonical contract.
- Do not add a model without a defined iGentic role and next test.
- Do not silently replace source links, licenses, benchmark expectations or model revisions.
- Open one narrow reconciliation issue when durable documents conflict.
- Keep current PR, check and lane state out of this directory.