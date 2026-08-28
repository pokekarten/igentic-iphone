# Qwen3 0.6B Offline Host Runner V0

Status: external research execution harness  
Parent: Issue #284  
Evidence-packaging follow-up: Issue #309  
Model: `Qwen/Qwen3-0.6B`  
Pinned revision: `c1899de289a04d12100db370d81485cdf75e47ca`

## Purpose

`scripts/qwen3_host_runner.py` is the smallest executable host boundary for the untouched Qwen3 0.6B Benchmark V0 baseline. It does not belong to the iPhone product runtime and does not add Transformers, PyTorch or model weights to repository dependencies.

The harness consumes the existing canonical adapter contract instead of copying prompts, tool schemas, generation settings or seed lists. `scripts/qwen3_baseline_packager.py` is a separate standard-library-only evidence step: it never loads or executes the model.

## Safety boundary

The harness:

- accepts only a local snapshot directory whose final path component is the exact pinned model revision;
- forces Hugging Face/Transformers offline mode;
- loads with `local_files_only=true` and `trust_remote_code=false`;
- never downloads a model;
- never executes a proposed tool;
- never receives private user data;
- does not train, fine-tune, quantize or modify weights;
- produces host evidence only and never establishes physical iPhone Air readiness.

The evidence packager accepts only a completed host run with the pinned model/revision, canonical profile and one of the precommitted seeds. It refuses physical-device claims, malformed provenance, missing runtime-observation evidence, symlinked evidence inputs and pre-existing package targets.

Deterministic Swift policy, approval, schema validation, execution and audit remain authoritative. Model output is research evidence only.

## External environment and runtime provenance

The repository intentionally does not declare host-model dependencies. Create a separate disposable environment with an already downloaded exact model snapshot and locally installed PyTorch plus Transformers >= 4.51.0.

The pinned Qwen README states that Qwen3 requires Transformers 4.51.0 or newer and loads the reference model with `torch_dtype="auto"`. The host runner therefore uses the same dtype selection while keeping device placement explicit.

`run-metadata.json` records at model-execution time:

- exact model ID and immutable revision;
- selected profile and seed;
- model dtype;
- Transformers and PyTorch versions;
- Python version, host OS and architecture;
- execution device;
- host evidence class and `physical_device_run=false`;
- `model.config.max_position_embeddings` as the actual configured context capacity;
- the canonical tokenizer chat-template ID and SHA-256.

The context capacity must be a positive integer and large enough for the selected V0 input plus output budget. The packager revalidates it and copies that observed capacity into `profile.context_limit_tokens`; it never substitutes the smaller benchmark profile budget as if that were the backend context capacity.

For prompt provenance, the runner asks the loaded tokenizer to resolve the exact template for the canonical tool-bearing request via `get_chat_template(tools=...)` and hashes the returned template string as exact UTF-8 bytes. This matters when a tokenizer exposes multiple named templates: the manifest binds the template actually selected for tool use, not a broader template mapping. A missing resolver, resolution failure or empty selected template fails closed before generation.

A standard Hugging Face cache snapshot normally has a path ending in the immutable revision, for example:

```text
.../models--Qwen--Qwen3-0.6B/snapshots/c1899de289a04d12100db370d81485cdf75e47ca
```

The directory name check is an offline identity guard, not independent proof that the local bytes equal the upstream publication. Reviewed evidence should retain the local snapshot separately if byte-level verification is required.

## Profiles

The harness supports only the two canonical Benchmark V0 router profiles:

```text
Router-small   input <= 512 tokens   max_new_tokens = 32
Router-normal  input <= 1024 tokens  max_new_tokens = 64
```

Every canonical case is rendered with the pinned tokenizer, adapter messages, adapter tools and adapter chat-template kwargs before any generation occurs. If one case exceeds the selected input budget, the whole profile fails before generation. Input truncation is forbidden.

## Sampling and repeats

The harness imports the adapter's exact hard non-thinking generation contract:

```text
do_sample=true
temperature=0.7
top_p=0.8
top_k=20
min_p=0.0
```

It adds only the selected profile's `max_new_tokens` cap. It also consumes the precommitted seeds `0,1,2,3,4` directly from the adapter and resets the external runtime seed once at the start of each seed/profile run.

Seed numbers prevent post-result seed selection. They do not imply equivalent random streams across different hardware, frameworks or backends.

The generation call passes only those explicit Benchmark V0 overrides. For provenance, `applied-generation-config.json` records the complete loaded `model.generation_config` merged with the runner overrides, so inherited stopping/token/default fields remain bound together with the selected non-thinking settings. The explicit runner values win when the upstream model configuration contains different defaults.

