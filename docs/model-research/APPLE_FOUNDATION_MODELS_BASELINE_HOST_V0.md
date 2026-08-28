# Apple Foundation Models Benchmark V0 Host Runner

Status: executable host-runner and deterministic evidence-packager contract; no benchmark result  
Parents: #318, #320 and #74  
Predecessors: #316 / PR #317, #318 / PR #319, #322 / PR #323

## Purpose

This contract defines the first untouched Apple `SystemLanguageModel.default` execution and evidence-packaging path for iGentic Benchmark V0.

The runner produces **host evidence only**. It does not prove physical iPhone Air execution, readiness, latency, memory, battery or thermal behavior. It does not authorize an action and never executes an iGentic tool.

The deterministic packager is a separate standard-library Python step. It does not execute the Apple model. It validates the completed host evidence, proves the raw-to-normalized relationship, runs the existing backend-neutral evaluator and emits a provenance manifest.

## Stable API boundary

The runner intentionally targets the stable Foundation Models evidence surface available from macOS/iOS 26.4 onward:

- `SystemLanguageModel.default`;
- `SystemLanguageModel.availability`;
- `SystemLanguageModel.contextSize`;
- `SystemLanguageModel.tokenCount(for:)` for instructions, prompts and generation schemas;
- `LanguageModelSession` guided generation;
- `GenerationOptions` with greedy sampling and a maximum response-token cap.

The first Xcode 26.6 compile of this slice proved two important negative boundaries:

- `LanguageModelSession.Response.usage` is **not** part of that stable SDK surface;
- `SystemLanguageModel.variant` is **not** part of that stable SDK surface.

Those newer beta APIs are therefore not used as evidence. The runner and packager do not invent output-token counts or a model variant name.

`tokenCount(for:)` is guarded by an explicit macOS/iOS 26.4 availability boundary. A 26.0–26.3 runtime fails closed as unsupported for this evidence protocol even though basic Foundation Models generation exists there.

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
- never truncates benchmark text, instructions or schema to fit a profile.

The packager:

- accepts only the five fixed host evidence files from the runner;
- never calls Foundation Models or any network/model runtime;
- never reconstructs a better proposal from expected benchmark answers;
- requires the normalized proposal to be the exact mechanical projection of the raw proposal;
- uses the existing `scripts/evaluate_action_proposals.py` unchanged;
- keeps Apple platform/product-license eligibility and the next model decision `unverified`;
- never converts host evidence into a physical-device readiness claim.

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

Reason codes are likewise limited to the existing Benchmark V0 values. This prevents arbitrary schema expansion but does **not** make a proposal semantically correct. A model can still return the wrong allowed tool, an irrelevant allowed argument, duplicate missing-argument entries or a wrong reason code. The normalizer and packager preserve those failures for the evaluator.

## Target-leakage prevention

`AppleBenchmarkCase` contains only:

```text
case_id
language
user_text
```

Swift's `JSONDecoder` ignores the remaining benchmark fields. Expected proposal type, intent, tool, argument values, missing arguments and reason code are therefore never loaded into the runner's case object and cannot be interpolated into its instructions or prompt.

The fixed runner instructions describe only the public routing task and supported route vocabulary. They contain no case-specific expected answer.

The packager derives `normalized-input.jsonl` from only:

- benchmark `case_id`, `language` and `user_text`;
- the exact fixed runner instructions and instructions ID;
- `include_schema_in_prompt=true`;
- an empty tools array;
- the repository path and SHA-256 of `ios/Sources/ModelResearchSupport/AppleFoundationBaseline.swift` that defines the guided-generation source contract.

Expected benchmark answers are not copied into `normalized-input.jsonl`.

## Native input-token gate

Apple documents that instructions, prompts and guided-generation schemas consume model context. For every case the runner measures, with the system model's own tokenizer:

1. fixed instructions tokens;
2. exact `FMGeneratedProposal.generationSchema` tokens;
3. exact current case prompt tokens.

There are no tools.

The runner records all three component counts and their exact sum as `model_visible_input_token_count`. If the sum exceeds the selected V0 input budget, the run stops before inference. It never shortens or rewrites an input.

