# Model Strategy

Status: canonical overview for model research  
Last updated: 2026-08-03

This document summarizes how iGentic evaluates model backends. Detailed candidate facts, benchmark rules, training governance and runtime/device evidence belong in the canonical documents under `docs/model-research/`.

## Core principle

Models are helpers, not authorities.

A model may propose, classify, summarize, route or draft. Deterministic Swift remains authoritative for policy, approval, schema validation, audit and execution. No prompt, model output, adapter or runtime may bypass those controls.

## Research paths

The project evaluates three independent paths:

1. **Deterministic Swift authority** — the permanent control and fallback layer.
2. **Apple Foundation Models** — an independent system-backend comparison without iGentic-owned model weights.
3. **Custom open-weight models** — bounded proposal-generation experiments behind the same deterministic controls.

Evidence from one path must not be represented as evidence for another.

## Current candidate order

| Order | Candidate or path | Role | Gate |
| --- | --- | --- | --- |
| Independent comparison | Apple Foundation Models | System-provided proposal and structured-generation comparison | Device, OS, locale, availability and physical-device evidence |
| First specialization candidate | `google/functiongemma-270m-it` | Very small fixed-action router | Gemma license, immutable revision, untouched baseline and export/runtime compatibility |
| First Apache-2.0 multilingual comparison | `Qwen/Qwen3-0.6B` | German/English router and short-assistant comparison | Untouched baseline, non-thinking profile, export/runtime compatibility and physical-device evidence |
| Later candidates | Larger, tool-specific or multimodal models | Role-specific comparisons only | Smaller candidates must first fail a defined quality gate; license and runtime gates remain mandatory |

The newest, largest or most multimodal model does not advance automatically.

The canonical candidate manifest is `docs/model-research/IPHONE_AIR_MODEL_CANDIDATES.md`.

## Canonical research contracts on `main`

- Research index: `docs/model-research/README.md`
- Candidate and license manifest: `docs/model-research/IPHONE_AIR_MODEL_CANDIDATES.md`
- Immutable benchmark contract: `docs/model-research/IGENTIC_ACTION_BENCHMARK_V0.md`
- Immutable benchmark data: `docs/model-research/igentic-action-benchmark-v0.jsonl`
- Validator and evaluator contract: `docs/model-research/EVALUATOR_CONTRACT_V0.md`
- Dataset governance: `docs/model-research/DATASET_GOVERNANCE.md`
- Training-run contract: `docs/model-research/TRAINING_RUN_CONTRACT.md`
- Runtime evidence matrix: `docs/model-research/RUNTIME_EVIDENCE_MATRIX.md`
- Physical-device protocol: `docs/model-research/IPHONE_AIR_DEVICE_EVIDENCE_PROTOCOL.md`

These files are source contracts, not claims that a model has been trained, exported or run on an iPhone Air.

## Evidence sequence

The next evidence sequence is:

```text
candidate manifest
→ immutable benchmark
→ validator and backend-neutral evaluator
→ untouched comparable baselines
→ select at most one specialization candidate
→ governed synthetic training run when justified
→ export and runtime compatibility evidence
→ physical iPhone Air measurement
```

The candidate manifest, immutable benchmark, evaluator contract, dataset/training governance and runtime/device evidence contracts are present. The next empirical step is comparable untouched baseline evidence; training is not justified before that comparison exists.

## Data rules

- Early model research uses synthetic, public-safe data only.
- Immutable benchmark cases must never be copied, paraphrased, translated or generated into training data.
- Private prompts, messages, contacts, files, credentials and production logs do not belong in public model experiments.
- Data classification, minimization and approval rules remain enforced outside the model.

## Runtime rules

- No model weights, adapters or checkpoints in this repository.
- No automatic model download.
- No provider credentials in the repository.
- No model or runtime claim without exact artifact and configuration identity.
- Compile, host and simulator results are not physical iPhone Air evidence.
- Cancellation, timeout, failure recovery and deterministic rollback are required evidence gates.
- External or delegated models require explicit policy and approval handling.

## Evaluation rules

Every comparison must use:

- an immutable model or system revision where exposed;
- the same benchmark and normalized proposal schema;
- recorded tokenizer, prompt, chat and tool-template revisions;
- fixed context, output and decoding profiles;
- separate component metrics rather than one opaque aggregate;
- explicit failure, repetition and truncation evidence;
- a documented evidence class and limitations.

Untouched baselines must be recorded before any specialization. Physical-device claims require the exact protocol in `docs/model-research/IPHONE_AIR_DEVICE_EVIDENCE_PROTOCOL.md`.

## Conclusion

The strategy is deterministic-control-first, Apple-system-backend-aware and custom-model-optional. Models may improve proposal quality, but they never become policy or execution authority. Advancement depends on reproducible evidence, not model size or vendor claims.
