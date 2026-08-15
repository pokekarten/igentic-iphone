# iGentic Untouched Baseline Run Contract V0

Status: executable provenance contract  
Schema: `igentic-baseline-run-v0`  
Parent: Issue #88  
Integrity follow-ups: Issues #274 and #280

## Purpose

This contract binds every untouched backend baseline to the exact benchmark, evaluator, backend, rendered input, decoding configuration, normalizer, execution environment, normalized proposals and evaluator result used for that run.

The package records evidence only. It does not download or run a model, execute a tool, authorize an action, add a runtime provider or establish physical iPhone Air readiness.

## Files and commands

Validate the synthetic example:

```bash
python3 scripts/validate_baseline_run.py \
  docs/model-research/baseline-run-manifest-v0.example.json
```

Run the focused fail-closed regression suite:

```bash
python3 scripts/test_validate_baseline_run.py
```

Both scripts use only the Python standard library, perform no network access and never rewrite the manifest.

## Exact manifest sections

The root object uses the fixed schema version `igentic-baseline-run-v0` and contains no optional sections or undeclared fields.

### Run identity

- `run_id`: stable lowercase slug for one run.
- `untouched_baseline`: must be `true`.
- `known_limitations`: non-empty unique statements.
- `next_decision`: `keep`, `rework`, `reject` or `unverified`.

### Benchmark identity

`benchmark` binds:

- exact benchmark version;
- repository-relative benchmark path;
- lowercase SHA-256 digest of the immutable benchmark bytes.

### Evaluator identity

`evaluator` binds:

- evaluator contract version, path and SHA-256;
- benchmark validator path and SHA-256;
- evaluator executable path and SHA-256.

A result is not comparable when any of these identities differ or are unknown.

### Backend identity

`backend.class` is exactly one of:

- `apple_system`: a system-provided Apple backend. `model_id` and `model_revision` are null because iGentic does not ship or own those weights. `system_model_identifier` binds the exact system model or availability identity exposed by the platform.
- `custom_model`: an externally sourced model. It requires an exact model ID and a full immutable 40- or 64-character hexadecimal revision. `system_model_identifier` is null.

Both classes require the exact framework/backend version, license reference, license review date and gate status. A blocked or unverified license gate cannot produce a `keep` or `rework` decision.

### Input and tokenizer evidence

`input` binds:

- tokenizer ID and immutable revision or exact system-managed identity;
- prompt/chat-template ID and SHA-256;
- SHA-256 of the normalized evaluator input;
- `max_rendered_input_tokens`, the maximum fully rendered and tokenized input length observed across every benchmark case;
- `token_counts_path`, a repository-relative path to a canonical per-case token-count evidence artifact;
- `token_counts_sha256`, the SHA-256 of that artifact.

For a custom model, the token counts must be produced with the exact tokenizer revision recorded in the same manifest after applying the exact prompt/chat template and all model-visible tool schemas. For a system-managed tokenizer, the count method must remain tied to the exact framework/system identity available to the runner.

The token-count artifact is run evidence, not a replacement for the immutable benchmark or the normalized input hash. A runner must not truncate the prompt, tool schema or user text to make a profile fit.

### Normalizer identity

`normalizer` binds the adapter that converts backend output into the normalized proposal JSONL schema. Its revision is an immutable 40- or 64-character hexadecimal revision. This normalizer is not a trained model adapter.

### Router profile

Benchmark V0 has exactly two comparable router profiles. Their experiment budgets are part of the profile identity and must not drift by backend:

| Profile | Maximum input tokens | Maximum output tokens |
| --- | ---: | ---: |
| `Router-small` | 512 | 32 |
| `Router-normal` | 1,024 | 64 |

`profile.context_limit_tokens` records the backend/environment context capacity used for the run. It may be larger than the V0 experiment budget, but it must be large enough for the configured input plus output limits. A larger backend context does not change the named V0 profile.

`input.max_rendered_input_tokens` must be less than or equal to the selected profile's maximum input-token budget. Equality is valid. A smaller measured maximum does not shrink or relabel the profile. A value above the budget invalidates the run; silent truncation is not an allowed repair.

### Decoding and sampling evidence

`decoding` records the comparable settings plus an artifact containing the exact backend decoding configuration actually applied:

