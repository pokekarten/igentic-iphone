# iPhone Air Model Candidate Manifest

Status: research gate, no runtime integration  
Sources checked: 2026-06-22  
Parent issues: #74 and #75

## Purpose

This manifest records source-backed candidates for small, local iGentic model experiments. It is a selection and evidence gate, not a device-readiness claim.

Models are helpers. `PolicyEngine`, `ApprovalManager`, schema validation, audit boundaries and deterministic rejection remain authoritative. A model may propose an intent, tool or draft response; it must not authorize or execute an action.

Simulator, Mac, vendor, model-card and runtime-repository results are not iPhone Air evidence. `IPHONE_AIR_EVIDENCE` remains `none` until the exact model artifact and runtime are observed on a physical target device.

Do not commit model weights, adapters, private prompts, credentials, messages, contacts, device identifiers or real user data to this repository.

## Advancement gate

A candidate does not advance to training or app integration until all of the following are recorded:

1. exact model repository and immutable revision;
2. applicable license and release implications;
3. tokenizer and chat/tool template revision;
4. untouched baseline on the immutable synthetic test set;
5. supported export and runtime path;
6. failure, cancellation and rollback behavior;
7. physical-device evidence before any iPhone Air performance claim.

Unknown information is written as `unknown` or `unverified` rather than inferred.

## Manifest fields

Each primary candidate uses the following fields:

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

## Primary candidates

### 1. Qwen3 0.6B

```text
MODEL_ID: Qwen/Qwen3-0.6B
MODEL_REVISION: unpinned; pin before download or evaluation
MODEL_ROLE: smallest multilingual text router and structured-proposal baseline
STATUS: first baseline candidate
PARAMETER_SCALE: 0.6B advertised; 0.44B non-embedding advertised
MODALITY: text
LANGUAGES: 100+ languages and dialects advertised
CONTEXT_ADVERTISED: 32,768 tokens
LICENSE: Apache-2.0
LICENSE_GATE: low friction, but exact artifact and notices still require review
NATIVE_TOOL_FORMAT: Qwen chat template and Qwen-Agent tool flow; normalize and validate outside the model
TRAINING_PATH: Transformers plus PEFT/TRL LoRA or QLoRA feasibility to verify; no iGentic training run yet
KNOWN_PORTABLE_FORMATS: Hugging Face safetensors; llama.cpp ecosystem conversion/quantization path
RUNTIME_EVIDENCE: Qwen3 is listed as supported by llama.cpp and other local applications; exact iOS artifact untested
IPHONE_AIR_EVIDENCE: none
KNOWN_RISKS: small-model quality ceiling, repetition, language mixing under some sampling settings, malformed or invented arguments
NEXT_TEST: untouched non-thinking text-only baseline at 1,024 and 2,048 context tokens
ROLLBACK: deterministic router/fallback; remove model adapter without changing policy or approval logic
SOURCES_CHECKED_AT: 2026-06-22
```

Decision note: this is the default first candidate when baseline quality is close because it is the smallest current Apache-2.0 text/tool candidate in the shortlist and has a mature local-runtime path.

Primary source: https://huggingface.co/Qwen/Qwen3-0.6B

### 2. LFM2 1.2B Tool

