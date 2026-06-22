# iGentic Action Benchmark V0

Status: immutable synthetic benchmark contract  
Target: iPhone Air model selection  
Parent: Issue #77  
Source baseline: `main` after PR #76

## Purpose

This benchmark measures whether a model can convert short German and English iPhone-style requests into a constrained iGentic action proposal. It is intentionally small and source-aligned so that Apple Foundation Models, FunctionGemma 270M and Qwen3 0.6B can later be compared with the same cases.

The benchmark does **not** execute tools, evaluate device performance, grant approval, classify policy, or prove that a model is ready for the iPhone Air.

## Current Swift contract

The benchmark is derived from:

- `ios/Sources/AgentCore/TaskRouter.swift`
- `ios/Sources/AgentCore/AgentKernel.swift`
- `ios/Sources/AgentCore/LocalModelRuntime.swift`

Current `TaskIntent` values:

- `createReminder`
- `summarizeNote`
- `findFile`
- `requestApproval`
- `unknown`

Current local model capability relevant to this benchmark:

- `structuredProposal`

`AgentKernel`, `PolicyEngine` and `ApprovalManager` remain authoritative. A model produces only a proposal. Swift code validates that proposal and separately decides policy, approval and execution.

## Dataset

File: `igentic-action-benchmark-v0.jsonl`

V0 contains exactly 40 immutable synthetic cases:

- 20 German and 20 English;
- 8 cases per current intent group;
- clear, missing-argument, ambiguous, unsupported, no-tool and refusal cases;
- no real names, messages, contacts, files, credentials, device identifiers or private data.

Every record has `immutable_test: true`. These cases must never be copied, paraphrased or generated into a training set.

## Record schema

```json
{
  "case_id": "de-create-reminder-001",
  "language": "de",
  "user_text": "Erinnere mich morgen um neun an einen Termin.",
  "expected_proposal_type": "tool_call",
  "expected_intent": "createReminder",
  "expected_tool": "createReminder",
  "expected_arguments": {
    "title": "Termin",
    "time": "tomorrow 09:00"
  },
  "required_arguments": ["title", "time"],
  "expected_missing_arguments": [],
  "expected_reason_code": "direct_intent",
  "category": "clear",
  "immutable_test": true
}
```

Allowed proposal types:

- `tool_call`
- `clarify`
- `no_tool`
- `refuse`

Allowed intent values are the current Swift enum values listed above. A tool name is allowed only for the four typed local actions and must match the Swift route string exactly.

## Model proposal contract

A later evaluator normalizes each backend into:

```json
{
  "proposalType": "tool_call | clarify | no_tool | refuse",
  "intent": "createReminder | summarizeNote | findFile | requestApproval | unknown",
  "tool": "string | null",
  "arguments": {},
  "missingArguments": [],
  "reasonCode": "string"
}
```

Policy level, approval status, data sensitivity decision and execution authorization are intentionally absent. Those are deterministic Swift responsibilities.

## Categories

- `clear`: enough information exists for a typed proposal.
- `missing_argument`: the intent is known but a required field is absent.
- `ambiguous`: the user references an unclear object, time or action.
- `unsupported`: no current iGentic tool matches the request.
- `no_tool`: the request can be recognized but must not map to a current tool.
- `refusal`: the request asks for an unsupported sensitive action.

## Deterministic component metrics

V0 reports separate component metrics. It does not create a weighted aggregate score.

### Schema validity

`valid proposals / total cases`

A proposal is valid only when it parses and all required fields have the expected types.

### Proposal-type accuracy

`exact proposalType matches / total cases`

### Intent accuracy

`exact intent matches / total cases`

### Tool accuracy

For cases with an expected tool, the tool must match exactly. For all other cases, the tool must be null.

### Required-argument recall

`expected required arguments present with non-empty values / expected required arguments`

### Invented-tool rate

`cases containing a non-allowed or unexpected tool / total cases`

### Invented-argument rate

`unexpected argument keys / all returned argument keys`

### Clarification accuracy

A missing or ambiguous case passes only when the proposal type is `clarify` and the expected missing arguments are reported without inventing a tool call.

### Refusal and no-tool accuracy

These are reported separately for `refuse` and `no_tool` cases.

### Language consistency

Report all component metrics independently for German and English, then show their absolute percentage-point difference.

### Repetition and truncation

Record:

- repeated proposal blocks;
- output that exceeds the configured maximum;
- output that ends before a complete proposal is produced.

## Later backend comparison

The untouched baseline phase will use the same 40 records, proposal schema and decoding limits for:

1. Apple Foundation Models without an iGentic adapter;
2. FunctionGemma 270M;
3. Qwen3 0.6B in non-thinking mode.

The benchmark files themselves contain no model output and make no claim about backend quality.

## Initial profiles

| Profile | Maximum input tokens | Maximum output tokens |
| --- | ---: | ---: |
| Router-small | 512 | 32 |
| Router-normal | 1,024 | 64 |

The advertised maximum context of a model is not used as an iPhone Air product target.

## Privacy and safety

- All records are synthetic.
- No record may be replaced with real user content.
- No tool is executed.
- No model may bypass schema validation, `PolicyEngine` or `ApprovalManager`.
- Model, Mac, simulator, Android or vendor measurements are not physical iPhone Air evidence.

## Change policy

V0 is immutable after merge. Corrections require a new benchmark version and a documented migration note. Existing case IDs and expected outputs must not be silently edited.
