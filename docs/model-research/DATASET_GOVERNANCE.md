# Dataset Governance

This document defines the governance rules for synthetic datasets used in model-research experiments. It protects the immutable benchmark from contamination and keeps training data reproducible, reviewable and safe to publish.

## Scope

This governance applies to records intended for training or validation experiments. It does not authorize model training, model downloads, benchmark edits, provider-specific notebooks, credentials, weights, adapters or checkpoints.

Initial specialization work must use synthetic training data only. Real private data, user data, secrets, credentials, production logs and non-redacted personal information are out of scope.

## Split ownership

Each dataset record belongs to exactly one split:

- `test`: immutable benchmark records used only for untouched evaluation;
- `validation`: records used for prompt, format and training-decision checks;
- `training`: synthetic records eligible for supervised fine-tuning or preference-style experiments.

Split ownership is assigned at record creation and recorded in metadata. A record must not be copied between splits. Near-duplicates across splits must be treated as contamination until reviewed and resolved.

## Immutable benchmark isolation

The test split is an immutable benchmark. It must not be used as a source, seed, prompt, paraphrase target or style guide for synthetic record generation.

Prohibited actions include:

- copying test cases into training or validation records;
- paraphrasing, translating or simplifying test cases for training;
- generating synthetic records from test prompts, expected answers or hidden rubrics;
- tuning prompts, adapters or checkpoints directly against test failures;
- editing benchmark records to improve a run result.

Any suspected benchmark leak blocks publication and training reuse until the affected records are rejected or re-split with source-backed review.

## Record metadata

Every dataset record must carry enough metadata to reproduce and audit it:

- stable `record_id` with a dataset-specific prefix;
- `schema_version`;
- `dataset_id` and `dataset_revision`;
- `split`;
- `language` such as `de` or `en`;
- `category` and optional subcategory;
- `source_type`, initially `synthetic` for training records;
- generator name and generator version;
- generation prompt or prompt template revision when safe to publish;
- reviewer status: `pending`, `accepted`, `rework` or `rejected`;
- reviewer note or rejection reason;
- license or publication status;
- content hash and normalized content hash;
- change-history entry for each material update.

Hashes must be computed over deterministic normalized content, not over transient timestamps or reviewer comments.

## Synthetic-only initial training data

Initial training records must be synthetic and created without using private data, production data, benchmark prompts or benchmark expected answers. Synthetic generation prompts must describe categories, constraints and formats without exposing benchmark records.

A synthetic record is rejected when it cannot be traced to a permitted generator and prompt-template revision.

## Duplicate and near-duplicate detection

Before a record becomes eligible for validation or training, compare it against:

- all records in the same candidate dataset;
- existing accepted training and validation records;
- the immutable benchmark test split.

Exact hash matches are rejected. Near-duplicates, close paraphrases, translations or answer-equivalent variants are held for review. A reviewer may accept only when the record is demonstrably independent from benchmark content and does not leak hidden evaluation structure.

## Language and category balance

Dataset revisions should track German and English coverage explicitly. Category balance should be measured by record count, accepted count and rejected count per category.

A dataset revision is not ready for training review when one language or category dominates because of accidental generator bias, unless the run manifest explains why that skew is intentional and safe.

## Public and private boundaries

Public dataset artifacts may contain only records that are synthetic, non-sensitive, license-compatible and approved for publication. Private review notes may reference internal review decisions but must not contain secrets, credentials, private user data or benchmark hidden answers.

Never commit:

- real private data;
- credentials or tokens;
- gated model artifacts;
- weights, adapters or checkpoints;
- unredacted personal data;
- unpublished benchmark answers;
- provider account details.

## Rejection rules

Reject a record when any of the following is true:

- it copies, paraphrases, translates or derives from benchmark test content;
- it includes private, sensitive or credential-like data;
- provenance, generator version, license status or reviewer status is missing;
- the language or category label is ambiguous;
- the content is unsafe for publication or training reuse;
- the normalized hash duplicates an existing record;
- near-duplicate review cannot prove independence;
- change history is missing for a material edit.

Rejected records may remain in a private audit queue only when their retention is safe and useful. They must not be used for validation, training or public examples.

## Dataset revision readiness

A dataset revision is eligible for a training-run proposal only when:

- every record has required metadata;
- accepted records are synthetic or otherwise explicitly permitted;
- duplicate and near-duplicate checks have been completed;
- benchmark isolation has no unresolved contamination finding;
- language and category balance are summarized;
- public/private boundaries are documented;
- rejected records are excluded from training and validation manifests.

This document records governance only. It does not claim any dataset has been generated, reviewed, trained on or published.
