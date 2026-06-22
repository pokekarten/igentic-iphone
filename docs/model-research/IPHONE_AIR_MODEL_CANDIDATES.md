# iPhone Air Model Candidate Manifest

Status: research gate, no runtime integration  
Sources checked: 2026-06-22  
Parent issues: #74 and #75

## Purpose

This manifest defines a public-safe selection path for local iGentic model experiments on the iPhone Air. It is an evidence and planning artifact, not a device-readiness claim.

The product boundary is fixed:

1. deterministic Swift code remains authoritative for policy, approvals, schema validation, audit and execution;
2. a model may only return a proposal;
3. Apple system-model evidence, custom-runtime evidence and physical iPhone Air evidence are separate evidence classes;
4. no model weights, adapters, private prompts, credentials, messages, contacts, device identifiers or real user data belong in this repository.

Simulator, Mac, Android, vendor and runtime-repository results are not iPhone Air evidence. Unknown facts are written as `unknown`, `unverified` or `none`.

## Architecture paths

### Path A — deterministic Swift authority

`PolicyEngine`, `ApprovalManager`, schema validation and audit boundaries remain authoritative. No prompt, adapter or model output may override these controls.

### Path B — Apple Foundation Models system backend

Evaluate Apple's Foundation Models framework as a system-provided backend that does not require iGentic to ship its own large assistant weights.

```text
BACKEND_ID: apple-foundation-models
BACKEND_ROLE: system-provided assistant and structured-generation comparison
STATUS: evaluation candidate
OWNED_MODEL_WEIGHTS: none
AVAILABILITY: device, OS, Apple Intelligence and locale requirements must be verified in the app
ADAPTER_PATH: available capabilities and distribution requirements must be verified before commitment
IPHONE_AIR_EVIDENCE: none
KNOWN_RISKS: platform availability, API/version coupling, limited portability, no independently redistributable iGentic base model
NEXT_TEST: compile-only capability spike after the benchmark contract is merged
ROLLBACK: deterministic fallback and custom-model path remain independent
SOURCES_CHECKED_AT: 2026-06-22
```

Primary sources:

- https://developer.apple.com/documentation/foundationmodels
- https://machinelearning.apple.com/research/apple-foundation-models-2025-updates

### Path C — custom open-weight models

Custom models advance only after license, immutable revision, tokenizer/chat template, untouched baseline, export/runtime compatibility, cancellation and rollback are documented.

## Manifest fields

Every primary custom candidate uses:

```text
MODEL_ID
MODEL_REVISION
MODEL_ROLE
STATUS
PARAMETER_SCALE
MODALITY
LANGUAGES
CONTEXT_ADVERTISED
LICENSE
LICENSE_GATE
NATIVE_TOOL_FORMAT
TRAINING_PATH
KNOWN_PORTABLE_FORMATS
RUNTIME_EVIDENCE
IPHONE_AIR_EVIDENCE
KNOWN_RISKS
NEXT_TEST
ROLLBACK
SOURCES_CHECKED_AT
```

## Primary custom candidates

### 1. FunctionGemma 270M

```text
MODEL_ID: google/functiongemma-270m-it
MODEL_REVISION: unpinned; pin before download, evaluation or training
MODEL_ROLE: first specialization candidate for a fixed iGentic action router
STATUS: first training candidate, license-gated
PARAMETER_SCALE: 270M advertised
MODALITY: text
LANGUAGES: exact multilingual and German quality must be measured; vendor safety evaluation is not a German benchmark
CONTEXT_ADVERTISED: 32,768 tokens
LICENSE: Gemma terms
LICENSE_GATE: required before downloading gated files, publishing adapters or redistribution
NATIVE_TOOL_FORMAT: FunctionGemma-specific function-call tokens generated from JSON tool definitions
TRAINING_PATH: official Mobile Actions dataset and fine-tuning recipe; Colab and Kaggle entry points are linked by the publisher
KNOWN_PORTABLE_FORMATS: Hugging Face safetensors; community quantizations are discovery pointers only
RUNTIME_EVIDENCE: quantizations exist for llama.cpp-compatible applications; exact iOS artifact and tokenizer integration are untested
IPHONE_AIR_EVIDENCE: none
KNOWN_RISKS: not intended as a general dialogue model, task specialization required, Gemma license, custom parser/template, German quality unknown
NEXT_TEST: untouched 512/1,024-token action-routing baseline with 32–64 output tokens
ROLLBACK: deterministic router or Qwen3 0.6B comparison; model-specific syntax must not become the public app API
SOURCES_CHECKED_AT: 2026-06-22
```

