# Open-weight models on iPhone: iOS 27 source-verified runtime survey

**Date:** 2026-11-22. **Owner goal:** iGentic iPhone, on-device/local-first, iOS **27.0+ only**. **Evidence:** Exa plugin search (11 independent discovery queries), official WWDC26 Apple material, and direct read of GitHub README/Swift package/source docs. **Limits:** these are upstream implementation claims and source-level API evidence. We did **not** run their models on the owner's iPhone, measure real-device memory/speed or verify their model weight licenses. GitHub `main` branches are mutable. This research lives on [PR #379](https://github.com/pokekarten/igentic-iphone/pull/379); the iOS 27 deployment migration is separate [PR #389](https://github.com/pokekarten/igentic-iphone/pull/389).

## What *changes* in iOS 27

Apple WWDC26 **[Bring an LLM provider to Foundation Models](https://developer.apple.com/videos/play/wwdc2026/339/)** introduces a public **`LanguageModel` + `LanguageModelExecutor`** provider interface. This makes **`LanguageModelSession(model: customModel)`** possible for non-Apple models, rather than only Apple's built-in system provider. This is an SDK API and **does not automatically install any open-weight model**. Apple also publishes [Core AI](https://developer.apple.com/videos/play/wwdc2026/326/) for export/deployment of `.aimodel` bundles with Apple-silicon GPU/Neural Engine acceleration, model specialization and architecture-specific builds.

**Three viable local formats (different backends):**
1. **MLX / Hugging Face 4-bit packages**: MLX Swift uses the GPU, quantized Hugging Face MLX-format models, Swift tokenization, model download + cache; iOS 27 adapter bridges to FoundationModels.
2. **GGUF / llama.cpp**: llama.cpp uses Metal GPU (or CPU), GGUF model files, exact runtime/model pins; its new iOS 27 adapter also bridges to FoundationModels.
3. **Core AI / `.aimodel`**: models exported from PyTorch using Apple's toolchain, with required tokenizer resources, platform-specific compilation and specialization; must test on a **real physical iPhone**, not rely on simulator inference.

Do not confuse **"runs on iOS 27"** with **"uses iOS 27's new LanguageModel protocol"**. Older MLX/GGUF/Core ML apps can still run on iOS 27 but often retain their private generation APIs.

## Direct-source shortlist

| Priority | Repository | iPhone model runtime | iOS 27-specific integration / observed boundary | iGentic decision |
| --- | --- | --- | --- | --- |
| P0 | [ml-explore/mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) ([adapter docs](https://github.com/ml-explore/mlx-swift-lm/blob/main/Libraries/MLXFoundationModels/README.md)) | MLX LLM + VLM, Hugging Face 4-bit packages; GPU | First-party MLXFoundationModels `MLXLanguageModel` conforms to Apple's `LanguageModel`; supports standard sessions, guided generation and declared tool capabilities; **iOS 27 SDK** | **Primary local Qwen engine candidate** |
| P0 | [pgorzelany/swift-llama-cpp](https://github.com/pgorzelany/swift-llama-cpp) | llama.cpp/Metal; GGUF | `LlamaLanguageModel` + `LlamaLanguageModelExecutor` for `LanguageModelSession`; **Swift 6.4 / iOS 27**, pinned llama.cpp Apple XCFramework + checksum; named and SHA-bound LFM tool profile | **Secondary local GGUF provider**; independent test, no generic tool authority |
| P0 | [apple/coreai-models](https://github.com/apple/coreai-models) | **Core AI** model export, `.aimodel` resources | Official export recipes and Swift runtime; minimum iOS/macOS 27; example Qwen 3/3.5, model-specific tokenizers | **Core AI / Neural Engine candidate** |
| P0 | [john-rocky/coreai-kit](https://github.com/john-rocky/coreai-kit) ([quickstart](https://github.com/john-rocky/coreai-kit/blob/main/docs/GETTING_STARTED.md)) | Core AI Swift package; pinned model downloads and cache | `CoreAIKit` chooses platform bundle, supports FoundationModels integration; **real device** needed: Core AI unavailable in iOS simulator SDK, per project | Core AI physical-iPhone spike |
| P1 | [john-rocky/coreai-model-zoo](https://github.com/john-rocky/coreai-model-zoo) ([apps](https://github.com/john-rocky/coreai-model-zoo/blob/main/apps/README.md)) | Converted Qwen3.5, LFM, Gemma, VLM, and ASR models | Per-model conversion recipes and iOS 27 sample apps; publisher benchmark results are **device/profile-specific** | Model catalog and verification recipes, not runtime dependency |
| P1 | [huggingface/AnyLanguageModel](https://github.com/huggingface/AnyLanguageModel) | Multi-provider Swift abstraction; optional MLX/Core ML/llama traits | Shared Apple-like session API, but a **separate library/abstraction**, not synonymous with Apple's new native protocol | Compare; do **not** introduce a duplicate session abstraction by default |
| P1 | [no-problem-dev/swift-llm-local](https://github.com/no-problem-dev/swift-llm-local) | MLX on-device Qwen/Gemma/Llama; model presets, memory/LoRA | iOS 18+ app/library **compatible with** iOS 27; not verified as native iOS27 `LanguageModel` conformer. Per-model tool support, pressure unload, one loaded model at a time | Borrow lifecycle/memory tests, avoid duplicate client layer |
| P1 | [Jflick58/resident](https://github.com/Jflick58/resident) | MLX, local agent, MCP, FluidAudio | Source demonstrates local on-phone agent harness; **not** a known native iOS-27 provider conformer; tool calls currently reach write tools without an iGentic approval capability | Study selective tool discovery/context; NEVER copy direct model-to-write trust |
| P1 | [a-ghorbani/pocketpal-ai](https://github.com/a-ghorbani/pocketpal-ai) | React Native `llama.rn` → llama.cpp GGUF; Whisper | Mature downloadable local phone app, supports model management and offline chat; **not** a native Apple `LanguageModel` bridge | Best GGUF UX/reference for download, cancel, model switching |
| P1 | [luckeyfaraday/local-models](https://github.com/luckeyfaraday/local-models) | Native Swift llama.cpp, Metal, GGUF with image/audio projector | In-app import/download; author reports physical iPhone 13 Pro running LFM3; **compatible** with iOS 27, not an iOS27-only provider | GGUF import and multimodal UX benchmark |
| P1 | [JaviChulvi/hermit](https://github.com/JaviChulvi/hermit) | MLX Gemma 4 E2B + local embeddings | Local PDF RAG, unload embedding model before loading text model, monitor memory | RAG architecture and finite memory budget |
| P1 | [Reezxy/Local-Ai-Vision-App](https://github.com/Reezxy/Local-Ai-Vision-App) | MLX SmolVLM2, whisper.cpp, Kokoro | Photo-per-query and voice chain; iOS 18+ compatible, not iOS27-specific | Vision/voice modular protocol reference |
| Watch | [simonmaddox/foundation-models-byo-model](https://github.com/simonmaddox/foundation-models-byo-model) | GGUF or Core ML behind native session | Direct iOS 27 protocol implementation, author candid about ANE bottlenecks | Compare conformance/edge cases against official MLX and SwiftLlama |
| Watch | [pytorch/executorch](https://github.com/pytorch/executorch) | PyTorch exported `.pte`, C++ and Swift/ObjC glue | iOS runtime examples, different tooling/export costs; **not** native 27 integration by itself | Fallback framework if specific model unavailable in MLX/GGUF/Core AI |
| Watch | [kilianbalaguer/Voltaire](https://github.com/kilianbalaguer/Voltaire) | Swift MLX, downloadable Qwen/LFM/Gemma etc. | iOS 26+ compatible with 27; **source-available license forbids derivative/commercial reuse** | Learn publicly documented behavior only; no code copy |

**Also useful previous projects:** [FluidAudio](https://github.com/FluidInference/FluidAudio) for fully local ASR/VAD (Core ML models, separate LLM inference), [Pocket Agent](https://github.com/meshoklv/pocket-agent) for approval-before-file-write UI, and [iCTRL](https://github.com/OpenMinis/iCTRL) for a *separate* developer-device UI automation experiment. They are **not interchangeable model runtimes**.

## Two direct iOS 27 code patterns (illustrative upstream API, not integrated)

**MLX provider** from the first-party MLX documentation:

```swift
import Foundation
import FoundationModels
import HuggingFace
import MLXFoundationModels
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

// Xcode 27 / iOS 27. Illustration ONLY: the macro may download weights.
// It does NOT enforce iGentic's pinned-commit/verified-asset admission.
let model = #huggingFaceLanguageModel(
    configuration: LLMRegistry.qwen3_0_6b_4bit,
    capabilities: [.reasoning]
)
let session = LanguageModelSession(model: model)
let response = try await session.respond(to: "Fasse diese öffentliche Notiz zusammen.")
// Model output remains untrusted data; it is not an execution approval.
```

**GGUF provider** from swift-llama-cpp:

```swift
import FoundationModels
import SwiftLlama

// Requires iOS 27 SDK/Swift 6.4; modelURL must refer to a
// locally admitted, immutable SHA-256-verified GGUF file.
let model = LlamaLanguageModel(modelURL: modelURL)
let session = LanguageModelSession(model: model)
let response = try await session.respond(to: "Erkläre diesen öffentlichen Begriff.")
await model.unload()
```

**Important: the MLX `#huggingFaceLanguageModel` macro synthesizes its own downloader/tokenizer loading and does not itself enforce iGentic's immutable model-admission policy. Production integration MUST instead use `MLXLanguageModel`'s direct `weightsLocation:` / `load:` initializer with only previously verified on-disk assets, no network fallback.** See [upstream direct initializer and default trait details](https://github.com/ml-explore/mlx-swift-lm/blob/main/Libraries/MLXFoundationModels/README.md).\n\nThe two examples are **not pasted application-ready code**: each requires SwiftPM products, a physical device build, a model asset, license clearance, actor isolation/cancellation and platform capability checks. Tool-call safety belongs **above** both model implementations.

## Recommended initial model matrix (candidates, not iGentic benchmarks)

| Candidate | Expected fit / purpose | Model-specific proof required |
| --- | --- | --- |
| Qwen3 0.6B 4-bit | Small downloadable bootstrap; cheap structured public requests | German output and tool-call/JSON quality, context and model revision |
| Qwen3.5 0.8B or 2B quantized | Next text/agent proposal tier; MLX and Core AI variants exist | Exact backend format, tokenizer compatibility, realistic memory/TTFT |
| LFM2.5 1.2B or LFM3 1.7B quantized | Alternate small local GGUF; swift-llama has qualified profiles for specific exact hashes | Do not elevate unqualified GGUF to tool-capable based on filename |
| Qwen3-VL 2B / LFM VLM (quantized) | Optional image analysis later | Images stay local; memory and multimodal projector assets |
| Gemma 4 E2B quantized | RAG and alternative comparison | Gemma-specific use license, actual iPhone footprint |

Important: **download size ≠ inference RAM** (weights + KV cache + active memory + tokenizer + OS overhead). No published tokens/second value is portable across iPhone hardware, quantization, prompt length, thermals or build. **Model family and weight license must be checked per exact published artifact**. A new iOS system release does not change hardware memory.

## Integration into iGentic, minimal sequence

1. **Keep user mandate:** [iOS27 migration PR #389](https://github.com/pokekarten/igentic-iphone/pull/389) sets Swift tools 6.2, iOS min 27, Xcode 27 runner. **Provider `swift-llama-cpp` specifically reports needing Swift 6.4**: use Xcode27 Swift 6.4/compiler in its integration spike, validate manifest/toolchain compatibility instead of assuming tools 6.2 guarantees it.
2. **Protect the safety kernel:** after [#381 proposal gate](https://github.com/pokekarten/igentic-iphone/pull/381) and existing [#383/#385](https://github.com/pokekarten/igentic-iphone/pull/385) immutable model admission, add one adapter conforming to our existing `LocalModelRuntime` metadata and capability structure. A model's `LanguageModelSession` tool callback must **never** bypass `PolicyEngine`, one-shot approval and `AuditLog`.
3. **First provider: native MLXFoundationModels**, an exact pinned Qwen3-0.6B-4bit bundle from Hugging Face. Opt-in explicit download, pinned commit and per-file SHA-256, authenticated/staged storage, validate model/tokenizer files, refuse symlinks and incomplete transfers, explicit network/offline state. Do not invent model hashes or auto-connect a cloud API.
4. **Second provider: pinned GGUF SwiftLlama**, native iOS 27 bridge. Test with `LanguageModelSession` both for text and synthetic structured proposals; qualify tool profiles *per exact weight and parser revision*. On cancellation, do not assume a C decode interrupt is immediate.
5. **Third provider: CoreAIKit/CoreAI** using a published exact model recipe and `.aimodel` model bundle. **Real iOS 27 device** required for actual Core AI execution; simulator can only validate independent UI/policy code.
6. **Acceptance:** record real device model, iOS/Xcode/compiler, package and model versions and hashes, download size vs memory used, first-token latency, decode speed, peak memory, heat/battery over repeated runs, German prompts, structured JSON/tool-call score, failed/unknown tool and off-device network guard tests. Never claim those numbers until measured.

**Source priority:** Apple WWDC26 and Apple Core AI reference for SDK/API contracts; first-party MLX package for native adapter; pinned swift-llama-cpp and CoreAIKit for implementation; local app READMEs for UX/field reports. None of this is a physical iGentic acceptance.
