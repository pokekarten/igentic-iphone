# iGentic iPhone — comparative capability gap audit
**Date:** 2026-11-23
**Project source reviewed:** `pokekarten/igentic-iphone`, development HEAD `372e50a` (draft PR #403, stacked on #402); **not** current `main`.
**Research input:** [Atlas PR #379](https://github.com/pokekarten/igentic-iphone/pull/379) (the atlas file is on that PR's branch, not in this stacked PR), assembled on 2026-11-21/22.
**Corpus:** 99 GitHub URL identities explicitly in the atlas (**98 external upstreams + iGentic**), plus **9 additional external projects in its cross-reference inventory** = **107 external references total**. Entries may be prior README claims, not new individual source-code audits or real-device tests. Selected high-priority upstreams were separately rechecked via current GitHub README and official product documentation on 2026-11-23.

## Executive conclusion

iGentic already contains a non-trivial *governance and safety kernel*:
`PolicyEngine`, `ApprovalManager`, `ToolRegistry`, `TaskRouter`,
`MemoryStore`, model admission/selection scaffolding, user-reviewed
EventKit reminder workflow, a native read-only App Intent, and independently
scoped first-party Mac CoreDevice own-app launch/observation. PR #403 additionally
adds an on-device text editor, user-triggered AVFoundation speech, selected-photo
Vision OCR and two *read-only/offline* portable and stdio MCP tools.

**These components do not yet form a full autonomous iPhone agent.** In
`AgentKernel.handle`, the registry is consulted to validate a routed tool
name; there is no generic tool-execution/model-feedback loop there. The
`MemoryStore` uses in-memory `LockedBox` state, not crash-resilient SQLite.
The native app has neither an unrestricted iOS shell nor a real cross-app AX/
HID controller, and the portable MCP gateway cannot contact a physical iPhone.
The newly added `iphone_prepare_local_task` is a manual handoff, *not*
an execution confirmation. These distinctions must remain visible in all
product/status communication.

Previous evidence from the Mac includes Xcode 27.2 successful simulator
build, **53 pass / 0 fail / 1 skip** in the PR #403 Node/MCP test suite,
and a read-only physical Wi-Fi CoreDevice tunnel plus a running *previously
installed* iGentic app. It does **not** demonstrate that the new iOS build is
signed/installed on the physical iPhone, nor physical cross-app UI control,
mobile-data remote control, or ChatGPT iOS plugin registration.

## Ranked gaps that should actually change the product

| Priority | Capability we lack | Reference mechanisms to compare | First deliverable / acceptance criterion |
| --- | --- | --- | --- |
| P0 | **Phone-local, bounded model → tool → observation loop** | [loopl](https://github.com/cagataycali/loopl), [Resident](https://github.com/Jflick58/resident), [PhoneAgent](https://github.com/rounak/PhoneAgent) | Execute 2–3 **synthetic own-app** steps with typed tool allowlist, budget, independent verification and no implicit mutation privileges; no Mac or provider assumed |
| P0 | **Durable state and interrupted task recovery** | [PiDurableKit](https://github.com/finnvoor/PiDurableKit), [DurableAgents](https://github.com/Think-Define-Create/DurableAgents) | SQLite journal, stable task and effect IDs, encrypted private storage, crash/reboot test; an uncertain external write remains `unknownOutcome` and is never blindly replayed |
| P0 | **Usable voice input and full conversation** | [FluidAudio](https://github.com/FluidInference/FluidAudio), [Volocal](https://github.com/fikrikarim/volocal), [Argmax/WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) | On-phone German ASR + VAD + interruption; measure latency/RAM/battery on iPhone Air. Existing text-to-speech alone does not qualify |
| P0 | **Safe on-device workspace and code/file tools** | [OpenMinis](https://github.com/OpenMinis/OpenMinis), [Pocket Agent](https://github.com/meshoklv/pocket-agent), [just-bash-swift](https://github.com/mweinbach/just-bash-swift) | User-selected workspace, bounded virtual filesystem, preview/diff-before-write, deny/apply tests; never confuse sandboxed shell with iOS system shell |
| P0 | **One consistent native action catalog** | [Apple App Intents](https://developer.apple.com/documentation/appintents), [AirMCP](https://github.com/heznpc/AirMCP), [FoundationModelsKit](https://github.com/rryam/FoundationModelsKit) | Typed read-only diagnostics + user-approved reminder + other independently admitted app-scoped intents; stable schemas used by Shortcuts and MCP without duplicating authorization |
| P0 | **End-to-end ChatGPT/custom MCP reachability** | [OpenAI connect plugin guide](https://developers.openai.com/plugins/deploy/connect-chatgpt), [custom MCP server](https://developers.openai.com/api/docs/guides/custom-mcp-server) | Authorized hosted or private authenticated connection; real invocation in permitted ChatGPT client; scope, revocation, receipts and no public unauthenticated device-control endpoint |
| P0 research, separate developer lane | **Real screen observation/tap/type across apps** | [iCTRL](https://github.com/OpenMinis/iCTRL), [Poki](https://github.com/JosssphZhou/poki), [iphone-use-app](https://github.com/EliotAndres/iphone-use-app), [Eiscue](https://github.com/LLLLLayer/Eiscue), [ipb](https://github.com/ipbtools/ipb) | Compare one authorized synthetic app on disposable device, real iOS 27, owner approval and fresh screen-bound execution receipts. Developer/private APIs & signing; **not App Store-general permission** |
| P1 | **Real independently measured small-model choices** | [Apple Core AI models](https://github.com/apple/coreai-models), [AnyLanguageModel](https://github.com/huggingface/AnyLanguageModel), [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm), [edge-llm-bench](https://github.com/john-rocky/edge-llm-bench) | One frozen task set with exact model artifact, quantization, local-only network proof, memory/jetsam, thermal and power data; fallback to manual task if model unavailable |
| P1 | **User-initiated background continuity** | [Apple BGContinuedProcessingTask](https://developer.apple.com/documentation/backgroundtasks/performing-long-running-tasks-on-ios-and-ipados), [Eiscue](https://github.com/LLLLLayer/Eiscue) | One foreground-started bounded task survives permitted background transitions or honestly pauses; no always-on iOS daemon claims |
| P1 | **Reproducible agent quality benchmark and replay** | [iOSWorld](https://github.com/ljang0/iOSWorld), [AppControlBench](https://github.com/software-mansion/app-control-bench), [agent-device](https://github.com/callstack/agent-device) | Deterministic suite with per-step evidence, cancellations, denied actions and failure labels; physical-phone success separately measured |
| P2 | **Reverse control: iPhone supervises Mac coding agents** | [PocketCtl](https://github.com/pocketctl/pocketctl), [CC Pocket](https://github.com/K9i-0/ccpocket) | Optional companion for viewing Codex/task status on iPhone; explicitly distinct from phone-autonomous execution |

## Core architecture recommendation: no required third-party tool

1. Keep `AgentCore` and Swift policy/approval/receipt types as the **single authority**; model output and external tool instructions are untrusted inputs.
2. Add one **typed capability manifest** with separate states: `source-known`, `code-present`, `build-tested`, `simulator-tested`, `physical-device-tested`, `connected-in-ChatGPT`. Never collapse these into `available`.
3. Three independent execution lanes: **(A)** signed native app with first-party local tools, **(B)** approved Mac/CoreDevice lab, **(C)** separately opted-in on-phone developer automation. No silent route switching or credential sharing.
4. Own the minimum implementations: local edit/copy, speech, selected-image OCR, manual reminder, diagnostics, structured task journal, lightweight agent loop and virtual workspace. Provider backends remain opt-in extras, *not fake equivalences*.
5. Do not bundle AGPL/GPL/PolyForm, unusual/modified MIT, private Apple automation code or model weights before pinned-revision legal/security review. Do not run unreviewed upstream install scripts or expose developer endpoints on public networks.
6. An API, VPN, tunnel, model availability result or app-running process **never** proves an action was performed. Use separate end-to-end receipts for each route and stop on unclear outcomes.

## Evidence and limitations

- `plugins/iphone-connect/src/server.mjs`: 15 MCP tools on PR #403; tool catalog is *declarative*, not a real third-party installation checker.
- `plugins/iphone-connect/src/portable-gateway.mjs`: four read-only MCP tools, localhost only, no device session.
- `ios/Sources/AgentCore/AgentKernel.swift`, `ios/Sources/AgentCore/MemoryStore.swift`, and `ios/Sources/AgentCore/ToolRegistry.swift`: governance/routing scaffolding but no durable agent task loop or persistent memory.
- `ios/Sources/iGenticApp/OfflineToolsView.swift`: user-triggered TTS, editor and photo OCR; not yet physically accepted.
- `app/iGenticDiagnostics/iGenticDiagnostics/iGenticDiagnosticsApp.swift`: a fixed demonstration App Intent, not a general system-action surface.
- PRs [#378](https://github.com/pokekarten/igentic-iphone/pull/378), [#379](https://github.com/pokekarten/igentic-iphone/pull/379), [#394](https://github.com/pokekarten/igentic-iphone/pull/394), [#400](https://github.com/pokekarten/igentic-iphone/pull/400), [#401](https://github.com/pokekarten/igentic-iphone/pull/401), [#402](https://github.com/pokekarten/igentic-iphone/pull/402), [#403](https://github.com/pokekarten/igentic-iphone/pull/403) remain separately reviewable. Stacked code is **not yet released on main**.
- The following appendix categorizes **all 107 external identities (98 explicit upstream URLs plus 9 cross-reference-only projects)**, not a claim that each upstream was freshly built, run or source-audited today. More detailed per-project source notes and caveats reside in the atlas on PR #379.

## Appendix: full atlas-to-gap coverage (107 external repositories)

### Developer transport and QA infrastructure (4)

**iGentic gap:** Wider signed runner, WDA and multi-device infrastructure; native CoreDevice bridge is own-app-only.

| Project | Source-described functionality (not newly device-verified) |
| --- | --- |
| [appium/appium](https://github.com/appium/appium) | Cross-platform automation framework |
| [appium/WebDriverAgent](https://github.com/appium/WebDriverAgent) | XCTest/WDA HTTP device automation server |
| [danielpaulus/go-ios](https://github.com/danielpaulus/go-ios) | Apple-device connectivity, automation/tunneling utilities |
| [google/artemis](https://github.com/google/artemis) | Primarily Android end-to-end GUI agent and MCP; iOS driver work is still a separate integration candidate. |

### Evaluation and GUI research (8)

**iGentic gap:** External benchmark, long-horizon apps and independent pass-rate metrics beyond own-app fixtures.

| Project | Source-described functionality (not newly device-verified) |
| --- | --- |
| [ananasDDA/pocket-ai-lab](https://github.com/ananasDDA/pocket-ai-lab) | iOS 26+ runtime comparison of MLX, llama.cpp, Apple model and more; **actual process memory/jetsam budget** and Metal working-set reporting, live CPU/thermal diagnostics |
| [john-rocky/edge-llm-bench](https://github.com/john-rocky/edge-llm-bench) | Reproducible trial fixtures and raw result records for MLX, LiteRT-LM, llama.cpp, Core AI and others across real devices; preserves failures and avoids unsupported headline rankings |
| [ljang0/iOSWorld](https://github.com/ljang0/iOSWorld) | iOS simulator benchmark with 26 synthetic SwiftUI apps, one fictional profile and 133 tasks across app/multi-app settings |
| [software-mansion/app-control-bench](https://github.com/software-mansion/app-control-bench) | Reproducible model-versus-tool comparisons for real iOS apps **in simulator**; its November 2026 README explicitly states the new edition is **not run yet** |
| [Tongyi-MAI/MAI-UI](https://github.com/Tongyi-MAI/MAI-UI) | Mobile GUI model and evaluation research, with reported hybrid GUI/CLI and device benchmarks |
| [Tongyi-MAI/MobileWorld](https://github.com/Tongyi-MAI/MobileWorld) | Containerized Android tasks with deterministic back-end state verification and MCP + human-interaction flows; 201 tasks over 20 apps |
| [X-PLUG/MobileAgent](https://github.com/X-PLUG/MobileAgent) | Planning, reflection, GUI grounding, long-horizon task evaluation |
| [zai-org/Open-AutoGLM](https://github.com/zai-org/Open-AutoGLM) | Multimodal screen grounding, planning and human takeover; iOS setup guide exists |

### Harness, persistence and sandbox components (14)

**iGentic gap:** Durable loop, effect journal and isolated execution; current kernel routes metadata and memory is in-process.

| Project | Source-described functionality (not newly device-verified) |
| --- | --- |
| [abra-code/mlx-agent](https://github.com/abra-code/mlx-agent) | Swift MLX/Foundation backend, ACP over stdio, MCP permission gates and reproducible benchmark tools |
| [AkinoKaede/AgentKit](https://github.com/AkinoKaede/AgentKit) | Swift model/tool loop with explicit permissions and persistent conversation state |
| [apple/foundation-models-utilities](https://github.com/apple/foundation-models-utilities) | Official Swift skills, context transformations, rolling history and Chat Completions-based provider adapters |
| [christopherkarani/Swarm](https://github.com/christopherkarani/Swarm) | Swift 6.2 agent runtime, typed tools, streaming, memory and backend adapters, including Linux test fixtures |
| [dsaad68/deepagents-swift](https://github.com/dsaad68/deepagents-swift) | Middleware, ReAct, MCP, lazy tool discovery, optional MLX adapter |
| [finnvoor/PiDurableKit](https://github.com/finnvoor/PiDurableKit) | Swift API to a JavaScriptCore agent harness; SQLite or JSONL persistence, durable tasks/subagents, tool events and restart recovery; iOS 17+ claimed |
| [mweinbach/just-bash-swift](https://github.com/mweinbach/just-bash-swift) | In-process Swift shell interpreter with **virtual in-memory filesystem**, designed where iOS forbids ordinary subprocess execution |
| [mzbac/SwiftAgent](https://github.com/mzbac/SwiftAgent) | Qwen3/MLX, MCP and tool-calling in Swift; README advertises iOS 16+ |
| [rryam/FoundationModelsKit](https://github.com/rryam/FoundationModelsKit) | Swift Apple Foundation Models tool-loop guardrails, structured generation, per-turn budgets, EventKit mutation receipts and unknown-outcome handling. |
| [rudrankriyam/FoundationModelsAgent](https://github.com/rudrankriyam/FoundationModelsAgent) | Native Swift `LanguageModel` harness with action policy, receipts, budgets, checkpoints and memory options |
| [sabby3861/Arbiter](https://github.com/sabby3861/Arbiter) | Unified Swift provider routing between Apple/on-device and cloud, explicit upstream feature-status claims |
| [SpaceCorps/open-apple-models](https://github.com/SpaceCorps/open-apple-models) | Swift tool-loop and structured tool policies around Apple Foundation Models |
| [Think-Define-Create/DurableAgents](https://github.com/Think-Define-Create/DurableAgents) | Swift event journal, typed effect classification (`pure`, `idempotent`, `transactional`, `external`), approval-resume tokens, optional encryption |
| [Tom-Ryder/AgentRunKit](https://github.com/Tom-Ryder/AgentRunKit) | Typed Swift tool contracts, streaming, MCP and optional MLX support |

### Host device adapters (23)

**iGentic gap:** General AX/screenshot/tap/swipe/typing; our adapter deliberately scopes operations to the own app. Requires Mac/host.

| Project | Source-described functionality (not newly device-verified) |
| --- | --- |
| [appium/appium-mcp](https://github.com/appium/appium-mcp) | AI-facing MCP atop iOS XCUITest and Android automation |
| [Array-Ventures/open-phone](https://github.com/Array-Ventures/open-phone) | Mac USB capture, Bluetooth HID, local MCP/API |
| [blitzdotdev/iPhone-mcp](https://github.com/blitzdotdev/iPhone-mcp) | Mac-hosted MCP for real iPhone/simulator with WDA |
| [callstack/agent-device](https://github.com/callstack/agent-device) | Device CLI, stdio MCP, typed Node API, accessibility snapshots; iOS simulators and physical iPhones |
| [carrotciallo/poki-for-linux](https://github.com/carrotciallo/poki-for-linux) | Unofficial Linux-host adaptation of Poki using Rust idevice and Node MCP, USB and RemoteXPC. |
| [ChrisThoma/ios-device-mcp](https://github.com/ChrisThoma/ios-device-mcp) | Mac USB/Xcode device test server + persistent XCUITest runner, structured MCP tools |
| [Derrors/iphone-control](https://github.com/Derrors/iphone-control) | Rust binary on **Linux or Mac**, native iOS-27 services or WDA route for iOS 17–26 |
| [ghosthand-dev/ghosthand](https://github.com/ghosthand-dev/ghosthand) | Mac-based USB capture + Bluetooth HID/AssistiveTouch, OCR and device leases |
| [hughlee824/iphone-use](https://github.com/hughlee824/iphone-use) | Mac CLI for an AI client to operate real iPhone; source describes standard and runner modes |
| [HyunSeob/iphone-cli](https://github.com/HyunSeob/iphone-cli) | Rust CLI + MCP + scripting; claims direct physical-iPhone accessibility/input without Xcode/WDA on **iOS 27+** |
| [ipbtools/ipb](https://github.com/ipbtools/ipb) | macOS-hosted iOS 27 CoreDevice **private HID/AX services**: native UI tree, taps, screen stream, MCP, no on-phone XCTest runner |
| [jkcoxson/devicehub_rs](https://github.com/jkcoxson/devicehub_rs) | Rust-based CoreDevice display and HID service bridge, GUI, MCP and VNC; requires separate network/authentication review. |
| [leeguooooo/iphone-use](https://github.com/leeguooooo/iphone-use) | Mac daemon + iPhone XCTest runner; iOS 15+ claimed, settled UI observations, single-device leases and replayable flows |
| [mharizanov/iphone-agent](https://github.com/mharizanov/iphone-agent) | WDA + go-ios with MCP and high-risk-action confirmation heuristics |
| [mobile-next/mobile-mcp](https://github.com/mobile-next/mobile-mcp) | MCP tool server for iOS + Android, simulator and physical devices; accessibility-first where available |
| [mobile-next/mobilecli](https://github.com/mobile-next/mobilecli) | Underlying cross-platform device CLI; real-iPhone agent installation needs Apple provisioning/signing |
| [mobiumdev/mobium](https://github.com/mobiumdev/mobium) | Go CLI/MCP for Android/iOS simulators and physical iPhones, structured UI refs, diagnostics and test recording |
| [niklas-schmidt-dev/mobdev](https://github.com/niklas-schmidt-dev/mobdev) | Native Mac GUI + MCP/CLI, USB/runner iPhone input; README also describes Bluetooth HID option |
| [phoneuse-official/phoneuse](https://github.com/phoneuse-official/phoneuse) | USB/Mac/WebDriverAgent, local viewer, REST and MCP |
| [semsturgut/open-iphone-use](https://github.com/semsturgut/open-iphone-use) | Mac MCP using CoreDevice real-iPhone capture/input. Current default requires **Xcode/iOS 27**; README documents old `v0.0.3` Bluetooth/older-iOS fallback |
| [timurcatakli/thumbly](https://github.com/timurcatakli/thumbly) | macOS CoreDevice iPhone controller with explicit client approval, activity history, stop control and MCP/remote integration |
| [UgeeCodes/iOS-agent-bridge](https://github.com/UgeeCodes/iOS-agent-bridge) | Host MCP and iOS 17+ WebDriverAgent/XCTest with CoreDevice tunnel recovery |
| [WaziXuan/iospilot](https://github.com/WaziXuan/iospilot) | Mac-hosted Python MCP using iOS 27+ CoreDevice accessibility, HID input and screen settling. |

### Hybrid phone/host agent products (3)

**iGentic gap:** Broad human takeover, mirrored-device monitoring and model-to-action UX.

| Project | Source-described functionality (not newly device-verified) |
| --- | --- |
| [DIYgod/pinky](https://github.com/DIYgod/pinky) | Desktop MCP/agent plus an **on-phone app**; project says iOS 17.4+ with helper/runner on older OS, iOS 27 has another route. Gateway implements permission prompts, blocked apps and human takeover. |
| [imsai-sh/fish-pocket](https://github.com/imsai-sh/fish-pocket) | Native SwiftUI phone agent app with tasks, local calendar/reminders/etc. and optional **iCTRL** bridge for other-app UI |
| [rounak/PhoneAgent](https://github.com/rounak/PhoneAgent) | Experimental SwiftUI in-app agent, XCTest-hosted action path, and Codex/OpenClaw RPC bridge for iOS/Android |

### Inference engines and provider adapters (14)

**iGentic gap:** Production-ready physical iPhone open-weight runtimes and reproducible memory/thermal/model evidence.

| Project | Source-described functionality (not newly device-verified) |
| --- | --- |
| [anthropics/ClaudeForFoundationModels](https://github.com/anthropics/ClaudeForFoundationModels) | Official Anthropic Swift adapter to Apple's `LanguageModel` protocol |
| [apple/coreai-models](https://github.com/apple/coreai-models) | Official Python export recipes and Swift on-device runtime utilities |
| [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) | GGUF inference and Metal backend |
| [huggingface/AnyLanguageModel](https://github.com/huggingface/AnyLanguageModel) | Swift model-provider interface resembling Foundation Models; supports multiple backends |
| [huggingface/swift-transformers](https://github.com/huggingface/swift-transformers) | Tokenization and model utilities in Swift |
| [john-rocky/coreai-kit](https://github.com/john-rocky/coreai-kit) | iOS 27 Swift runtime for Core AI chat, speech and vision with model downloads, caching and Foundation Models integration. |
| [ml-explore/mlx-swift](https://github.com/ml-explore/mlx-swift) | Apple Silicon compute primitives |
| [ml-explore/mlx-swift-examples](https://github.com/ml-explore/mlx-swift-examples) | Example Swift apps and experiments |
| [ml-explore/mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) | Swift LLM/VLM, guided generation, MLX/Apple model bridging |
| [mlc-ai/mlc-llm](https://github.com/mlc-ai/mlc-llm) | Deploy LLM runtimes to mobile and other targets |
| [no-problem-dev/swift-llm-local](https://github.com/no-problem-dev/swift-llm-local) | Swift MLX local inference, per-model tool capability, model download/memory management, agent-client adapter |
| [pgorzelany/swift-llama-cpp](https://github.com/pgorzelany/swift-llama-cpp) | Swift package wrapper around llama.cpp for native iOS model inference. |
| [pytorch/executorch](https://github.com/pytorch/executorch) | Edge model inference runtime |
| [simonmaddox/foundation-models-byo-model](https://github.com/simonmaddox/foundation-models-byo-model) | Bring your own model to iOS 27 Foundation Models with Core ML/llama.cpp backends. |

### Model and local-app UX references (6)

**iGentic gap:** Polished offline model downloads/cache, multimodal and model-picker UX; current iGentic is not a general local model catalog.

| Project | Source-described functionality (not newly device-verified) |
| --- | --- |
| [a-ghorbani/pocketpal-ai](https://github.com/a-ghorbani/pocketpal-ai) | Phone-local LLM chat application, local model download and use. |
| [javichulvi/hermit](https://github.com/javichulvi/hermit) | Local model/assistant interface reference; verify current platform and model support before adoption. |
| [john-rocky/coreai-model-zoo](https://github.com/john-rocky/coreai-model-zoo) | Downloadable Core AI model catalog, conversion recipes, source-vs-export validation and Swift examples. |
| [kilianbalaguer/voltaire](https://github.com/kilianbalaguer/voltaire) | Local MLX model app for iPhone/iPad/Mac; check source and redistribution limitations. |
| [luckeyfaraday/local-models](https://github.com/luckeyfaraday/local-models) | Local model application/UX and model selection reference. |
| [reezxy/local-ai-vision-app](https://github.com/reezxy/local-ai-vision-app) | Swift/Metal fully local vision app example. |

### Native agent/workspace products (12)

**iGentic gap:** Complete on-phone agent/planner, shared file workspace and persistent context beyond diagnostic/offline utilities.

| Project | Source-described functionality (not newly device-verified) |
| --- | --- |
| [cagataycali/loopl](https://github.com/cagataycali/loopl) | Native Swift agent loop; MLX, llama.cpp, Apple Foundation Models; device tools and human approval |
| [dannote/pi-ios](https://github.com/dannote/pi-ios) | Native iOS Bun/JavaScript + terminal wrapper around a Pi coding agent and local file tools |
| [everettjf/dsh-ios](https://github.com/everettjf/dsh-ios) | Native wrapper around iSH Linux userspace and a coding-agent harness on iPhone/iPad |
| [isaced/pokeet](https://github.com/isaced/pokeet) | Phone-native coding agent that reads/edits/tests/commits within its own workspace; public TestFlight and early development |
| [Jflick58/resident](https://github.com/Jflick58/resident) | SwiftUI **locally running MLX model agent**, tools, skills, memory, MCP/OAuth connectors; lazy tool/schema loading |
| [JiangNanGenius/floe-agent](https://github.com/JiangNanGenius/floe-agent) | iOS 26+ on-device workspace with files and a Linux environment, plus cross-device workflows |
| [Maximoff19/makima](https://github.com/Maximoff19/makima) | SwiftUI personal assistant with voice/memory/calendar UI and self-hosted FastAPI/LLM gateway |
| [meshoklv/pocket-agent](https://github.com/meshoklv/pocket-agent) | iPhone-local Gemma/LiteRT-LM coding agent: reads a user-selected folder and proposes before/after diffs with explicit **Apply** |
| [off-grid-ai/OGAM](https://github.com/off-grid-ai/OGAM) | On-device GGUF, multimodal, local tools, knowledge base, optional offline speech and image generation |
| [OpenMinis/OpenMinis](https://github.com/OpenMinis/OpenMinis) | Native iOS agent shell with **on-device Alpine/iSH Linux sandbox**, skills, persistent memory and optional external providers |
| [sandeepvijayarao09/Anu-iOS](https://github.com/sandeepvijayarao09/Anu-iOS) | Experimental voice-first local iPhone assistant, Gemma/LiteRT, on-device intent/model routing and optional cloud fallback |
| [trufae/pmai](https://github.com/trufae/pmai) | Swift agent core shared across terminal/phone, Apple local models and optional encrypted workstation pairing |

### Out-of-target architecture references (2)

**iGentic gap:** Extra hardware or Mac-only Accessibility; research-only, not a production dependency.

| Project | Source-described functionality (not newly device-verified) |
| --- | --- |
| [FluidInference/FluidUse](https://github.com/FluidInference/FluidUse) | Small Core ML decision model drives form filling via **macOS Accessibility**, not iPhone APIs |
| [Kastarter/phone-agent](https://github.com/Kastarter/phone-agent) | On-phone planner + **ESP32-S3 Bluetooth HID dongle** for UI input, source claims iOS 27 end-to-end |

### Phone-resident cross-app experiments (6)

**iGentic gap:** Developer-mode, phone-hosted UI automation; unavailable in iGentic and not a general App Store API.

| Project | Source-described functionality (not newly device-verified) |
| --- | --- |
| [EliotAndres/iphone-use-app](https://github.com/EliotAndres/iphone-use-app) | Swift/Rust on-iPhone screenshot → vision-model → actions via CoreDevice and a loopback VPN; claims **iOS 26+** and **no Mac during operation** after pairing |
| [JosssphZhou/poki](https://github.com/JosssphZhou/poki) | Native iPhone agent; claims on-phone cross-app actions after one-time Mac/Windows setup, then no running Mac; iOS 18+ in README |
| [LLLLLayer/Eiscue](https://github.com/LLLLLayer/Eiscue) | iPhone-resident screenshot-to-vision-to-action agent; one-use frame binding, uncertain-result handling and optional continued-background tasks. |
| [OpenMinis/iCTRL](https://github.com/OpenMinis/iCTRL) | Phone-hosted XCTest service with **encrypted X25519/HMAC pairing**, JSON-RPC and discovery; README describes on-phone Developer Disk Image mounting and optional Mac-free operation |
| [Raynan00/cell-use](https://github.com/Raynan00/cell-use) | Swift API for phone-on-phone screenshots/taps/swipes with embedded tunnel and phone-control runtime |
| [Turbo1123/roubao](https://github.com/Turbo1123/roubao) | Swift/Rust iPhone-resident agent derived from iphone-use-app, loopback VPN bridge, resumable task UX and manual consent. |

### Public action and shortcut bridges (4)

**iGentic gap:** Full typed App Intents/Shortcuts catalog, permission separation and shared policy for each action.

| Project | Source-described functionality (not newly device-verified) |
| --- | --- |
| [heznpc/AirMCP](https://github.com/heznpc/AirMCP) | Governed Mac-app MCP tools, with an **iOS runtime described as preview** and App Intents bridging |
| [recursechat/mcp-server-apple-shortcuts](https://github.com/recursechat/mcp-server-apple-shortcuts) | Run/list shortcuts from Mac MCP clients |
| [truth0530/mcp-server-ios-shortcuts](https://github.com/truth0530/mcp-server-ios-shortcuts) | Mac-based MCP for generating, signing, inspecting, importing and running `.shortcut` files |
| [VladUZH/intents-mcp](https://github.com/VladUZH/intents-mcp) | Exposes **selected macOS App Intents** as MCP through Shortcuts |

### Reverse-direction remote supervision (2)

**iGentic gap:** Optional iPhone dashboard for Mac agents, not phone-autonomous control.

| Project | Source-described functionality (not newly device-verified) |
| --- | --- |
| [K9i-0/ccpocket](https://github.com/K9i-0/ccpocket) | Native mobile client with QR-paired bridge to Codex/Claude processes on a host |
| [pocketctl/pocketctl](https://github.com/pocketctl/pocketctl) | iPhone/web client for *supervising coding agents running on a separate development machine* |

### Simulator tooling (4)

**iGentic gap:** Scripted multi-app test flow recording and replay; own iOS app simulator build exists.

| Project | Source-described functionality (not newly device-verified) |
| --- | --- |
| [facebook/idb](https://github.com/facebook/idb) | iOS development bridge, especially simulator instrumentation |
| [joshuayoes/ios-simulator-mcp](https://github.com/joshuayoes/ios-simulator-mcp) | MCP control for Xcode simulator |
| [minitap-ai/mobile-use](https://github.com/minitap-ai/mobile-use) | Language-driven Android + iOS **simulator** workflows |
| [mobile-dev-inc/Maestro](https://github.com/mobile-dev-inc/Maestro) | YAML UI flows and `maestro mcp` for iOS simulators, Android and web |

### Speech and conversational audio (5)

**iGentic gap:** Voice input, local ASR, VAD, interruption, complete speech conversation; current PR adds only speech output.

| Project | Source-described functionality (not newly device-verified) |
| --- | --- |
| [argmaxinc/argmax-oss-swift](https://github.com/argmaxinc/argmax-oss-swift) | Current canonical upstream for the WhisperKit, SpeakerKit and TTSKit family; the older `argmaxinc/WhisperKit` GitHub link resolves here |
| [fikrikarim/volocal](https://github.com/fikrikarim/volocal) | Experimental **fully local** streaming voice loop (ASR → LLM → TTS), barge-in and echo cancellation, iPhone-native |
| [FluidInference/FluidAudio](https://github.com/FluidInference/FluidAudio) | Swift/Core ML SDK for local speech-to-text, VAD, TTS and diarization, with Apple Neural Engine paths |
| [ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp) | Local speech-to-text; includes SwiftUI example |
| [soniqo/speech-swift](https://github.com/soniqo/speech-swift) | MLX/Core ML on-device speech recognition, synthesis and related audio models |

---

**Scope closure:** all 107 external upstream identities (98 linked in the frozen atlas + 9 additional catalog cross-references) appear exactly once. This is classification of source projects, not verified readiness, licensing clearance or installation.