```text
MODEL_ID: LiquidAI/LFM2-1.2B-Tool
MODEL_REVISION: unpinned; pin before download or evaluation
MODEL_ROLE: dedicated non-thinking tool-router comparison
STATUS: first comparison candidate, license-gated
PARAMETER_SCALE: 1.2B family name; exact pinned configuration must be recorded
MODALITY: text
LANGUAGES: German is explicitly supported; model-card language-count metadata should be reconciled before release documentation
CONTEXT_ADVERTISED: unverified for the exact pinned artifact
LICENSE: lfm1.0
LICENSE_GATE: required before adapter publication, redistribution or product release
NATIVE_TOOL_FORMAT: JSON function definitions and model-specific tool-call special tokens; output is Python-like and must be parsed into a strict iGentic schema
TRAINING_PATH: official model card links LoRA/SFT examples for TRL, Axolotl and Unsloth
KNOWN_PORTABLE_FORMATS: Hugging Face safetensors; linked GGUF variant for llama.cpp
RUNTIME_EVIDENCE: LFM2 family implementation and conversion support exist in llama.cpp and ExecuTorch source; exact iOS artifact untested
IPHONE_AIR_EVIDENCE: none
KNOWN_RISKS: custom license, model-specific tool syntax, parser complexity, possible mismatch with JSON-only product contracts
NEXT_TEST: untouched native-template baseline with temperature 0, after license gate is recorded
ROLLBACK: deterministic router/fallback; do not make the model-specific tool format a public API
SOURCES_CHECKED_AT: 2026-06-22
```

Decision note: this candidate advances only if it materially outperforms Qwen3 0.6B on structured output and the `lfm1.0` license is acceptable for the intended distribution.

Primary source: https://huggingface.co/LiquidAI/LFM2-1.2B-Tool

### 3. Qwen3 1.7B

```text
MODEL_ID: Qwen/Qwen3-1.7B
MODEL_REVISION: unpinned; pin before download or evaluation
MODEL_ROLE: higher-quality text assistant and router comparison
STATUS: second-stage text candidate
PARAMETER_SCALE: 1.7B advertised
MODALITY: text
LANGUAGES: 100+ languages and dialects advertised for Qwen3
CONTEXT_ADVERTISED: 32,768 tokens
LICENSE: Apache-2.0
LICENSE_GATE: low friction, exact artifact and notices still require review
NATIVE_TOOL_FORMAT: Qwen chat template and Qwen-Agent tool flow
TRAINING_PATH: Transformers plus PEFT/TRL LoRA or QLoRA feasibility to verify
KNOWN_PORTABLE_FORMATS: Hugging Face safetensors; llama.cpp ecosystem conversion/quantization path
RUNTIME_EVIDENCE: Qwen3 family is supported by llama.cpp and ExecuTorch examples; exact iOS artifact untested
IPHONE_AIR_EVIDENCE: none
KNOWN_RISKS: higher memory, loading time, energy and thermal cost than 0.6B; repetition and malformed arguments remain possible
NEXT_TEST: run only after the 0.6B baseline shows a measurable quality gap that may justify a larger model
ROLLBACK: return to Qwen3 0.6B or deterministic routing
SOURCES_CHECKED_AT: 2026-06-22
```

Primary source: https://huggingface.co/Qwen/Qwen3-1.7B

### 4. LFM2.5 1.2B Instruct

```text
MODEL_ID: LiquidAI/LFM2.5-1.2B-Instruct
MODEL_REVISION: unpinned; pin before download or evaluation
MODEL_ROLE: local assistant, extraction, summarization and retrieval-augmented response candidate
STATUS: role-specific candidate, license-gated
PARAMETER_SCALE: approximately 1.2B family; exact pinned configuration required
MODALITY: text
LANGUAGES: multilingual with German support advertised
CONTEXT_ADVERTISED: 32,768 tokens advertised
LICENSE: lfm1.0
LICENSE_GATE: required before adapter publication, redistribution or product release
NATIVE_TOOL_FORMAT: native function/tool flow documented by Liquid AI; exact pinned template required
TRAINING_PATH: LoRA/QLoRA feasibility through Transformers ecosystem; use official examples where applicable
KNOWN_PORTABLE_FORMATS: Hugging Face safetensors; official or publisher-linked GGUF and ONNX variants exist
RUNTIME_EVIDENCE: LFM2 family support exists in llama.cpp and ExecuTorch source; exact iOS artifact untested
IPHONE_AIR_EVIDENCE: none
KNOWN_RISKS: custom license, less task-specific than LFM2 Tool, runtime/operator compatibility, output-schema drift
NEXT_TEST: assistant-only baseline after the router candidate is selected
ROLLBACK: disable assistant profile and keep deterministic/local non-generative helpers
SOURCES_CHECKED_AT: 2026-06-22
```