Decision: this is the first model to specialize because it is purpose-built for function calling and small enough for a realistic free-tier experiment. Publisher Android measurements and Mobile Actions scores are orientation only, not iPhone Air evidence.

Primary source: https://huggingface.co/google/functiongemma-270m-it

### 2. Qwen3 0.6B

```text
MODEL_ID: Qwen/Qwen3-0.6B
MODEL_REVISION: unpinned; pin before download, evaluation or training
MODEL_ROLE: first Apache-2.0 multilingual router and short-assistant comparison
STATUS: first license-simple custom comparison
PARAMETER_SCALE: 0.6B advertised; 0.44B non-embedding advertised
MODALITY: text
LANGUAGES: 100+ languages and dialects advertised; German must be measured
CONTEXT_ADVERTISED: 32,768 tokens
LICENSE: Apache-2.0
LICENSE_GATE: verify exact artifact, notices and derivative packaging
NATIVE_TOOL_FORMAT: Qwen chat template and tool flow; normalize into the iGentic proposal schema
TRAINING_PATH: Transformers plus PEFT/TRL LoRA or QLoRA feasibility to verify
KNOWN_PORTABLE_FORMATS: Hugging Face safetensors; llama.cpp conversion and quantization path
RUNTIME_EVIDENCE: Qwen3 family support exists in llama.cpp and ExecuTorch examples; exact iOS artifact untested
IPHONE_AIR_EVIDENCE: none
KNOWN_RISKS: repetition, language mixing, malformed arguments and higher cost than FunctionGemma
NEXT_TEST: untouched non-thinking text-only baseline at 512/1,024 tokens
ROLLBACK: deterministic router or omit the custom model
SOURCES_CHECKED_AT: 2026-06-22
```

Primary source: https://huggingface.co/Qwen/Qwen3-0.6B

### 3. LFM2 1.2B Tool

```text
MODEL_ID: LiquidAI/LFM2-1.2B-Tool
MODEL_REVISION: unpinned; pin before download, evaluation or training
MODEL_ROLE: dedicated non-thinking tool-router comparison
STATUS: later comparison, license-gated
PARAMETER_SCALE: 1.2B family name; exact pinned configuration required
MODALITY: text
LANGUAGES: German is advertised; exact quality must be measured
CONTEXT_ADVERTISED: unverified for the exact pinned artifact
LICENSE: lfm1.0
LICENSE_GATE: required before adapter publication, redistribution or product release
NATIVE_TOOL_FORMAT: model-specific tool-call special tokens and Python-like output; strict normalization required
TRAINING_PATH: publisher-linked LoRA/SFT examples for TRL, Axolotl and Unsloth
KNOWN_PORTABLE_FORMATS: Hugging Face safetensors; publisher-linked GGUF path
RUNTIME_EVIDENCE: LFM2 family implementations exist in llama.cpp and ExecuTorch source; exact iOS artifact untested
IPHONE_AIR_EVIDENCE: none
KNOWN_RISKS: custom license, parser complexity, larger footprint, public schema leakage
NEXT_TEST: untouched native-template baseline only after the license gate
ROLLBACK: FunctionGemma, Qwen3 or deterministic routing
SOURCES_CHECKED_AT: 2026-06-22
```

Primary source: https://huggingface.co/LiquidAI/LFM2-1.2B-Tool

### 4. Qwen3 1.7B