The packager independently verifies that all token records:

- follow the exact 40-case benchmark order;
- contain positive component counts;
- have an exact component sum;
- use one constant instructions-token count and one constant schema-token count for the run;
- stay within the selected 512/1,024 input budget;
- agree byte-for-byte semantically with the raw record's recorded model-visible input count.

This is the supported stable input-token evidence for V0. The runner and packager do **not** claim response usage or output token counts because Xcode 26.6 does not expose stable `Response.usage` on this API surface.

`SystemLanguageModel.contextSize` is recorded as the actual system-model context capacity and must be large enough for the selected profile. The packager rejects metadata whose context capacity is smaller than the profile input plus output budget.

## System-model identity

Apple updates the system language model with OS releases. iGentic therefore does not invent a custom-model revision.

The stable SDK exposes the semantic model identity `SystemLanguageModel.default` but not a stable variant display property in Xcode 26.6. The runner binds system identity as:

```text
SystemLanguageModel.default|<ProcessInfo operatingSystemVersionString>
```

It also records the OS string separately, host architecture and active Swift toolchain. The packager requires that the system identifier exactly matches the separately recorded OS value.

The generated baseline manifest therefore uses:

- `backend.class=apple_system`;
- `model_id=null`;
- `model_revision=null`;
- the validated `system_model_identifier`;
- `tokenizer_id=system-managed` with a system-bound tokenizer revision;
- Apple Foundation Models as the framework;
- the exact OS/toolchain provenance from the host receipt.

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

`greedy` is the no-seed deterministic comparison mode. The maximum response-token value always equals the selected V0 profile output budget.

PR #323 makes the JSON evidence contract explicit: `top_k` and `seed` are present with JSON `null`, and every normalized proposal contains the `tool` key with JSON `null` when no tool was generated. The packager rejects evidence that does not preserve those fields.

A successful guided-generation response is structurally complete. The current runner records `repetitionDetected=false` and `truncationDetected=false`; this V0 protocol does not claim a general repetition or truncation detector. A generation failure is a failed run rather than a repaired or partial proposal.

## Runner output directory contract

The caller must provide an existing empty real directory. A missing path, ordinary file, symlink or non-empty directory is rejected before model execution.

A completed profile writes exactly these research evidence files:

```text
raw-proposals.jsonl
normalized-proposals.jsonl
token-counts.json
applied-generation-config.json
run-metadata.json
```

`token-counts.json` records per case:

```text
case_id
instructions_token_count
schema_token_count
prompt_token_count
model_visible_input_token_count
```

Evidence bytes are constructed before writing. Files use fixed names and no-overwrite writes. If a write fails, files created by that write phase are removed.

No model cache, credentials, host identifiers, private data, screenshot or unrelated machine file belongs in this directory.

## External host command

Run from a clean checkout of the intended iGentic revision on an eligible Mac running macOS 26.4 or newer with Apple Intelligence enabled and a compatible Foundation Models SDK/runtime:

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

Do not rerun only weak cases, alter the fixed instructions after seeing results, or edit raw/normalized output before packaging and evaluation.

## Deterministic evidence packaging

After a completed profile has produced the five runner files, package that same directory from the matching clean repository revision:

```bash
python3 scripts/apple_foundation_baseline_packager.py --run-dir "$OUT"
```

The packager accepts no model/runtime dependency. It uses Python's standard library plus the repository's existing validator/evaluator modules.

Before writing anything, it fails closed unless:

- the canonical 40-case Benchmark V0 validates;
- the run directory is real rather than a symlink and contains no unexpected entries;
- all five runner evidence files are regular files rather than symlinks;
- metadata exactly binds the profile, 40-case count, `SystemLanguageModel.default|<os>`, context capacity, macOS/iOS 26.4 evidence boundary, token method, instructions, architecture/toolchain and host-only claims;
- token components, sums, order and profile budgets are internally consistent;
- raw proposal records and normalized records follow exact benchmark order;
- every normalized record is the exact mechanical projection of its raw proposal with no semantic repair;
- the explicit-null encoding contract from PR #323 is preserved;
- greedy/no-seed/no-tools generation configuration exactly matches the selected profile;
- all three package targets are absent, including dangling symlinks.