Primary source: https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct

### 5. LFM2.5 VL 450M

```text
MODEL_ID: LiquidAI/LFM2.5-VL-450M
MODEL_REVISION: unpinned; pin before download or evaluation
MODEL_ROLE: optional separately loaded OCR, document and vision sidecar
STATUS: role-specific multimodal candidate, license-gated
PARAMETER_SCALE: 450M advertised
MODALITY: image and text
LANGUAGES: multilingual vision understanding including German advertised
CONTEXT_ADVERTISED: unverified for the exact pinned artifact
LICENSE: lfm1.0
LICENSE_GATE: required before adapter publication, redistribution or product release
NATIVE_TOOL_FORMAT: tool use is documented for text input; exact multimodal/tool combination must be verified
TRAINING_PATH: publisher links LoRA examples; no iGentic training run yet
KNOWN_PORTABLE_FORMATS: Hugging Face safetensors; GGUF and ONNX variants; WebGPU demonstration path
RUNTIME_EVIDENCE: LFM2-VL is listed by llama.cpp; exact iOS multimodal packaging untested
IPHONE_AIR_EVIDENCE: none
KNOWN_RISKS: custom license, image preprocessing cost, OCR hallucination, extra encoder memory, larger app/model packaging surface
NEXT_TEST: synthetic image/document evaluation only after the text router path is stable
ROLLBACK: unload or omit the sidecar; keep text path independent
SOURCES_CHECKED_AT: 2026-06-22
```

Primary source: https://huggingface.co/LiquidAI/LFM2.5-VL-450M

### 6. Qwen3.5 0.8B

```text
MODEL_ID: Qwen/Qwen3.5-0.8B
MODEL_REVISION: unpinned; pin before download or evaluation
MODEL_ROLE: experimental compact multimodal/router candidate
STATUS: experimental second-wave candidate
PARAMETER_SCALE: 0.8B language model advertised, plus vision encoder packaging
MODALITY: image and text; text-only serving mode is documented
LANGUAGES: 201 languages and dialects advertised
CONTEXT_ADVERTISED: 262,144 tokens
LICENSE: Apache-2.0
LICENSE_GATE: low friction, exact artifact and notices still require review
NATIVE_TOOL_FORMAT: qwen3_coder tool-call parser documented for serving frameworks
TRAINING_PATH: model card identifies task-specific fine-tuning as an intended use; exact LoRA support for the pinned architecture must be verified
KNOWN_PORTABLE_FORMATS: Hugging Face safetensors; llama.cpp ecosystem quantizations are discoverable
RUNTIME_EVIDENCE: Qwen3.5 implementation exists in current llama.cpp and ExecuTorch source; exact iOS build untested
IPHONE_AIR_EVIDENCE: none
KNOWN_RISKS: newer hybrid architecture, very large vocabulary and advertised context, vision packaging, low 0.8B agent benchmark scores relative to the 2B sibling, main-branch/nightly framework requirements in documented server paths
NEXT_TEST: text-only baseline after mature Qwen3/LFM2 candidates; do not begin with advertised maximum context
ROLLBACK: return to Qwen3 text baseline; omit vision encoder and model artifact
SOURCES_CHECKED_AT: 2026-06-22
```

Decision note: the model is interesting because it combines a compact language model with multimodal support, but it is not the first baseline. The model card itself positions this scale for prototyping and task-specific fine-tuning, and its published agent scores are materially below the 2B sibling.

Primary source: https://huggingface.co/Qwen/Qwen3.5-0.8B

### 7. Gemma 4 E2B Mobile QAT

