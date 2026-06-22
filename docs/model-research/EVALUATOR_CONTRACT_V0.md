# iGentic Evaluator Contract V0

Status: executable benchmark and comparison contract  
Benchmark: `igentic-action-benchmark-v0.jsonl`  
Parent: Issue #81

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

Both scripts use only the Python standard library and perform no network access.

## Benchmark validation

The validator fails with exit code `1` when the JSONL cannot be decoded as UTF-8, contains invalid JSON or blank lines, or violates the V0 contract. It enforces:

- exactly 40 records;
- unique non-empty `case_id` values;
- exactly 20 German and 20 English records;
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

A joinable proposal with invalid normalized fields is retained as a measured failure. Its `schema_valid` value is `false`, its schema errors are reported, and exact-match metrics fail safely. This distinction preserves a meaningful schema-validity metric while preventing malformed files or mixed case sets from producing a comparison.

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
- `invented_tool_rate`;
- `invented_argument_rate`;
- `clarification_accuracy`;
- `refusal_accuracy`;
- `no_tool_accuracy`;
- `repetition_flag_rate`;
- `truncation_flag_rate`.

Required-argument recall includes only required fields that the benchmark does not mark as expected missing. An argument is recalled only when a non-empty value is returned.

An invented tool is any non-null tool that differs from the benchmark expectation. An invented argument is a returned argument key absent from that case's `expected_arguments`.

Clarification accuracy requires `clarify`, a null tool and an exact set match for `expected_missing_arguments`. Refusal and no-tool accuracy require the exact proposal type and a null tool.

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

`case_results` follows benchmark order and records schema errors, exact-match booleans, argument counts, invented keys and supplied repetition or truncation flags. The result has no timestamp so identical inputs produce byte-stable JSON when invoked with the same Python version.

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
