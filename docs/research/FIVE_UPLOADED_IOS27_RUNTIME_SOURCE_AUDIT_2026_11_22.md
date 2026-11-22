# Five uploaded iOS 27 runtime archives — source audit (2026-11-22)

**Scope / proof level:** Five user-uploaded snapshot ZIP archives, **4,897 files** total: 1,974 Swift, 1,132 Python, and 428 JSON/Plist. Every file was SHA-256 inventoried; ZIP CRC checked; all Python AST and JSON/Plist parsed; 1,974 Swift files run through Linux Swift **6.2.1** source parse; all five SwiftPM manifests passed `swift package dump-package`. Source review focused on actual model/runtime/tool/storage/security implementation. **No Xcode 27 full typecheck, model download, real iPhone inference, or physical-device proof.** Additional earlier source triage covers 2,546 files from seven other distinct archives (12 upstream repos / 7,443 inventoried source files in all). Previous triage is heuristic rather than a line-by-line semantic verification.

## Repo-by-repo findings

| Upstream | Files | Implemented and suitable | Required admission gates |
| --- | ---: | --- | --- |
| [apple/coreai-models](https://github.com/apple/coreai-models) | 834 | Official iOS/macOS 27 Core AI `.aimodel` converter and Swift LLM/vision/speech/runtime libraries (BSD-3) | Weight conversion/quality, architecture and tokenizer verification, genuine iOS27 device |
| [john-rocky/coreai-model-zoo](https://github.com/john-rocky/coreai-model-zoo) | 2283 | Catalog/recipes and dozens of iOS27 demo apps, chat/agent/vision/audio (BSD-3) | The `swift/` package explicitly requires an extra **local patched** `../coreai-models` checkout; standalone ZIP `swift package resolve` FAILED with missing-folder error. Avoid copying direct EventKit-writing agent tools |
| [john-rocky/coreai-kit](https://github.com/john-rocky/coreai-kit) | 844 | CoreAIKit ModelStore/Catalog/ChatSession/embeddings/speech/vision (BSD-3); integrates **fork** `john-rocky/coreai-models@0.2.9-zoo` not Apple main | Reject silent sibling-revision fallback and mutable `main` model identities. Confirm syntax issue with Xcode27 compiler before importing |
| [pgorzelany/swift-llama-cpp](https://github.com/pgorzelany/swift-llama-cpp) | 118 | GGUF+Metal via pinned llama.cpp b11960 XCFramework; SHA-qualified LFM tool profiles; iOS27 `LlamaLanguageModel` adapter (MIT) | FoundationModels bridge is compiler >=6.4 only; simulator slices need project script; never trust arbitrary GGUF as tool-capable |
| [ml-explore/mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) | 818 | MLX native LLM/VLM runtime, guided generation, tool parsing, iOS27 `MLXFoundationModels` adapter (MIT) | Pin 3.x dependency and HF weights; supply pre-verified local weight directory/loader instead of macro downloader; deny unknown tool modes |

## Explicit test results and implementation blockers

1. **Swift parsing:** 1,972/1,974 files parse with the default Linux Swift 6.2.1 invocation. [MiniCPMDialect.swift (upstream)](https://github.com/john-rocky/coreai-model-zoo/blob/main/swift/Sources/ZooFMProvider/MiniCPMDialect.swift) **passes** when supplying `-enable-bare-slash-regex`; the extra lexer option is required for this standalone parsing method. Thus **1,973/1,974 parse** with the appropriate option.
2. **CoreAIKit parse blocker** `Sources/CoreAIKit/Decide/TypedDecisions.swift:890–893`: `state.withLock { defer { $0.nextTicket += 1 }; return $0.nextTicket }` is rejected by Swift 6.2.1 as an anonymous closure argument in the `defer` block. Minimal tested syntax remedy: change closure to `state.withLock { state in defer { state.nextTicket += 1 }; return state.nextTicket }`. The exact source still exists upstream on GitHub as of 2026-11-22. **Compiler 6.4 / Xcode27 behavior is not yet tested**; do not describe as a confirmed Apple SDK build failure.
3. **CoreAIKit model identity:** `Sources/CoreAIKitCore/ModelID.swift:17` defaults revision to `main`; `ModelStore.swift:95–145` explicitly falls back to a **cached sibling revision** when the network is unavailable; `ModelStore.swift:231–235` checks size, not SHA-256. These may be valid app UX choices but violate iGentic's immutable model admission.
4. **Zoo model and actions:** `apps/AppShared/ModelDownloader.swift:193–212` resumes range chunks from a bitmap without final cryptographic file hash verified in that downloader. `apps/CoreAIAgent/Sources/Tools.swift:118–141` creates EventKit reminders after OS permission without an iGentic one-time action approval. **Do not copy** tool implementations directly into our action path.
5. **MLX model and tool status:** `Libraries/MLXFoundationModels/MLXLanguageModel+Availability.swift:173–184` uses only `config.json` presence to report `.available`, with an explicitly documented partial-download false positive. `ToolCalling/ToolCallingModeResolution.swift:20–30` treats an **unknown** future mode as `allowed` (`@unknown default: return true`). Our PolicyEngine must force disallowed on unknown state.
6. **Separate release families:** `coreai-model-zoo` requires a patched local `coreai-models`; `coreai-kit` pins `john-rocky/coreai-models@0.2.9-zoo`; the uploaded official `apple/coreai-models` is **not** interchangeable. Maintain exact dependency graph and checksums.

## iGentic integration and actual status

**Direct current-source comparison:** `main` still declares Swift tools 6.0 / iOS17, while the existing [iOS27 migration Draft PR #389](https://github.com/pokekarten/igentic-iphone/pull/389) declares tools 6.2 / iOS27 and already passed macOS+Linux Swift package tests, Xcode27 Foundation host build, iOS27 simulator smoke, actionlint and structure checks. **CodeQL check on PR #389 remains failed**, so it is not ready to merge.

**Recommended implementation order:**
1. Resolve PR #389's security check before merging; preserve all main/stacked Draft PR separation.
2. Reuse existing [pinned model admission PR #383](https://github.com/pokekarten/igentic-iphone/pull/383) and [GGUF SHA/symlink gate #385](https://github.com/pokekarten/igentic-iphone/pull/385), plus model-proposal policy. Do not add a second competing policy subsystem.
3. First provider: iOS27 `MLXFoundationModels.MLXLanguageModel` + model Qwen3-0.6B-4bit; configure **only a verified, exact-revision local directory** via the direct `weightsLocation:`/`load:` initializer, never mutable Hub `main` or silent networking. Start with text/synthetic proposals, tool calls **disabled**.
4. Second provider: SwiftLlama `LlamaLanguageModel` with explicit SHA-approved GGUF and per-model capability tests.
5. Third provider: Apple Core AI and a verified `.aimodel` bundle, on a **physical iPhone running iOS27**; compare same task/quantization/memory/first-token latency.
6. All generated tool calls remain **untrusted proposals**; only `PolicyEngine → ApprovalManager → one-shot capability ledger → AuditLog` may authorize execution. Unknown tools/modes, partial files, missing hashes and cancellations fail closed.

**Files in the user's downloadable offline audit pack:** 4,897-row SHA-256 inventory, Swift/Python/JSON-Plist parse logs, full ZIP SHA-256 manifest, detailed German findings, and one preview-only CoreAIKit syntax patch. The report does **not** assert full typechecking or physical-device tests.