```text
MODEL_ID: Qwen/Qwen3-1.7B
MODEL_REVISION: unpinned; pin before download or evaluation
MODEL_ROLE: higher-quality text assistant and router comparison
STATUS: second-stage text candidate
PARAMETER_SCALE: 1.7B advertised
MODALITY: text
LANGUAGES: 100+ languages and dialects advertised
CONTEXT_ADVERTISED: 32,768 tokens
LICENSE: Apache-2.0
LICENSE_GATE: verify exact artifact and notices
NATIVE_TOOL_FORMAT: Qwen chat and tool template
TRAINING_PATH: PEFT/TRL LoRA or QLoRA feasibility to verify
KNOWN_PORTABLE_FORMATS: Hugging Face safetensors; llama.cpp conversion and quantization path
RUNTIME_EVIDENCE: Qwen3 family runtime support exists; exact iOS artifact untested
IPHONE_AIR_EVIDENCE: none
KNOWN_RISKS: memory, load time, energy and thermal cost relative to smaller candidates
NEXT_TEST: only when smaller candidates fail a defined quality gate
ROLLBACK: return to Qwen3 0.6B or FunctionGemma
SOURCES_CHECKED_AT: 2026-06-22
```

Primary source: https://huggingface.co/Qwen/Qwen3-1.7B

### 5. LFM2.5 1.2B Instruct

```text
MODEL_ID: LiquidAI/LFM2.5-1.2B-Instruct
MODEL_REVISION: unpinned; pin before download or evaluation
MODEL_ROLE: local assistant, extraction, summarization and RAG candidate
STATUS: role-specific candidate, license-gated
PARAMETER_SCALE: approximately 1.2B family; exact pinned configuration required
MODALITY: text
LANGUAGES: multilingual with German support advertised
CONTEXT_ADVERTISED: 32,768 tokens advertised
LICENSE: lfm1.0
LICENSE_GATE: required before adapter publication, redistribution or product release
NATIVE_TOOL_FORMAT: publisher-native function/tool flow; exact template must be pinned
TRAINING_PATH: LoRA/QLoRA feasibility through the Transformers ecosystem
KNOWN_PORTABLE_FORMATS: safetensors; publisher-linked GGUF and ONNX variants
RUNTIME_EVIDENCE: LFM2 family runtime support exists; exact iOS artifact untested
IPHONE_AIR_EVIDENCE: none
KNOWN_RISKS: custom license, assistant scope larger than router need, schema drift
NEXT_TEST: assistant-only baseline after the router is selected
ROLLBACK: disable assistant profile and keep deterministic helpers
SOURCES_CHECKED_AT: 2026-06-22
```

Primary source: https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct

### 6. LFM2.5 VL 450M

```text
MODEL_ID: LiquidAI/LFM2.5-VL-450M
MODEL_REVISION: unpinned; pin before download or evaluation
MODEL_ROLE: optional separately loaded OCR and vision sidecar
STATUS: later role-specific candidate, license-gated
PARAMETER_SCALE: 450M advertised
MODALITY: image and text
LANGUAGES: multilingual vision understanding advertised; German must be measured
CONTEXT_ADVERTISED: unverified for the exact pinned artifact
LICENSE: lfm1.0
LICENSE_GATE: required before adapter publication, redistribution or product release
NATIVE_TOOL_FORMAT: tool use is documented for text input; multimodal/tool combination must be verified
TRAINING_PATH: publisher-linked LoRA examples; no iGentic training run
KNOWN_PORTABLE_FORMATS: safetensors; GGUF and ONNX variants; WebGPU demonstration path
RUNTIME_EVIDENCE: family support is listed by llama.cpp; exact iOS multimodal packaging untested
IPHONE_AIR_EVIDENCE: none
KNOWN_RISKS: custom license, preprocessing and encoder memory, OCR hallucination, larger package surface
NEXT_TEST: synthetic document evaluation only after the text path is stable
ROLLBACK: omit the sidecar and prefer deterministic Apple Vision APIs where suitable
SOURCES_CHECKED_AT: 2026-06-22
```

