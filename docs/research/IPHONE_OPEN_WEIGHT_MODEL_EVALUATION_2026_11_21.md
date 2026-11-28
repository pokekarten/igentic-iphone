# iGentic iPhone: open-weight model shortlist and iPhone acceptance, 2026-11-21

Status: **research / decision proposal only**. Neither a model downloaded to the iPhone nor a device inference benchmark is claimed. Models and versions must be pinned by revision/hash before accepting or distributing weights. This document intentionally introduces no runtime, entitlement or external dependency.

## Primary candidates

| Candidate | Suggested role | Source | Runtime to evaluate | Acceptance |
| --- | --- | --- | --- | --- |
| Qwen3.5-2B | Primary German-language intent and typed-action proposal baseline | https://huggingface.co/Qwen/Qwen3.5-2B | GGUF llama.cpp / llama.swift first; Core ML alternative | Structured intent accuracy, prompt-injection resistance and RAM |
| LFM2.5-2.6B | Low-latency offline agent alternative | https://huggingface.co/LiquidAI/LFM2.5-2.6B | Quantized GGUF llama.cpp | Cold start, thermal drift, task accuracy |
| FunctionGemma-270M | Specialist function selector; not a general conversational agent | https://huggingface.co/google/functiongemma-270m-it | Core ML available from community; validate model conversion, license | False-positive action rate and abstention |
| Qwen3.5-4B | Higher-quality comparison, if measured memory permits | https://huggingface.co/Qwen/Qwen3.5-4B | Quantized GGUF | Quality delta vs 2B, memory pressure |
| Gemma-4-E2B | Optional vision/multimodal investigation | https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf | llama.cpp or a validated Core ML conversion | Image usefulness, peak memory, license review |
| Qwen3-VL-2B-Instruct | Alternative vision exploration | https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct | Core ML conversion or compatible GGUF + projector | Image-grounded action proposal accuracy |

Check each upstream model's actual license and accompanying applicable terms at the pinned revision. Open *weights* does not necessarily mean OSI open source. Quantized file size is **not** equal to peak RAM. Do not estimate iPhone acceptance from Mac/desktop tok/s. There is no verified physical-iPhone result as of this research update.

## Swift architecture and OS 27 candidates

- https://github.com/huggingface/AnyLanguageModel — unified model interface spanning Apple Foundation Models, llama.cpp, MLX, Core ML and other providers. Evaluate package traits, transitive dependencies, iOS build support, license, and API version before committing.
- https://github.com/john-rocky/CoreML-LLM — community implementation of mobile Core ML LLM/ANE paths. Community benchmarks are **not** iGentic device benchmarks.
- https://github.com/ml-explore/mlx-swift-examples — MLX/Swift alternative for local GPU inference.
- https://github.com/ggml-org/llama.cpp — GGUF baseline; assess app size and KV cache on a physical device.
- https://developer.apple.com/wwdc26/guides/ios/ — iOS 27 App Intents / AppIntentsTesting and device APIs.

Keep Swift `PolicyEngine`, `ApprovalManager`, audit and trusted user confirmation outside every model adapter. A model output is always untrusted *text or data*, never authorization, an entitlement, an executable command, or permission to access other apps. Use a deterministic typed allowlist. Start with non-executing diagnostics and reminder *preview*; later, add an explicitly authorized app-scoped reminder creation flow as a separate reviewed PR.

## Physical iPhone Air acceptance protocol

1. Restore Xcode physical device availability: USB data connection / unlock / trust / Developer Mode / pairing / signing; **do not** reset or erase the device. Document exact iOS/Xcode/Swift build and accessible RAM/memory warnings.
2. Signed install of iGenticDiagnostics and invoke the real read-only App Intent via Shortcuts or `AppIntentsTesting`, verifying the exact returned string; simulator success is not device acceptance.
3. Run the *same* 30-50 deterministic German intent prompts through each model and a no-model baseline: diagnostic, proposed reminder, ambiguous request, disallowed system-setting changes, sensitive content, prompt injection, offline mode.
4. Record cold/warm start, tokens/sec and first-token latency, application peak RSS, memory pressure, crash rate, thermal state, battery impact and airplane-mode behavior over repeated runs. Include full prompt/version/quantization SHA and correct/incorrect decision counts; keep personal content out of logs.
5. Run each candidate's structured proposals through `UntrustedActionProposalGate` and confirm model text can **never** approve an action, override sensitivity, or run tools. Negative tests are required.
6. Accept a model only if all safety gates pass and it offers measurable practical benefit. Do not bundle GB-sized model weights in a new PR by default; provide explicit-download UI and storage budget first.

## Order of execution

P0: unblock PR #379 docs consistency and PR #381 PR-text quality; review PR #380 device test evidence. P1: physical iPhone read-only App Intent test, then pinned Qwen3.5-2B and LFM2.5-2.6B standalone local inference smoke tests. P2: integrate a single pluggable adapter into the preview-only gate and compare models; then implement the real approval-gated reminder action. P3: ARTEMIS synthetic UI lab and optional multimodal models after explicit approvals and security review.
