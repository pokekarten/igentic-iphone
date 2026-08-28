# Apple Foundation Models Benchmark V0 Host Runner

Status: executable host-runner contract; no benchmark result  
Parent: #318 and #74  
Predecessor: #316 / PR #317

## Purpose

This contract defines the first untouched Apple `SystemLanguageModel.default` execution path for iGentic Benchmark V0.

The runner produces **host evidence only**. It does not prove physical iPhone Air execution, readiness, latency, memory, battery or thermal behavior. It does not authorize an action and never executes an iGentic tool.

## Safety and comparison boundary

The runner:

- reads only the synthetic public Benchmark V0;
- decodes only `case_id`, `language` and `user_text` from benchmark records;
- never decodes benchmark expected answers into the model runner;
- creates a fresh single-turn `LanguageModelSession` per case;
- passes zero tools to the session;
- uses guided generation only to produce one typed proposal;
- normalizes the typed proposal mechanically without repairing intent, tool, arguments, missing arguments or reason code;
- uses deterministic greedy sampling and no seed;
- never truncates benchmark text, instructions or schema to fit a profile;
- writes no evaluator score or baseline manifest in this slice.

`PolicyEngine`, `ApprovalManager`, schema validation, audit and execution remain outside the model and remain deterministic product authority.

## Fixed Benchmark V0 profiles

| Profile | Maximum model-visible input | Maximum response |
| --- | ---: | ---: |
| `Router-small` | 512 tokens | 32 tokens |
| `Router-normal` | 1,024 tokens | 64 tokens |

These names and budgets are inherited from `docs/model-research/BASELINE_RUN_CONTRACT_V0.md`. A larger Apple system context does not change the experiment budget.

## Model-visible proposal schema

The guided-generation schema is intentionally finite.

Proposal types:

- `tool_call`
- `clarify`
- `no_tool`
- `refuse`

Intents:

- `createReminder`
- `summarizeNote`
- `findFile`
- `requestApproval`
- `unknown`

Tool values are limited to the four current typed local routes and may be null.

Argument names are limited to the existing Benchmark V0 universe:

- `title`
- `time`
- `date`
- `note_text`
- `note_reference`
- `query`
- `file_type`
- `date_hint`
- `action_summary`

Reason codes are likewise limited to the existing Benchmark V0 values. This prevents arbitrary schema expansion but does **not** make a proposal semantically correct. A model can still return the wrong allowed tool, an irrelevant allowed argument, duplicate missing-argument entries or a wrong reason code. The normalizer preserves those failures for the evaluator.

## Target-leakage prevention

`AppleBenchmarkCase` contains only:

```text
case_id
language
user_text
```

Swift's `JSONDecoder` ignores the remaining benchmark fields. Expected proposal type, intent, tool, argument values, missing arguments and reason code are therefore never loaded into the runner's case object and cannot be interpolated into its instructions or prompt.

The fixed runner instructions describe only the public routing task and supported route vocabulary. They contain no case-specific expected answer.

## Native token-budget gate

Apple documents that instructions, prompts, tools and guided-generation schemas consume the model context. The runner therefore measures the native token cost of:

1. the fixed instructions;
2. the current case prompt;
3. the exact `FMGeneratedProposal.generationSchema`.

There are no tools.

The sum is a **pre-inference gate**. If it exceeds the selected V0 input budget, the run stops before creating a result for that case. It never shortens or rewrites an input.

After a successful guided response, the runner also records `response.usage.input.totalTokenCount`. This is a second fail-closed check against the same profile budget. A mismatch that crosses the budget invalidates the run rather than being hidden.

Output token count is derived exactly as:

```text
response.usage.totalTokenCount - response.usage.input.totalTokenCount
```

Apple defines total usage as input plus output. A negative result is rejected as invalid usage.

The runner records `SystemLanguageModel.contextSize` as the actual system-model context capacity. It never substitutes the historical 4,096-token value or the V0 profile budget for this observation.

## System-model identity

Apple updates the system language model with OS releases. iGentic therefore does not invent a custom-model revision for this backend.

The runner records:

- `SystemLanguageModel.default.variant.displayName`;
- exact host OS version/build string;
- architecture;
- the active Swift toolchain string;
- framework class `Apple Foundation Models`;
- backend class `apple_system`.

