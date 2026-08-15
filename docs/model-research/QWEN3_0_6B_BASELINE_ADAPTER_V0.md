# Qwen3 0.6B Benchmark V0 Adapter

Status: executable adapter contract, no model runtime  
Parent: Issue #278  
Benchmark: `docs/model-research/igentic-action-benchmark-v0.jsonl`  
Evaluator: `docs/model-research/EVALUATOR_CONTRACT_V0.md`

## Purpose

This contract defines the reproducible boundary between immutable iGentic Benchmark V0 and an external untouched `Qwen/Qwen3-0.6B` baseline runner.

The repository owns request-envelope construction and output normalization only. It does not download, load, execute, quantize, convert or fine-tune Qwen3. A later runner may use the pinned upstream tokenizer/chat template, but model/runtime dependencies remain outside this dependency-free adapter.

The model may propose. Deterministic Swift policy, approval, schema validation, audit and execution remain authoritative.

## Pinned upstream identity

For this V0 adapter contract:

```text
MODEL_ID: Qwen/Qwen3-0.6B
MODEL_REVISION: c1899de289a04d12100db370d81485cdf75e47ca
TOKENIZER_ID: Qwen/Qwen3-0.6B
TOKENIZER_REVISION: c1899de289a04d12100db370d81485cdf75e47ca
LICENSE: Apache-2.0 at the pinned repository revision
CHAT_TEMPLATE_SOURCE: tokenizer_config.json at the pinned repository revision
THINKING_MODE: disabled
```

Primary sources checked on 2026-08-15:

- `https://huggingface.co/Qwen/Qwen3-0.6B/tree/c1899de289a04d12100db370d81485cdf75e47ca`
- `https://huggingface.co/Qwen/Qwen3-0.6B/blob/c1899de289a04d12100db370d81485cdf75e47ca/README.md`
- `https://huggingface.co/Qwen/Qwen3-0.6B/blob/c1899de289a04d12100db370d81485cdf75e47ca/tokenizer_config.json`
- `https://huggingface.co/docs/transformers/main/chat_template_tools_and_documents`

Do not silently advance this revision. A later revision requires a new reviewed contract update and new provenance.

## Dependency-free CLI

Generate request envelopes:

```bash
python3 scripts/qwen3_baseline_adapter.py requests \
  --output artifacts/qwen3-v0-requests.jsonl
```

Normalize raw assistant text:

```bash
python3 scripts/qwen3_baseline_adapter.py normalize \
  --input artifacts/qwen3-v0-raw.jsonl \
  --output artifacts/qwen3-v0-normalized.jsonl
```

These commands perform no network access and import no model framework.

## Request envelope

The adapter first validates canonical Benchmark V0 with the existing benchmark validator. It then emits one record per canonical `case_id`.

Each record contains:

- transport `case_id`;
- exact model and tokenizer identity/revision;
- one fixed system message;
- the benchmark `user_text` as the only benchmark-derived model-visible content;
- one non-executable function schema named `igentic_propose_action`;
- `add_generation_prompt=true`;
- `enable_thinking=false`.

The request must not contain benchmark answers or labels such as `expected_*`, `category`, `required_arguments`, `immutable_test` or expected reason codes. `case_id` is transport metadata and is not part of the model message content.

## Proposal-only tool schema

`igentic_propose_action` exposes exactly the backend-neutral proposal fields:

```text
proposalType
intent
tool
arguments
missingArguments
reasonCode
```

It exposes no policy level, approval result, data-classification decision, execution authorization or side-effect API. The function is a synthetic structured-output envelope, not an executable iPhone tool.

## External runner contract

A later external runner is responsible for:

1. loading the exact pinned model/tokenizer revision;
2. passing the emitted `messages` and `tools` through the pinned upstream chat template;
3. preserving `enable_thinking=false`;
4. applying the selected V0 Router profile limits from `docs/model-research/BASELINE_RUN_CONTRACT_V0.md`;
5. recording only generated assistant text as `assistant_text` plus transport-owned runtime observations;
6. stopping/decoding so the model-generated span can be checked exactly by this normalizer;
7. recording all runtime, dependency and artifact provenance in the baseline-run manifest.

The adapter does not strip arbitrary model prose, code fences, repeated blocks or backend control tokens. Such output must remain failure evidence rather than being repaired into a better answer.

## Raw output record

The normalizer accepts these transport-owned fields only:

```json
{
  "case_id": "de-create-reminder-001",
  "assistant_text": "<tool_call>{...}</tool_call>",
  "repetitionDetected": false,
  "truncationDetected": false
}
```

`repetitionDetected` and `truncationDetected` are optional. They are runtime observations, never trusted from model-generated function arguments.

Missing, blank or duplicate transport `case_id` values fail the normalization command because a stable benchmark join is impossible.

## Accepted native envelope

After trimming outer whitespace, valid backend output contains exactly one native envelope:

```text
<tool_call>
{"name":"igentic_propose_action","arguments":{...}}
</tool_call>
```

The JSON payload must:

- be an object;
- contain exactly `name` and `arguments`;
- use `name="igentic_propose_action"`;
- use an object-valued `arguments`.

The normalizer copies `arguments` into the evaluator-facing record without semantic repair. Proposal field types, allowed values, tool/intent consistency and unexpected semantic fields remain the evaluator's responsibility.

## Fail-safe normalization

Joinable malformed backend output becomes failure evidence with the original transport identity, for example:

```json
{
  "case_id": "de-create-reminder-001",
  "normalizerError": "expected_exactly_one_tool_call"
}
```

This record intentionally violates the normalized proposal schema. The V0 evaluator therefore retains it as a schema-invalid measured failure and, after Issue #276 / PR #277, awards no positive semantic correctness credit.

Joinable failure cases include:

- missing or repeated `<tool_call>` envelopes;
- prose or code fences outside the envelope;
- nested tool-call tags;
- malformed tool-call JSON;
- wrong native function name;
- non-object native arguments;
- model attempts to control `case_id`, `normalizerError`, `repetitionDetected` or `truncationDetected`;
- unexpected transport fields.

The normalizer does not invent missing proposal fields, coerce types, infer intent, repair arguments or select a tool on the model's behalf.

## Validation

Required exact-head checks:

```bash
python3 scripts/test_qwen3_baseline_adapter.py
python3 scripts/validate_action_benchmark.py
python3 scripts/test_evaluate_action_proposals.py
python3 scripts/validate_repo_structure.py
```

Repository PR gates also include Repo Audit, PR Change Scope, Pull Request Quality, Docs Consistency and Workflow Lint for the audit wiring.

Swift source is unchanged by this contract. Repository-triggered Swift/Phase 0 runs are supporting evidence, not evidence that Qwen3 executes on an iPhone.

## Safety boundary

This contract authorizes none of the following:

- model downloads or model execution inside this repository;
- Transformers, llama.cpp, ExecuTorch, Core ML or other runtime dependencies;
- weights, adapters, credentials or provider calls;
- networking in the adapter;
- real messages, contacts, files, device identifiers or other private user data;
- tool execution;
- moving policy, approval, audit or execution authority into model output;
- iPhone Air latency, memory, battery, thermal or readiness claims.

Physical-device claims require the separate iPhone Air evidence protocol and an exact artifact/runtime/configuration record.
