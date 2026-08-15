# iGentic Evaluator Contract V0

Status: executable benchmark and comparison contract  
Benchmark: `igentic-action-benchmark-v0.jsonl`  
Parent: Issue #81  
Fail-safe metric follow-up: Issue #276

## Purpose

This contract turns the immutable 40-case action-routing benchmark into a deterministic, backend-neutral evaluation step. It validates benchmark integrity and compares normalized proposals without downloading a model, executing a tool, using the network or changing Swift authority.

The evaluator measures proposal quality only. `PolicyEngine`, `ApprovalManager`, schema enforcement, audit and execution authorization remain deterministic product responsibilities.

## Files and commands

Validate the canonical benchmark:

```bash
python3 scripts/validate_action_benchmark.py \
  docs/model-research/igentic-action-benchmark-v0.jsonl
```

Evaluate one normalized backend output:

```bash
python3 scripts/evaluate_action_proposals.py \
  docs/model-research/igentic-action-benchmark-v0.jsonl \
  path/to/normalized-proposals.jsonl \
  --output path/to/result.json
```

Run the focused evaluator regression suite:

```bash
python3 scripts/test_evaluate_action_proposals.py
```

All scripts use only the Python standard library and perform no network access.

## Benchmark validation

The validator fails with exit code `1` when the JSONL cannot be decoded as UTF-8, contains invalid JSON or blank lines, or violates the V0 contract. It enforces:

- exactly 40 records;
- unique non-empty `case_id` values;
- exactly 20 German / 20 English records;
- exactly eight records for each current intent;
- the fixed field set and expected value types;
- allowed proposal types, intents, tools and categories;
- `immutable_test: true`;
- null tools for non-tool proposals;
- exact typed route names for tool calls;
- unique string argument lists;
- missing arguments as a subset of required arguments;
- every required argument has exactly one expected state: a non-empty value or expected missing;
- non-empty user text, reason codes, argument keys and expected values;
- category-to-proposal-type consistency.

The canonical benchmark is an immutable test set. The validator must never rewrite it.

## Normalized proposal JSONL

Each backend adapter emits exactly one JSON object for every benchmark `case_id`:

```json
{
  "case_id": "de-create-reminder-001",
  "proposalType": "tool_call",
  "intent": "createReminder",
  "tool": "createReminder",
  "arguments": {
    "title": "Termin",
    "time": "tomorrow 09:00"
  },
  "missingArguments": [],
  "reasonCode": "direct_intent",
  "repetitionDetected": false,
  "truncationDetected": false
}
```

Required fields:

| Field | Type | Rule |
| --- | --- | --- |
| `case_id` | string | unique and present in the benchmark |
| `proposalType` | string | `tool_call`, `clarify`, `no_tool` or `refuse` |
| `intent` | string | current `TaskIntent` raw value |
| `tool` | string or null | typed route for `tool_call`; null otherwise |
| `arguments` | object | normalized known argument values |
| `missingArguments` | array of strings | unique unresolved argument names |
| `reasonCode` | string | non-empty backend-neutral reason code |

Optional fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `repetitionDetected` | boolean | repeated proposal block or loop was observed |
| `truncationDetected` | boolean | output ended before a complete proposal |

No policy level, approval decision, data classification, execution result, user identifier or private prompt belongs in this schema.

## Failure behavior

The evaluator fails closed with exit code `1` for transport or identity failures:

- invalid UTF-8 or JSONL;
- blank or non-object records;
- missing, empty or duplicate `case_id`;
- proposal IDs missing from the benchmark;
- benchmark IDs missing from the proposal file;
- extra proposal IDs;
- an invalid canonical benchmark;
- an unwritable result path.

A joinable proposal with invalid normalized fields is retained as a measured failure. Its `schema_valid` value is `false` and its schema errors are reported.

Schema validity is the gate for **positive semantic correctness credit**. When `schema_valid` is false, the proposal receives zero/false credit for:

- proposal-type accuracy;
- intent accuracy;
- tool accuracy;
- required-argument recall hits;
- expected-argument-value hits/correctness;
- reason-code accuracy;
- exact missing-argument accuracy;
- clarification accuracy;
- refusal accuracy;
- no-tool accuracy;
- fully-correct case status.

This prevents missing or malformed fields from accidentally comparing equal to benchmark defaults. For example, an omitted `tool` field must not receive tool accuracy merely because the benchmark expected `null`.

Negative/error evidence remains independently observable when its raw field is structurally inspectable. In particular, an invalid proposal may still record an invented tool, invented argument keys/count, or valid boolean repetition/truncation observations. These observations do not restore any positive semantic correctness credit.