- `sampling_enabled`: boolean recording whether sampling was active;
- `temperature`: numeric temperature from 0 through 2;
- `top_p`: value greater than 0 and at most 1;
- `top_k`: positive integer when the backend exposes/uses top-k, otherwise null;
- `max_output_tokens`: must equal the named profile output-token budget;
- `seed_supported`: whether the backend supports an explicit deterministic seed;
- `seed`: non-negative integer when supported, otherwise null;
- `applied_config_path`: repository-relative path to canonical JSON containing the exact backend decoding settings actually applied;
- `applied_config_sha256`: SHA-256 of that JSON artifact.

The explicit comparable fields are intentionally not the whole universe of backend knobs. `applied_config_path` and its digest bind any additional backend-specific generation settings so that a run cannot silently change them while preserving the same high-level manifest fields.

For the Qwen3 0.6B adapter pinned by `docs/model-research/QWEN3_0_6B_BASELINE_ADAPTER_V0.md`, the upstream pinned generation configuration at revision `c1899de289a04d12100db370d81485cdf75e47ca` contains sampling enabled with temperature 0.6, top-k 20 and top-p 0.95. A future untouched Qwen run must record the settings it actually applies; it must not rely on an implicit library default.

A seed is required only when the backend supports deterministic seeding. Otherwise `seed` is null.

### Execution evidence

`execution.evidence_class` is one of:

- `host`;
- `simulator`;
- `physical_device`.

Host and simulator records must set `physical_device_run` to false and keep device fields null. Physical-device evidence requires `physical_device_run: true`, an exact device model and exact OS build.

The separate `claims.physical_device_readiness_claimed` flag prevents host or simulator results from becoming a physical-device readiness claim.

### Output artifacts and observations

`artifacts` binds repository-relative paths and SHA-256 digests for:

- normalized proposal JSONL;
- evaluator result JSON.

The proposal and evaluator paths and digests must differ.

`observations` records repetition, truncation, timeout and cancellation as explicit booleans plus one termination reason: `completed`, `timeout`, `cancelled` or `error`.

### Untouched-baseline boundary

`specialization` must state:

- `training_performed: false`;
- `fine_tuning_performed: false`;
- `model_adapter_applied: false`;
- null model-adapter ID and revision.

Any training, fine-tuning or trained-model-adapter claim invalidates the untouched-baseline manifest. A later specialized run requires a separately versioned contract and must retain the untouched baseline as prior evidence.

## Fail-closed validation

The validator rejects:

- invalid UTF-8, invalid JSON, duplicate JSON keys or a non-object root;
- missing or unexpected fields at every schema level;
- invalid paths, hashes, revisions, dates, limits, enums or seed combinations;
- a `Router-small` or `Router-normal` manifest whose profile budget differs from canonical V0;
- a rendered/tokenized benchmark input maximum above the selected profile input budget;
- a missing or invalid per-case token-count evidence path/hash;
- invalid sampling state or non-positive non-null top-k;
- a missing or invalid applied-decoding-config path/hash;
- a decoding maximum that differs from the profile output limit;
- a context limit smaller than the configured input plus output budget;
- incompatible Apple-system and custom-model identities;
- training, fine-tuning or trained-model-adapter claims;
- credential, secret, private-prompt, user-content or device-identifier fields;
- obvious embedded secret patterns;
- physical-device claims without physical-device evidence;
- inconsistent timeout, cancellation or completion observations.

Validation proves schema and provenance consistency only. It does not prove that referenced artifacts exist, that their hashes match files on disk, that a model was executed, that a license interpretation is correct or that a physical device produced the result. Those claims require reviewed run evidence.

## Continuous validation

Repo Audit executes `scripts/validate_baseline_run.py` and `scripts/test_validate_baseline_run.py`. The regression suite mutation-tests both named V0 profiles, rendered-input budget boundaries, decoding/sampling evidence, artifact path/hash rules, larger backend context capacity, and the existing license/training/device fail-closed rules.

A future benchmark version must not silently reuse these profile names with different budgets. Introduce a versioned contract or explicit migration when the experiment profile changes.

## Synthetic example

`docs/model-research/baseline-run-manifest-v0.example.json` contains synthetic placeholders only. Repeated hexadecimal characters are deliberately non-evidence examples, not hashes of repository files or model artifacts. The example uses the canonical Router-small 512-input / 32-output budget while making no product, model, benchmark or device-performance claim.

## Safety boundary

No credentials, private prompts, real user content, device identifiers, weights, trained adapters or provider data belong in this manifest. Models remain proposal-only. `PolicyEngine`, `ApprovalManager`, schema enforcement, audit and execution authorization remain deterministic product responsibilities.