```text
MODEL_ID: google/gemma-4-E2B-it-qat-mobile-transformers
MODEL_REVISION: unpinned; pin before download or evaluation
MODEL_ROLE: later multimodal quality-mode candidate
STATUS: later mobile-QAT experiment
PARAMETER_SCALE: E2B architecture label; exact active/total parameter accounting must be taken from the pinned config and model card
MODALITY: multimodal; exact text, image and audio packaging for the selected runtime must be verified
LANGUAGES: multilingual; exact supported-language statement must be captured from the pinned model card
CONTEXT_ADVERTISED: up to 128K for the small Gemma 4 family, subject to exact checkpoint verification
LICENSE: Apache-2.0 on the referenced repository
LICENSE_GATE: review model card and bundled terms for the exact revision before redistribution
NATIVE_TOOL_FORMAT: native function-calling capability is advertised; exact runtime parser must be verified
TRAINING_PATH: start from the mobile QAT checkpoint; do not assume a second aggressive quantization preserves quality
KNOWN_PORTABLE_FORMATS: Transformers mobile-QAT checkpoint; Gemma 4 support exists in llama.cpp source
RUNTIME_EVIDENCE: current llama.cpp contains Gemma 4 architecture implementation; the WebGPU demo is a separate experimental browser path
IPHONE_AIR_EVIDENCE: none
KNOWN_RISKS: larger package and working memory than first candidates, multimodal encoder cost, architecture/runtime conversion risk, thermal cost, vendor mobile optimization not specific to iPhone Air
NEXT_TEST: compatibility and short-context load test only after Tier A text candidates; begin text-only where possible
ROLLBACK: omit quality profile and use the selected smaller text model
SOURCES_CHECKED_AT: 2026-06-22
```

Primary source: https://huggingface.co/google/gemma-4-E2B-it-qat-mobile-transformers

## Reference-only candidates

These models remain comparison points. They do not displace the smallest viable candidates without measured evidence.

| Model | License gate | Reference value | Why not first |
| --- | --- | --- | --- |
| `Qwen/Qwen3.5-2B` | Apache-2.0 | stronger Qwen3.5 quality and agent comparison | larger memory and thermal target than 0.8B/0.6B |
| `HuggingFaceTB/SmolLM3-3B` | Apache-2.0 | multilingual text and tool-calling quality reference | 3B scale is too large for the first iPhone Air baseline |
| `ibm-granite/granite-4.0-micro` | Apache-2.0 | enterprise, RAG and function-calling reference | 3B scale and no current device evidence |
| `microsoft/Phi-4-mini-instruct` | MIT | reasoning and tool-format reference | approximately 3.8B and model card warns that hallucinated function names or URLs can occur |
| `meta-llama/Llama-3.2-1B-Instruct` | Llama 3.2 Community License | mature mobile/runtime comparison | gated/custom terms and attribution requirements add release friction |
| `google/gemma-3-1b-it` | Gemma terms | mature small Gemma deployment comparison | custom terms and less direct tool-router focus than Tier A |

Primary sources:

- https://huggingface.co/Qwen/Qwen3.5-2B
- https://huggingface.co/HuggingFaceTB/SmolLM3-3B
- https://huggingface.co/ibm-granite/granite-4.0-micro
- https://huggingface.co/microsoft/Phi-4-mini-instruct
- https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct
- https://huggingface.co/google/gemma-3-1b-it

## Runtime research order

### 1. llama.cpp and GGUF compatibility baseline

Use first for portable compatibility, quantization and initial device measurement because the project provides GGUF tooling, Apple Silicon/Metal support, broad model-family support and an XCFramework build script.

Architecture presence or a successful desktop run proves only implementation compatibility. It does not prove that the exact artifact loads, remains stable or performs acceptably on iPhone Air.

Sources:

- https://github.com/ggml-org/llama.cpp
- https://github.com/ggml-org/llama.cpp/blob/master/build-xcframework.sh

