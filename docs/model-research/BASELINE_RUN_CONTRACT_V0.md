# iGentic Untouched Baseline Run Contract V0

Status: executable provenance contract  
Schema: `igentic-baseline-run-v0`  
Parent: Issue #88

## Purpose

This contract binds every untouched backend baseline to the exact benchmark, evaluator, backend, input, normalizer, execution environment, normalized proposals and evaluator result used for that run. It is the evidence boundary between the backend-neutral evaluator and any later specialization or training decision.

The package records evidence only. It does not download or run a model, execute a tool, authorize an action, add a runtime provider or establish physical iPhone Air readiness.

## Files and command

Validate the synthetic example:

```bash
python3 scripts/validate_baseline_run.py \
  docs/model-research/baseline-run-manifest-v0.example.json
```

The validator uses only the Python standard library, performs no network access and never rewrites the manifest.

## Exact manifest sections

The root object uses the fixed schema version `igentic-baseline-run-v0` and contains no optional fields.

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

### Input and normalizer identity

`input` binds:

- tokenizer ID and revision;
- prompt or chat-template ID and SHA-256;
- SHA-256 of the normalized evaluator input.

For a custom model, the tokenizer revision must be immutable. For a system-managed Apple tokenizer, the revision starts with `system:` and binds the exact system/framework version.

`normalizer` binds the adapter that converts backend output into the normalized proposal JSONL schema. Its revision is an immutable 40- or 64-character hexadecimal revision. This normalizer is not a trained model adapter.

### Router profile and decoding

`profile.name` is `Router-small` or `Router-normal` and records context, input and output token limits. The input plus output limit cannot exceed the context limit.

`decoding` records temperature, top-p, maximum output tokens and deterministic seed behavior. A seed is required only when the backend supports it; otherwise the seed is null.

### Execution evidence

`execution.evidence_class` is one of:

- `host`;
- `simulator`;
- `physical_device`.

Host and simulator records must set `physical_device_run` to false and keep device fields null. Physical-device evidence requires `physical_device_run: true`, an exact device model and exact OS build.

The separate `claims.physical_device_readiness_claimed` flag prevents host or simulator results from becoming a physical-device readiness claim.

### Artifacts and observations

`artifacts` binds repository-relative paths and SHA-256 digests for:

- normalized proposal JSONL;
- evaluator result JSON.

The paths and digests must differ.

`observations` records repetition, truncation, timeout and cancellation as explicit booleans plus one termination reason: `completed`, `timeout`, `cancelled` or `error`.

### Untouched-baseline boundary

`specialization` must state:

- `training_performed: false`;
- `fine_tuning_performed: false`;
- `model_adapter_applied: false`;
- null model-adapter ID and revision.

Any training, fine-tuning or model-adapter claim invalidates the untouched-baseline manifest. A later specialized run requires a separately versioned contract and must retain the untouched baseline as prior evidence.

## Fail-closed validation

The validator rejects:

- invalid UTF-8, invalid JSON, duplicate JSON keys or a non-object root;
- missing or unexpected fields at every schema level;
- invalid paths, hashes, revisions, dates, limits, enums or seed combinations;
- incompatible Apple-system and custom-model identities;
- training, fine-tuning or model-adapter claims;
- credential, secret, private-prompt, user-content or device-identifier fields;
- obvious embedded secret patterns;
- physical-device claims without physical-device evidence;
- inconsistent timeout, cancellation or completion observations.

Validation proves schema and provenance consistency only. It does not prove that an artifact exists, that a model was executed, that a license interpretation is correct or that a physical device produced the result.

## Synthetic example

`baseline-run-manifest-v0.example.json` contains synthetic placeholders only. Repeated hexadecimal digits are deliberately non-evidence examples, not hashes of repository files or model artifacts. The example validates the schema while making no product, model, benchmark or device-performance claim.

## Safety boundary

No credentials, private prompts, real user content, device identifiers, weights, trained adapters or provider data belong in this manifest. Models remain proposal-only. `PolicyEngine`, `ApprovalManager`, schema enforcement, audit and execution authorization remain deterministic product responsibilities.