## Explicit output observations

Every raw output record carries two booleans in addition to `case_id` and `assistant_text`:

- `repetitionDetected`: true when the decoded output contains more than one Qwen `<tool_call>` opening or closing envelope. This is deliberately a narrow repeated-proposal detector; it is not a general semantic or lexical-loop detector.
- `truncationDetected`: true when generation consumes the complete selected `max_new_tokens` budget. This is conservative: hitting the cap is retained as truncation evidence rather than guessed away.

The packager requires both booleans on every benchmark case. Missing flags invalidate packaging instead of becoming implicit `false` observations. The existing Qwen normalizer carries valid boolean observation fields into normalized proposal JSONL without changing proposal semantics.

## Run

Example external host command:

```bash
python3 scripts/qwen3_host_runner.py \
  --snapshot /local/hf-cache/models--Qwen--Qwen3-0.6B/snapshots/c1899de289a04d12100db370d81485cdf75e47ca \
  --profile Router-small \
  --output-dir /local/igentic-qwen-v0 \
  --device cpu
```

Before loading the model or generating any case, the harness checks all five target seed directories. If any target already exists, the run fails without creating the other seed directories. This prevents a rerun from silently producing a mixed old/new stochastic evidence set.

For each seed it writes:

```text
<output>/<profile>/seed-N/
  applied-generation-config.json
  raw-outputs.jsonl
  run-metadata.json
  token-counts.json
```

`raw-outputs.jsonl` retains the decoded `assistant_text` exactly as research evidence; no semantic repair is applied. Using `skip_special_tokens=true` removes tokenizer transport markers while preserving the non-special `<tool_call>` envelope expected by the normalizer. Stray prose, malformed calls, repeated envelopes or capped output remain measurable failure evidence.

## Evidence packaging

Package one completed seed/profile directory only after the host runner has finished writing all four raw evidence files:

```bash
python3 scripts/qwen3_baseline_packager.py \
  --run-dir /local/igentic-qwen-v0/Router-small/seed-0
```

The packager performs no model import, download or generation. It validates all raw provenance first, then:

1. reconstructs byte-stable synthetic adapter request envelopes;
2. normalizes through the existing Qwen adapter without semantic repair;
3. evaluates through the existing backend-neutral V0 evaluator;
4. requires explicit repetition and truncation flags for every case;
5. hashes benchmark, evaluator contract/scripts, adapter, token counts, generation config and generated artifacts;
6. builds one host-only `igentic-baseline-run-v0` manifest;
7. runs the existing manifest validator before writing any package target.

A successful package adds:

```text
<output>/<profile>/seed-N/
  normalized-input.jsonl
  normalized-proposals.jsonl
  evaluator-result.json
  baseline-run-manifest.json
```

`normalized-input.jsonl` is a byte-stable reconstruction of the synthetic adapter request envelopes and is bound by `input.normalized_input_sha256`. The manifest records model-execution environment and context capacity from `run-metadata.json`, not from the later packaging environment. `normalizer.revision` is the SHA-256 of the exact repository adapter source used for packaging.

Manifest-level repetition/truncation observations are the OR across the explicit per-case runner flags. If any case lacks either flag, the package fails closed. Timeout and cancellation remain false for this completed-run packager; a future interrupted-run evidence contract must represent incomplete execution separately rather than package it as completed.

If any target package file already exists, packaging stops before writing anything. A completed package always uses `next_decision=unverified`; selecting `KEEP`, `REWORK` or `REJECT` remains a later comparison decision.

## Validation

Repository CI runs:

```bash
python3 scripts/test_qwen3_host_runner.py
python3 scripts/test_qwen3_baseline_packager.py
```

These tests do not import Transformers or PyTorch and do not execute a model. They bind the offline path guard, exact load options, host-environment provenance, actual context-capacity capture, exact selected tokenizer-template hash, canonical profiles, fail-closed seed output planning, adapter generation contract, inherited effective-generation provenance, explicit output observations, tokenizer budget preflight, package identity checks, deterministic hashes, manifest self-validation and no-partial-write behavior for pre-existing outputs.

## Follow-up

After Issue #309 is independently reviewed and merged, the next evidence action is an actual external untouched Qwen3 0.6B host run with the pinned snapshot and environment, followed by packaging of every completed seed/profile run. Only those source-backed results may be compared with the other untouched backends. Host evidence still cannot establish physical iPhone Air readiness, and no fine-tuning should begin before comparable untouched-baseline evidence exists.