A later packager will bind these values into the existing Apple-system branch of `igentic-baseline-run-v0`.

## Generation settings

One canonical JSON artifact records:

```text
sampling_mode=greedy
sampling_enabled=false
temperature=0.0
top_p=1.0
top_k=null
maximum_response_tokens=32 or 64
seed_supported=false
seed=null
include_schema_in_prompt=true
tools_count=0
```

`greedy` is the no-seed deterministic comparison mode. The maximum response token value always equals the selected V0 profile output budget.

## Output directory contract

The caller must provide an existing empty real directory. A missing path, ordinary file, symlink or non-empty directory is rejected before model execution.

A completed profile writes exactly these research evidence files:

```text
raw-proposals.jsonl
normalized-proposals.jsonl
token-counts.json
applied-generation-config.json
run-metadata.json
```

Evidence bytes are constructed before writing. Files use fixed names and no-overwrite writes. If a write fails, files created by that write phase are removed.

No model cache, credentials, host identifiers, private data, screenshot or unrelated machine file belongs in this directory.

## External host command

Run from a clean checkout of the intended iGentic revision on an eligible Mac with Apple Intelligence and a current Foundation Models SDK/runtime:

```bash
set -euo pipefail
OUT="$HOME/igentic-apple-v0/Router-small"
mkdir -p "$OUT"
test -z "$(ls -A "$OUT")"

swift run --package-path ios AppleFoundationBaselineHost \
  --benchmark docs/model-research/igentic-action-benchmark-v0.jsonl \
  --profile Router-small \
  --output-dir "$OUT"
```

Only after the complete Router-small output set is preserved should a separate empty directory be used for `Router-normal`:

```bash
OUT="$HOME/igentic-apple-v0/Router-normal"
mkdir -p "$OUT"
test -z "$(ls -A "$OUT")"

swift run --package-path ios AppleFoundationBaselineHost \
  --benchmark docs/model-research/igentic-action-benchmark-v0.jsonl \
  --profile Router-normal \
  --output-dir "$OUT"
```

Do not rerun only weak cases, alter the fixed instructions after seeing results, or edit normalized output before evaluation.

## CI compile evidence

Phase 0 keeps the existing compatibility paths:

- default-toolchain macOS package build/test;
- Linux package build/test;
- the Xcode 26.3 `AgentCore` Foundation Models availability compile introduced by #317.

The newer token/context/response-usage evidence APIs require a later stable Foundation Models SDK. Phase 0 therefore also has a narrow `macos-latest` job. GitHub currently maps that label to its macOS 26 image; the job prints the exact Xcode and Swift versions before compiling `ModelResearchSupport` and `AppleFoundationBaselineHost` with the image's current stable Xcode 26 toolchain.

That job **compiles but does not execute the model**. GitHub-hosted hardware is not physical iPhone evidence and is not assumed to have Apple Intelligence available.

## What this slice proves

A green exact-head CI run proves:

- ordinary iGentic package compatibility remains intact;
- the research support code compiles on Linux through its unsupported-platform path;
- the real current Foundation Models runner branch compiles with a current stable Apple SDK;
- pure contract tests pass without model availability.

It does not prove that the system model executed or produced any quality result.

## Follow-up

After one external host profile completes, a separate standard-library evidence packager should:

1. validate the five runner artifacts;
2. run `scripts/evaluate_action_proposals.py` on the normalized JSONL;
3. hash benchmark, evaluator, runner contract and artifacts;
4. emit a valid `igentic-baseline-run-v0` Apple-system manifest;
5. keep `evidence_class=host` and `physical_device_readiness_claimed=false`.

Actual physical iPhone Air evidence remains a later, separate protocol.

## Primary Apple sources

- Foundation Models framework: https://developer.apple.com/documentation/foundationmodels
- SystemLanguageModel: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
- LanguageModelSession: https://developer.apple.com/documentation/foundationmodels/languagemodelsession
- Managing the context window: https://developer.apple.com/documentation/foundationmodels/managing-the-context-window
- Foundation Models updates: https://developer.apple.com/documentation/updates/foundationmodels
