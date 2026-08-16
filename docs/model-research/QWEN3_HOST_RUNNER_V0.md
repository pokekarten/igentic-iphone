# Qwen3 0.6B Offline Host Runner V0

Status: external research execution harness  
Parent: Issue #284  
Model: `Qwen/Qwen3-0.6B`  
Pinned revision: `c1899de289a04d12100db370d81485cdf75e47ca`

## Purpose

`scripts/qwen3_host_runner.py` is the smallest executable host boundary for the untouched Qwen3 0.6B Benchmark V0 baseline. It does not belong to the iPhone product runtime and does not add Transformers, PyTorch or model weights to repository dependencies.

The harness consumes the existing canonical adapter contract instead of copying prompts, tool schemas, generation settings or seed lists.

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

Deterministic Swift policy, approval, schema validation, execution and audit remain authoritative. Model output is research evidence only.

## External environment

The repository intentionally does not declare host-model dependencies. Create a separate disposable environment with an already downloaded exact model snapshot and locally installed PyTorch plus Transformers >= 4.51.0.

The pinned Qwen README states that Qwen3 requires Transformers 4.51.0 or newer and loads the reference model with `torch_dtype="auto"`. The host runner therefore uses the same dtype selection while keeping device placement explicit. `run-metadata.json` records the resulting `model_dtype`, exact Transformers and PyTorch versions, Python version, host OS and architecture at model-execution time so later evidence packaging cannot accidentally substitute the packaging machine's environment. Current Hugging Face documentation also supports `local_files_only`, `trust_remote_code=false`, JSON-schema tools in `apply_chat_template`, and the pinned sampling arguments used by the adapter.

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

`raw-outputs.jsonl` contains only `case_id` and the decoded `assistant_text`; no semantic repair is applied. The pinned tokenizer marks `<tool_call>` and `</tool_call>` as non-special tokens, while transport tokens such as `<|im_end|>` are special. Using `skip_special_tokens=true` therefore preserves the tool-call envelope required by the existing normalizer while dropping tokenizer transport markers. Any stray prose, malformed call or non-thinking-contract violation that remains in the decoded assistant span stays measurable failure evidence.

## Validation

Repository CI runs:

```bash
python3 scripts/test_qwen3_host_runner.py
```

Those tests do not import Transformers or PyTorch and do not execute a model. They bind the offline path guard, exact load options, host-environment provenance, exact profiles, fail-closed seed output planning, adapter generation contract, inherited effective-generation provenance, precommitted seeds and fail-closed tokenizer budget preflight.

## Follow-up

After this harness is independently reviewed and merged, the next bounded slice is evidence packaging: normalize and evaluate each of the five seed/profile raw-output files, hash the generated artifacts and emit one valid `igentic-baseline-run-v0` manifest per seed/profile run. That later slice must still distinguish host evidence from physical-device evidence.