The packager then runs the existing backend-neutral evaluator against the already validated normalized proposals and creates exactly:

```text
normalized-input.jsonl
evaluator-result.json
baseline-run-manifest.json
```

All output bytes and the complete manifest are built and validated before the first package file is written. Package files use no-overwrite creation. If a write fails, the packager removes only files created by that packaging attempt and leaves the five host inputs untouched.

## Provenance binding

The generated `igentic-baseline-run-v0` manifest hashes and binds:

- the immutable Benchmark V0;
- the evaluator contract, benchmark validator and evaluator implementation;
- `token-counts.json`;
- `applied-generation-config.json`;
- `normalized-proposals.jsonl`;
- the generated evaluator result;
- the exact UTF-8 runner instructions;
- the generated normalized input;
- the Apple system/OS host identity.

`normalizer.revision` is a deterministic combined SHA-256 over both:

```text
ios/Sources/ModelResearchSupport/AppleFoundationBaseline.swift
ios/Sources/ModelResearchSupport/AppleFoundationBaselineEvidenceEncoding.swift
```

This ensures that both the raw-to-normalized proposal semantics and the explicit-null JSON serialization layer are provenance-bound. Changing either source changes the manifest normalizer revision.

The manifest remains conservative:

```text
backend.class=apple_system
execution.evidence_class=host
physical_device_run=false
physical_device_readiness_claimed=false
backend.license_gate_status=unverified
next_decision=unverified
```

The Apple documentation reference is recorded as platform provenance, not as a product/license approval. A successful evaluation does not automatically promote the backend to `keep` or `rework`.

## CI evidence

Phase 0 keeps the existing compatibility paths:

- default-toolchain macOS package build/test;
- Linux package build/test;
- the Xcode 26.3 `AgentCore` Foundation Models availability compile introduced by #317.

The Benchmark V0 runner additionally compiles on `macos-latest`, which currently resolves to the macOS 26 ARM hosted image and prints the exact Xcode and Swift versions before compiling `ModelResearchSupport` and `AppleFoundationBaselineHost`.

That job **compiles but does not execute the model**. GitHub-hosted hardware is not physical iPhone evidence and is not assumed to have Apple Intelligence available.

Repo Audit runs the deterministic Apple evidence-packager regression suite using synthetic runner evidence. Those tests do not execute Foundation Models.

## What this contract proves

A green exact-head runner CI run proves:

- ordinary iGentic package compatibility remains intact;
- the research support code compiles on Linux through its unsupported-platform path;
- the real stable Foundation Models 26.4+ runner branch compiles with the hosted current Xcode 26 toolchain;
- pure contract tests pass without model availability.

A green packager regression suite additionally proves on synthetic evidence that:

- identical completed host inputs produce byte-identical package outputs;
- generated manifests pass the existing V0 manifest validator;
- malformed or inconsistent metadata/token/proposal evidence fails closed;
- pre-existing or symlinked evidence targets are not overwritten;
- write failures do not delete the original five host evidence files;
- evaluator failures caused by wrong model semantics remain failures rather than being repaired.

Neither CI path proves that the Apple system model executed or produced a quality result. That evidence exists only after the external host command actually completes on an eligible Mac.

## Follow-up

After this runner and packager contract is merged, the next evidence step is an actual untouched external host run on an eligible Mac with Apple Intelligence enabled:

1. run the complete `Router-small` profile once without case selection;
2. preserve and package its complete evidence directory;
3. inspect the evaluator result without editing model outputs;
4. repeat `Router-normal` only under the predeclared protocol;
5. keep all conclusions host-only.

Actual physical iPhone Air evidence remains a later, separate protocol.

## Primary Apple sources

- Foundation Models framework: https://developer.apple.com/documentation/foundationmodels
- SystemLanguageModel: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
- `tokenCount(for:)`: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/tokencount(for:)
- LanguageModelSession: https://developer.apple.com/documentation/foundationmodels/languagemodelsession
- Managing the context window: https://developer.apple.com/documentation/foundationmodels/managing-the-context-window
- Foundation Models updates: https://developer.apple.com/documentation/updates/foundationmodels