Primary source: https://huggingface.co/LiquidAI/LFM2.5-VL-450M

### 7. Qwen3.5 0.8B

```text
MODEL_ID: Qwen/Qwen3.5-0.8B
MODEL_REVISION: unpinned; pin before download or evaluation
MODEL_ROLE: experimental compact multimodal and router candidate
STATUS: experimental second-wave candidate
PARAMETER_SCALE: 0.8B language model advertised plus vision packaging
MODALITY: image and text; text-only serving is documented
LANGUAGES: 201 languages and dialects advertised
CONTEXT_ADVERTISED: 262,144 tokens
LICENSE: Apache-2.0
LICENSE_GATE: verify exact artifact and notices
NATIVE_TOOL_FORMAT: Qwen tool parser/template for the pinned runtime must be verified
TRAINING_PATH: task-specific fine-tuning is an intended use; exact adapter support must be verified
KNOWN_PORTABLE_FORMATS: safetensors; llama.cpp ecosystem quantizations are discoverable
RUNTIME_EVIDENCE: current llama.cpp and ExecuTorch source contain Qwen3.5 work; exact iOS build untested
IPHONE_AIR_EVIDENCE: none
KNOWN_RISKS: newer architecture, vision packaging, oversized advertised context, runtime churn
NEXT_TEST: text-only after mature small baselines; never begin at maximum context
ROLLBACK: Qwen3 0.6B or FunctionGemma
SOURCES_CHECKED_AT: 2026-06-22
```

Primary source: https://huggingface.co/Qwen/Qwen3.5-0.8B

### 8. Gemma 4 E2B Mobile QAT

```text
MODEL_ID: google/gemma-4-E2B-it-qat-mobile-transformers
MODEL_REVISION: unpinned; pin before download or evaluation
MODEL_ROLE: later multimodal quality-mode candidate
STATUS: later mobile-QAT experiment
PARAMETER_SCALE: E2B architecture label; exact active and total parameters must be read from the pinned artifact
MODALITY: multimodal; exact runtime packaging must be verified
LANGUAGES: multilingual; exact pinned model statement required
CONTEXT_ADVERTISED: up to 128K for the family, subject to exact checkpoint verification
LICENSE: repository advertises Apache-2.0; exact revision and bundled terms require review
LICENSE_GATE: mandatory before redistribution
NATIVE_TOOL_FORMAT: native function-calling capability is advertised; parser must be verified
TRAINING_PATH: start from the mobile QAT checkpoint; no blind second aggressive quantization
KNOWN_PORTABLE_FORMATS: Transformers mobile-QAT checkpoint; Gemma 4 runtime work exists in llama.cpp
RUNTIME_EVIDENCE: architecture implementation is not iPhone execution evidence
IPHONE_AIR_EVIDENCE: none
KNOWN_RISKS: package size, working memory, multimodal encoder cost, conversion and thermal risk
NEXT_TEST: short-context text-only compatibility after smaller candidates
ROLLBACK: omit the quality profile
SOURCES_CHECKED_AT: 2026-06-22
```

Primary source: https://huggingface.co/google/gemma-4-E2B-it-qat-mobile-transformers

## Reference-only candidates

| Model | License gate | Reference value | Why not first |
| --- | --- | --- | --- |
| `Qwen/Qwen3.5-2B` | Apache-2.0 | stronger same-family quality comparison | larger memory and thermal target |
| `HuggingFaceTB/SmolLM3-3B` | Apache-2.0 | multilingual text/tool reference | 3B scale |
| `ibm-granite/granite-4.0-micro` | Apache-2.0 | enterprise/RAG/function reference | 3B scale and no device evidence |
| `microsoft/Phi-4-mini-instruct` | MIT | reasoning and function reference | approximately 3.8B |
| `meta-llama/Llama-3.2-1B-Instruct` | Llama Community License | mature runtime comparison | custom terms and attribution |
| `google/gemma-3-1b-it` | Gemma terms | mature small Gemma comparison | custom terms and less router focus |

## Runtime research order