This distinction preserves a meaningful schema-validity metric and useful failure evidence while preventing malformed normalized output from inflating backend quality metrics.

## Metrics

V0 reports separate metrics and never computes a weighted aggregate.

Each metric contains:

```json
{
  "numerator": 39,
  "denominator": 40,
  "rate": 0.975
}
```

Reported metrics:

- `schema_validity`;
- `proposal_type_accuracy`;
- `intent_accuracy`;
- `tool_accuracy`;
- `required_argument_recall`;
- `expected_argument_value_accuracy`;
- `reason_code_accuracy`;
- `exact_missing_argument_accuracy`;
- `fully_correct_case_rate`;
- `invented_tool_rate`;
- `invented_argument_rate`;
- `clarification_accuracy`;
- `refusal_accuracy`;
- `no_tool_accuracy`;
- `repetition_flag_rate`;
- `truncation_flag_rate`.

Existing V0 metrics retain their documented meaning for schema-valid proposals. `required_argument_recall` remains a presence/non-empty recall metric for required fields that the benchmark does not mark as expected missing. Schema-invalid proposals contribute zero required-argument hits while retaining the benchmark-derived denominator.

`expected_argument_value_accuracy` is a micro-average over every key/value pair in benchmark `expected_arguments`. For a schema-valid proposal, a value counts as correct only when the key is returned and the normalized JSON value and JSON type exactly match the benchmark expectation. Missing or wrong values reduce this metric; extra keys remain measured separately by `invented_argument_rate`. Schema-invalid proposals contribute zero expected-value hits.

`reason_code_accuracy` requires a schema-valid proposal and an exact match between proposal `reasonCode` and benchmark `expected_reason_code`.

`exact_missing_argument_accuracy` evaluates every case, not only clarification cases. The proposal must be schema-valid and contain a unique string list whose set exactly matches `expected_missing_arguments`; malformed or otherwise schema-invalid proposals fail this metric.

`fully_correct_case_rate` counts a case only when its normalized schema is valid, proposal type, intent and tool are exact, every expected argument value is exact, no argument key is invented, the missing-argument set is exact and the reason code is exact. Optional repetition and truncation observations remain separate evidence and do not change this semantic correctness definition.

An invented tool is any non-null tool that differs from the benchmark expectation. An invented argument is a returned argument key absent from that case's `expected_arguments`. These negative observations may be recorded even when the overall proposal schema is invalid.

Clarification accuracy requires a schema-valid `clarify` proposal, a null tool and an exact set match for `expected_missing_arguments`. Refusal and no-tool accuracy likewise require schema validity, the exact proposal type and a null tool.

## Result JSON

The deterministic result contains:

```json
{
  "benchmark_version": "V0",
  "case_count": 40,
  "weighted_aggregate": null,
  "metrics": {},
  "metrics_by_language": {
    "de": {},
    "en": {}
  },
  "language_difference_percentage_points": {},
  "case_results": []
}
```

`case_results` follows benchmark order and records schema errors, exact-match booleans, argument counts, invented keys and supplied repetition or truncation flags. Semantic argument evidence is public-safe: it records expected-value hit/total counts and incorrect expected argument keys, never the expected or returned values themselves. Each case also records `reason_code_correct`, `missing_arguments_exact` and `fully_correct`.

The result has no timestamp so identical inputs produce byte-stable JSON when invoked with the same Python version.

A null metric rate means its denominator was zero. Language differences are absolute German-versus-English percentage-point differences and are null when either language rate is undefined.

## Backend comparison rules

Apple Foundation Models, FunctionGemma 270M and Qwen3 0.6B must be normalized into the same schema before comparison.

For every comparison:

1. use the identical immutable benchmark file;
2. use the same Router-small or Router-normal input/output limits;
3. record the exact backend, model or system revision outside the benchmark;
4. keep decoding and prompt-template settings fixed and reviewable;
5. run untouched baselines before any specialization;
6. retain every component metric separately;
7. treat schema failures, repetition and truncation as evidence rather than repairing outputs silently;
8. never infer physical iPhone Air readiness from these host-level results.

Backend output and result JSON are experiment artifacts, not source truth. Do not commit them as claimed product results until they are reviewed, public-safe and tied to an immutable run manifest.

## Safety boundary

These scripts do not import model libraries, call providers, execute tools, modify benchmark data or authorize actions. No weights, adapters, credentials, private prompts, real user content or device-performance claims belong in this V0 evaluator contract.