### 2. ExecuTorch experimental adapter spike

Use second behind the existing `LocalModelRuntime` boundary. ExecuTorch documents Objective-C and Swift LLM components, token streaming and stopping, but explicitly describes the iOS LLM API as experimental and subject to change.

Sources:

- https://docs.pytorch.org/executorch/stable/llm/run-on-ios.html
- https://github.com/pytorch/executorch/tree/main/examples/models/qwen3
- https://github.com/pytorch/executorch/tree/main/examples/models/qwen3_5
- https://github.com/pytorch/executorch/tree/main/examples/models/lfm2

### 3. MLC-LLM comparison

Evaluate later as an iOS Swift and custom-model deployment alternative. Treat conversion, generated libraries, model packaging and conversation templates as additional integration surface.

Source: https://llm.mlc.ai/docs/deploy/ios.html

### 4. Core ML feasibility

Attempt only after the selected model graph and tokenizer path are understood. A successful conversion is a compatibility result, not physical-device performance evidence. Stateful KV-cache and mixed-precision experiments are subsequent optimization steps, not assumptions.

Sources:

- https://apple.github.io/coremltools/docs-guides/source/stateful-models.html
- https://apple.github.io/coremltools/docs-guides/source/opt-overview.html

### 5. WebGPU browser path

Keep WebGPU as a separate PWA/browser experiment. WebGPU execution is not equivalent to a native Core ML or Neural Engine path, and browser-kernel results on another Apple chip are not iPhone Air evidence.

## First untouched baseline selection gate

No LoRA or QLoRA run is selected until both first candidates have complete, comparable untouched results.

| Profile | Context | Maximum output | Purpose |
| --- | ---: | ---: | --- |
| Router-small | 1,024 | 64 | intent, tool and required arguments |
| Router-normal | 2,048 | 96 | ambiguous and multi-argument requests |
| Assistant-check | 2,048 | 192 | short German summarization and extraction only |

Candidates:

1. `Qwen/Qwen3-0.6B` in non-thinking, text-only mode;
2. `LiquidAI/LFM2-1.2B-Tool` with its native tool format, only after the license gate is recorded.

Required metrics:

- schema-valid output rate;
- correct intent and tool rate;
- required-argument accuracy;
- invented or unsupported tool/argument rate;
- safe-failure and refusal accuracy;
- German/English consistency;
- repetition and truncation rate;
- artifact size and host peak memory where actually observed.

When scores are close, prefer Qwen3 0.6B because Apache-2.0 and the smaller scale reduce initial release and device risk. LFM2 Tool advances only when it demonstrates a material structured-output advantage and its license gate passes.

## Training artifact contract

Every later training run must record:

- immutable model revision;
- license reference;
- dataset revision and split hashes;
- immutable test-set identifier;
- prompt and chat-template revision;
- dependency lock or exported environment;
- random seed;
- context length;
- batch and gradient-accumulation settings;
- LoRA target modules and rank settings;
- quantization configuration;
- resumable checkpoints;
- baseline and post-training evaluation;
- explicit `KEEP`, `REWORK` or `REJECT` decision.

Free GPU services and credits are opportunistic executors, not guaranteed dependencies. Training must be resumable and provider-independent.

## Stop conditions

Stop a candidate before app integration when any of the following is true:

- license or redistribution terms are unresolved;
- the exact tokenizer or chat/tool template cannot be reproduced;
- the model cannot reliably stop or be cancelled;
- structured output cannot be validated before returning a proposal;
- the runtime requires policy or approval logic to move into the prompt;
- export requires unsupported operators or custom kernels without a bounded maintenance plan;
- the candidate fails the immutable test set without a measured benefit over the smaller baseline;
- physical-device memory, crash, battery or thermal behavior is unacceptable.

No performance or readiness claim may be made until the exact artifact, runtime, configuration and physical iPhone Air measurement are recorded.