1. **Apple Foundation Models** for the system-provided path. Availability and behavior must be tested in-app.
2. **llama.cpp/GGUF** for the first portable custom-model compatibility baseline and Swift XCFramework path.
3. **ExecuTorch** as an experimental second native adapter.
4. **Core ML** only after exact graph, tokenizer and stateful-cache conversion feasibility.
5. **MLC-LLM** as a later packaging/runtime comparison.
6. **WebGPU** as a separate browser/PWA experiment, not a Neural Engine claim.

Runtime source presence proves implementation support only. It does not prove that an artifact loads or performs acceptably on iPhone Air.

Primary runtime sources:

- https://github.com/ggml-org/llama.cpp
- https://github.com/ggml-org/llama.cpp/blob/master/build-xcframework.sh
- https://docs.pytorch.org/executorch/stable/llm/run-on-ios.html
- https://llm.mlc.ai/docs/deploy/ios.html
- https://apple.github.io/coremltools/docs-guides/source/stateful-models.html
- https://apple.github.io/coremltools/docs-guides/source/opt-overview.html

## First untouched benchmark contract

No training run is selected until comparable untouched results exist for:

1. Apple Foundation Models without an iGentic adapter;
2. FunctionGemma 270M;
3. Qwen3 0.6B in non-thinking mode.

LFM2 Tool may enter only after its license gate.

### Evaluation set

- 120 synthetic cases: 60 German and 60 English;
- 8–12 fixed tool schemas;
- categories: direct call, missing argument, ambiguous intent, unsupported tool, no-tool response, safe refusal and malformed-output recovery;
- immutable test cases are never copied into training data;
- no real personal or device data.

### Shared proposal schema

```json
{
  "proposalType": "tool_call | clarify | no_tool | refuse",
  "tool": "string | null",
  "arguments": {},
  "missingArguments": [],
  "reasonCode": "string"
}
```

The model does not return authoritative policy level, approval or execution decisions. Swift computes those after validation.

### Profiles

| Profile | Input context | Maximum output | Purpose |
| --- | ---: | ---: | --- |
| Router-small | 512 | 32 | direct tool and arguments |
| Router-normal | 1,024 | 64 | ambiguity and missing fields |
| Assistant-check | 2,048 | 192 | short summary/extraction comparison |

### Selection metrics

- schema-valid proposal rate;
- correct tool and intent rate;
- required-argument accuracy;
- invented tool or argument rate;
- clarification accuracy;
- safe-failure and refusal accuracy;
- German/English consistency;
- repetition and truncation rate;
- artifact size and host memory only when actually observed.

FunctionGemma is the default first specialization candidate. Qwen3 0.6B wins when results are close and license simplicity or multilingual behavior is decisive.

## Free-tier training artifact contract

Free GPU availability is opportunistic and not guaranteed. Kaggle, Colab or other credits are interchangeable executors.

Every run must be resumable and record:

- immutable model revision and license reference;
- dataset revision plus train/validation hashes;
- immutable test-set identifier;
- prompt and chat-template revision;
- dependency lock or exported environment;
- random seed, context, batch and gradient accumulation;
- LoRA target modules, rank and quantization settings;
- checkpoint after each useful stage;
- untouched and post-training evaluation;
- explicit `KEEP`, `REWORK` or `REJECT` decision.

First training target: 200–500 separate synthetic examples for FunctionGemma with short inputs and 32–64 output tokens. Qwen3 training begins only when the untouched comparison justifies it.

## Stop conditions

Stop before app integration when:

- license or redistribution terms are unresolved;
- tokenizer or tool template cannot be reproduced;
- output cannot be stopped, cancelled or validated;
- a runtime requires policy or approval authority to move into the prompt;
- export depends on unsupported operators or kernels without a bounded maintenance plan;
- the candidate does not beat the smaller baseline on the immutable test;
- physical-device crash, memory, battery or thermal behavior is unacceptable.

No performance or readiness claim may be made until the exact artifact, runtime, configuration and physical iPhone Air measurement are recorded.