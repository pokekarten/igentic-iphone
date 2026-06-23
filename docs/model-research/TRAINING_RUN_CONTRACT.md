# Training Run Contract

This document defines the minimum manifest and review contract for reproducible model specialization experiments. It is provider-independent: Kaggle, Colab, local machines or other executors may run the same contract, but no provider is a required dependency.

The contract records planning and review requirements only. It does not authorize training, model downloads, gated artifact access, dependency additions, credentials, weights, adapters, checkpoints or iPhone readiness claims.

## Candidate order

FunctionGemma 270M is the default first specialization candidate because the first pass should minimize model size and runtime risk.

Qwen3 0.6B may be considered only after untouched baseline comparison evidence exists. It must not be trained first, used to tune benchmark expectations or substituted without a manifest note explaining the comparison evidence.

## Required run identity

Every run must have a stable manifest that records:

- `run_id`;
- `schema_version`;
- run owner or automation lane;
- creation time and optional resume time;
- linked issue or PR;
- run objective;
- explicit stop rules;
- decision status: `PLANNED`, `KEEP`, `REWORK` or `REJECT`.

The decision must include a reason. `KEEP` is allowed only when baseline, post-training and safety evidence support it. `REWORK` requires the next bounded change. `REJECT` requires the failure reason and any cleanup requirement.

## Model and license fields

Every run must record the immutable model identity:

- model family;
- model ID;
- exact revision, commit or release tag;
- source registry;
- license reference;
- gate status;
- local cache or artifact reference without credentials.

A manifest must not store access tokens, account identifiers, private URLs or gated artifact contents.

## Dataset fields

Every run must record:

- training dataset IDs, revisions and hashes;
- validation dataset IDs, revisions and hashes;
- immutable test-set ID and revision;
- dataset governance document revision;
- benchmark contamination review status;
- rejected-record exclusion confirmation.

The immutable test set is used only for untouched evaluation. If a training or validation dataset is found to derive from the test set, the run is rejected.

## Template and tokenizer fields

Every run must record:

- tokenizer revision;
- chat template revision;
- tool-call or function-call template revision when applicable;
- prompt formatting rules;
- maximum context length;
- output limit;
- truncation policy.

Template changes are material changes. They require a new run manifest or a new manifest revision.

## Environment and dependency lock

Every run must record:

- executor type such as Kaggle, Colab, local or CI-like runner;
- hardware class when known, without claiming future device readiness;
- operating system image or container reference;
- Python and package versions;
- dependency lock or environment export path;
- random seed;
- deterministic flags when available.

Provider-specific paths are implementation details. A run must be resumable from manifest fields and safe artifact references rather than from one provider account.

## Training parameters

Every run must record:

- batch size;
- gradient accumulation;
- learning rate and schedule;
- epoch or step budget;
- sequence length;
- optimizer;
- precision;
- quantization mode;
- LoRA target modules;
- LoRA rank;
- LoRA alpha;
- LoRA dropout;
- checkpoint cadence;
- resume checkpoint reference without credentials.

Changing any of these fields creates a new manifest revision.

## Metrics and comparison

Every run must record untouched baseline metrics before training and post-training metrics after training. Metrics must include the immutable test-set ID and the evaluator contract revision.

A run must not claim improvement when:

- the baseline was not captured before training;
- the test set was used for tuning;
- the evaluator or template changed between baseline and post-training without a separate comparison;
- the manifest lacks dataset hashes;
- benchmark contamination review is unresolved.

## Export and runtime compatibility

Every run must record planned and actual export targets, if any:

- adapter format;
- quantized export format;
- runtime compatibility status;
- known unsupported runtimes;
- artifact locations without credentials.

Runtime compatibility status may be `not_tested`, `planned`, `compatible`, `incompatible` or `blocked`. Do not claim iPhone Air readiness, physical-device success or production readiness without separate source-backed evidence.

## Provider independence

The provider executes the run; it is not the source of truth. Kaggle, Colab or other free credits must be interchangeable. A manifest is invalid when it depends on provider-only hidden state, private notebook output, uncommitted credentials or account-local paths.

A resumable run must include enough public-safe configuration to recreate the environment and enough private-safe references to resume artifacts without exposing secrets.

## Review gates

Before starting any run, verify:

- dataset governance readiness;
- immutable benchmark isolation;
- model license and gate status;
- allowed executor and dependency scope;
- no credentials in manifests or notebooks;
- no weights, adapters or checkpoints committed to the repository.

After a run, record:

- baseline metrics;
- post-training metrics;
- safety or regression notes;
- export status;
- `KEEP`, `REWORK` or `REJECT` decision and reason.

This contract is documentation. It does not claim that any training run, free-compute session, export, adapter or model artifact exists.
