# iPhone & mobile-agent open-source project atlas

**Source review:** 2026-11-21 · **Evidence:** primary GitHub repositories and project READMEs, plus Apple's public developer documentation. **Status:** research inventory, not an iGentic dependency or device-test result.

This is a curated, **non-exhaustive** discovery map for building **iGentic iPhone**: an on-device, privacy-first AI controller with policy-gated actions and optional host/device-automation adapters. Repositories were checked for existence on GitHub; the higher-priority projects were additionally checked against their upstream READMEs. A linked project, star count, README claim, or a simulated run is **not** evidence that it works on our physical iPhone Air. No external code is installed, vendored or executed in this change.

## Read this first: three distinct kinds of "iPhone agent"

1. **On-phone runtime:** an iOS app remains on the phone after installation, proposes actions through its own model/client, and works without a continuously connected Mac **only within its demonstrated iOS/background/UI-automation constraints**. Evaluate separately from normal App Store-compliant App Intents.
2. **Host-driven physical iPhone control:** a Mac/Windows process operates the attached phone through XCTest/WebDriverAgent, Apple device services, accessibility or input bridges. This is powerful developer/test tooling, **not** an iOS app with general system permissions.
3. **Simulator/test automation:** excellent for reproducible CI and synthetic-data UI tests; simulator results must never be promoted to physical-device readiness.

**Labels:** `P0` = directly evaluate next; `P1` = useful comparison/component; `Watch` = promising or limited; `Reference` = enabling infrastructure. `Source claim` means the project README says so; it is not independently reproduced by iGentic.

## A. iPhone-native / agent-first experiences

| Project | Upstream | Source-described capability | Boundaries / iGentic value | Triage |
| --- | --- | --- | --- | --- |
| **Poki** | [JosssphZhou/poki](https://github.com/JosssphZhou/poki) | Native iPhone agent; claims on-phone cross-app actions after one-time Mac/Windows setup, then no running Mac; iOS 18+ in README | **Highest-priority Mac-free architecture comparison.** Setup/signing, developer/automation modes, VPN/proxy routing, screen/model-data exposure and real iOS 26 behavior need controlled validation. **AGPL-3.0-only**: study concepts before contemplating code reuse. | **P0** |
| **PhoneAgent** | [rounak/PhoneAgent](https://github.com/rounak/PhoneAgent) | Experimental SwiftUI in-app agent, XCTest-hosted action path, and Codex/OpenClaw RPC bridge for iOS/Android | Compare its iPhone agent loop, explicit bridge and Keychain design. External OpenAI Responses API is **not local-only**; a running XCTest runner/host may be needed for cross-app action paths. | **P0** |
| **AirMCP** | [heznpc/AirMCP](https://github.com/heznpc/AirMCP) | Governed Mac-app MCP tools, with an **iOS runtime described as preview** and App Intents bridging | Study allowlist, approvals and audit design. **Do not call the iPhone path released or proven** based on the macOS runtime. | P1 |

### Additional on-phone projects found in the 2026-11-21 cross-chat + search reconciliation

These are **new to the original atlas**. In particular, do not conflate **phone-hosted agent reasoning** with **phone-hosted system-wide UI control**: some offer only App Intents, sandboxed tools, or an optional developer-mode control bridge.

| Project | Upstream | Primary-source findings (not tested by iGentic) | Fit / caveat | Triage |
| --- | --- | --- | --- | --- |
| **iphone-use-app** | [EliotAndres/iphone-use-app](https://github.com/EliotAndres/iphone-use-app) | Swift/Rust on-iPhone screenshot → vision-model → actions via CoreDevice and a loopback VPN; claims **iOS 26+** and **no Mac during operation** after pairing | **Most direct iOS-26 comparison.** First setup needs Mac/pairing, Developer Mode, VPN, signing; free-account signatures expire, model endpoint may be cloud, and VPN conflicts with existing VPN. **Cellular-only caveat:** the upstream [TODO](https://github.com/EliotAndres/iphone-use-app/blob/main/TODO.md) reports a loopback VPN failure on iOS 26.6/27 (LocalDevVPN #31); its README describes a cellular-toggle workaround when connecting. Mac-free operation on cellular-only must be tested, not assumed. **AGPL-3.0**; no reuse without license review. | **P0** |
| **Pinky** | [DIYgod/pinky](https://github.com/DIYgod/pinky) | Desktop MCP/agent plus an **on-phone app**; project says iOS 17.4+ with helper/runner on older OS, iOS 27 has another route. Gateway implements permission prompts, blocked apps and human takeover. | **Pre-alpha;** study **gateway-enforced** approvals and role scopes. Do not present broad platform claims as independently reproduced. Apache-2.0 claimed by repo. | **P0** |
| **OpenMinis** | [OpenMinis/OpenMinis](https://github.com/OpenMinis/OpenMinis) | Native iOS agent shell with **on-device Alpine/iSH Linux sandbox**, skills, persistent memory and optional external providers | High-value phone-local **agent harness**; not itself proof of cross-app UI permissions. **GPL-3.0** with GPL-linked components; code reuse requires licensing review. | **P0** |
| **Fish Pocket** | [imsai-sh/fish-pocket](https://github.com/imsai-sh/fish-pocket) | Native SwiftUI phone agent app with tasks, local calendar/reminders/etc. and optional **iCTRL** bridge for other-app UI | Runtime on phone; iCTRL adds developer-mode/sideload setup. Its repo describes an **MIT-based LICENSE with extra restrictions** and noncommercial art: **do not assume standard MIT reuse**. | P1 |
| **Resident** | [Jflick58/resident](https://github.com/Jflick58/resident) | SwiftUI **locally running MLX model agent**, tools, skills, memory, MCP/OAuth connectors; lazy tool/schema loading | Excellent iPhone Air small-model/harness reference; local inference needs **real iPhone** benchmarking, simulator can use a Mac model server. License claimed Apache-2.0. | **P0** |
| **loopl** | [cagataycali/loopl](https://github.com/cagataycali/loopl) | Native Swift agent loop; MLX, llama.cpp, Apple Foundation Models; device tools and human approval | Strong reference for a small **offline model → tools → model** kernel with structured events. App-scoped tools are **not arbitrary app UI control**. | **P0** |
| **Anu-iOS** | [sandeepvijayarao09/Anu-iOS](https://github.com/sandeepvijayarao09/Anu-iOS) | Experimental voice-first local iPhone assistant, Gemma/LiteRT, on-device intent/model routing and optional cloud fallback | Compare task classification and privacy gates. README identifies a prototype and **iOS simulator build without model weights**; no device readiness inferred. MIT claimed. | P1 |
## B. Physical-device control and MCP adapters

| Project | Upstream | Source-described platform / technique | Specific evaluation question | Triage |
| --- | --- | --- | --- | --- |
| **Mobile MCP** | [mobile-next/mobile-mcp](https://github.com/mobile-next/mobile-mcp) | MCP tool server for iOS + Android, simulator and physical devices; accessibility-first where available | Test read-only discovery and screen tree, then a synthetic Diagnostics flow. Current default backend uses `mobilecli`; legacy physical-iOS route uses WebDriverAgent. | **P0** |
| **mobilecli** | [mobile-next/mobilecli](https://github.com/mobile-next/mobilecli) | Underlying cross-platform device CLI; real-iPhone agent installation needs Apple provisioning/signing | Is a small **typed** adapter preferable to exposing all Mobile MCP tools? Test exact iOS 26 setup and fail-closed errors. | **P0** |
| **agent-device** | [callstack/agent-device](https://github.com/callstack/agent-device) | Device CLI, stdio MCP, typed Node API, accessibility snapshots; iOS simulators and physical iPhones | Compare snapshot stability, latency, scoped sessions and deterministic evidence with Mobile MCP. | **P0** |
| **iphone-cli (`iph`)** | [HyunSeob/iphone-cli](https://github.com/HyunSeob/iphone-cli) | Rust CLI + MCP + scripting; claims direct physical-iPhone accessibility/input without Xcode/WDA on **iOS 27+** | **Not a tested solution for iOS 26** (author explicitly says input is not expected to work). Track after OS compatibility changes; evaluate error semantics and restricted tools. | P1 |
| **Mobdev** | [niklas-schmidt-dev/mobdev](https://github.com/niklas-schmidt-dev/mobdev) | Native Mac GUI + MCP/CLI, USB/runner iPhone input; README also describes Bluetooth HID option | Compare consent flow and Bluetooth path; requires a **Mac host**, does not create standalone iPhone autonomy. | P1 |
| **iPhone-mcp** | [blitzdotdev/iPhone-mcp](https://github.com/blitzdotdev/iPhone-mcp) | Mac-hosted MCP for real iPhone/simulator with WDA | Alternative backend; review signing/runner lifetime and policy gates before tests. | P1 |
| **iphone-agent** | [mharizanov/iphone-agent](https://github.com/mharizanov/iphone-agent) | WDA + go-ios with MCP and high-risk-action confirmation heuristics | Useful patterns: idle shutdown, action outcome and sensitive-button guards. **Label-based confirmation is not a substitute for iGentic approval receipts.** | P1 |
| **PhoneUse Local** | [phoneuse-official/phoneuse](https://github.com/phoneuse-official/phoneuse) | USB/Mac/WebDriverAgent, local viewer, REST and MCP | Compare observation/replay UX; developer preview needs a running signed WDA and externally configured model access. | P1 |
| **Appium MCP** | [appium/appium-mcp](https://github.com/appium/appium-mcp) | AI-facing MCP atop iOS XCUITest and Android automation | Useful compatibility/control baseline, not an on-device AI runtime. | P1 |
| **go-ios** | [danielpaulus/go-ios](https://github.com/danielpaulus/go-ios) | Apple-device connectivity, automation/tunneling utilities | Infrastructure only; useful for device doctor, WDA transport and pairing investigations. | Reference |
| **WebDriverAgent** | [appium/WebDriverAgent](https://github.com/appium/WebDriverAgent) | XCTest/WDA HTTP device automation server | Understand signing, runner security and system permission boundaries. **WDA endpoints must never be exposed unprotected.** | Reference |

### Additional physical-device implementations from cross-chat research

| Project | Upstream | Platform architecture / source claim | Constraint / engineering lesson | Triage |
| --- | --- | --- | --- | --- |
| **cell-use** | [Raynan00/cell-use](https://github.com/Raynan00/cell-use) | Swift API for phone-on-phone screenshots/taps/swipes with embedded tunnel and phone-control runtime | **Runtime needs iOS 27** per project FAQ, even though its library/packet-tunnel targets iOS 17. **Do not offer as iOS-26 control solution.** Apache-2.0 reported. | **P0 conditional on iOS 27** |
| **iCTRL** | [OpenMinis/iCTRL](https://github.com/OpenMinis/iCTRL) | Phone-hosted XCTest service with **encrypted X25519/HMAC pairing**, JSON-RPC and discovery; README describes on-phone Developer Disk Image mounting and optional Mac-free operation | **High-priority iOS-26 alternative.** Requires Developer Mode, compatible iOS/DDI/side-loading and a persistent XCTest runner; all paired clients have deep UI capabilities. Separate paired-key authorization from **action-level iGentic ApprovalReceipts**. Apache-2.0 claimed. | **P0** |
| **iphone-use** | [leeguooooo/iphone-use](https://github.com/leeguooooo/iphone-use) | Mac daemon + iPhone XCTest runner; iOS 15+ claimed, settled UI observations, single-device leases and replayable flows | Good UI-reference/verification design, **Mac still required during execution**. Source license badge **PolyForm Shield 1.0.0**: **not automatically reusable as open-source code**. | P1 |
| **open-iphone-use** | [semsturgut/open-iphone-use](https://github.com/semsturgut/open-iphone-use) | Mac MCP using CoreDevice real-iPhone capture/input. Current default requires **Xcode/iOS 27**; README documents old `v0.0.3` Bluetooth/older-iOS fallback | Investigate precise OS compatibility, host requirement and screenshot handling; do not run upstream install shell scripts without review. | P1 |
| **iphone-control** | [Derrors/iphone-control](https://github.com/Derrors/iphone-control) | Rust binary on **Linux or Mac**, native iOS-27 services or WDA route for iOS 17–26 | Useful host-side non-Mac/Linux experiments; **needs an external host** regardless. Source says predecessor `iphone-control-toolkit` is superseded/archived. | P1 |
| **ghosthand** | [ghosthand-dev/ghosthand](https://github.com/ghosthand-dev/ghosthand) | Mac-based USB capture + Bluetooth HID/AssistiveTouch, OCR and device leases | Good **multi-agent leasing** pattern. Still needs Mac; project describes account and pricing dependency for some remote functions and private Bluetooth APIs. | P1 |
| **open-phone** | [Array-Ventures/open-phone](https://github.com/Array-Ventures/open-phone) | Mac USB capture, Bluetooth HID, local MCP/API | Alternate host driver; no phone-native runtime, verify Bluetooth and pairing behavior. | P1 |
| **Mobium** | [mobiumdev/mobium](https://github.com/mobiumdev/mobium) | Go CLI/MCP for Android/iOS simulators and physical iPhones, structured UI refs, diagnostics and test recording | Strong test instrumentation / independent verifier; physical iPhone uses **Xcode + signing + WDA**, not an on-phone agent. | P1 |
## C. Shortcuts / App Intents / safe action surfaces

| Project / platform source | Upstream | Actual role | Boundary | Triage |
| --- | --- | --- | --- | --- |
| **iOS Shortcuts MCP** | [truth0530/mcp-server-ios-shortcuts](https://github.com/truth0530/mcp-server-ios-shortcuts) | Mac-based MCP for generating, signing, inspecting, importing and running `.shortcut` files | The server itself runs on **macOS**, not a background iPhone MCP host; import prompts do not prove installation. | **P0** |
| **intents-mcp** | [VladUZH/intents-mcp](https://github.com/VladUZH/intents-mcp) | Exposes **selected macOS App Intents** as MCP through Shortcuts | Strong allowlist design reference; not evidence of arbitrary iOS Settings access. | **P0** |
| **Apple Shortcuts MCP Server** | [recursechat/mcp-server-apple-shortcuts](https://github.com/recursechat/mcp-server-apple-shortcuts) | Run/list shortcuts from Mac MCP clients | Desktop bridge; no claim that an iPhone can host this MCP process. | P1 |
| **Apple App Intents** | [Official Apple developer guide](https://developer.apple.com/documentation/appintents) | Public API for app-scoped, declarative Siri, Shortcuts and system actions | **Preferred shipping path** for user-approved iGentic actions; not generic third-party app UI control. | **P0** |
| **Apple Foundation Models** | [Official Apple framework](https://developer.apple.com/documentation/foundationmodels) | On-device model API / structured generation with availability constraints | Keep model output non-authoritative; check supported device, OS, language, locale and runtime availability. | P0 |

## D. UI testing, repeatability, and simulation

| Project | Upstream | Source-described scope | Boundary / test use | Triage |
| --- | --- | --- | --- | --- |
| **Maestro** | [mobile-dev-inc/Maestro](https://github.com/mobile-dev-inc/Maestro) | YAML UI flows and `maestro mcp` for iOS simulators, Android and web | **Physical iPhones not yet supported** per current README. Excellent synthetic regression baseline. | **P0** |
| **ios-simulator-mcp** | [joshuayoes/ios-simulator-mcp](https://github.com/joshuayoes/ios-simulator-mcp) | MCP control for Xcode simulator | Simulator-only: do not infer physical-iPhone ability. Security review before installation. | P1 |
| **Appium** | [appium/appium](https://github.com/appium/appium) | Cross-platform automation framework | Evaluate as heavy but mature test reference; iOS host/toolchain setup applies. | P1 |
| **Facebook idb** | [facebook/idb](https://github.com/facebook/idb) | iOS development bridge, especially simulator instrumentation | Infrastructure, not agent planning or an iPhone resident agent. | Reference |
| **mobile-use** | [minitap-ai/mobile-use](https://github.com/minitap-ai/mobile-use) | Language-driven Android + iOS **simulator** workflows | README explicitly says **physical iOS is not supported yet**. Learn planning/evaluation without false real-iPhone claims. | P1 |

## E. Local inference, multimodal UI understanding, speech

| Project | Upstream | Role for iGentic | Boundary / next validation | Triage |
| --- | --- | --- | --- | --- |
| **AnyLanguageModel** | [huggingface/AnyLanguageModel](https://github.com/huggingface/AnyLanguageModel) | Swift model-provider interface resembling Foundation Models; supports multiple backends | Very promising for model-agnostic proposals; check Swift/Xcode version and whether every backend is truly local. | **P0** |
| **MLX Swift** | [ml-explore/mlx-swift](https://github.com/ml-explore/mlx-swift) | Apple Silicon compute primitives | Core runtime reference; test exact iPhone memory and supported operations. | P1 |
| **MLX Swift LM** | [ml-explore/mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) | Swift LLM/VLM, guided generation, MLX/Apple model bridging | Main 3.x introduces breaking changes; Foundation Models bridge mentions **iOS 27 SDK**. Pin API/version for comparison. | **P0** |
| **MLX Swift Examples** | [ml-explore/mlx-swift-examples](https://github.com/ml-explore/mlx-swift-examples) | Example Swift apps and experiments | Educational reference, not iGentic runtime evidence. | P1 |
| **llama.cpp** | [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) | GGUF inference and Metal backend | Check exact iOS integration, model memory, energy, tool-calling and licensing per artifact. | P1 |
| **whisper.cpp** | [ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp) | Local speech-to-text; includes SwiftUI example | Good privacy-first voice-input candidate, benchmark on physical iPhone Air. | **P0** |
| **MLC LLM** | [mlc-ai/mlc-llm](https://github.com/mlc-ai/mlc-llm) | Deploy LLM runtimes to mobile and other targets | Compare conversion/build size, thermal behavior and iOS integration complexity. | P1 |
| **Swift Transformers** | [huggingface/swift-transformers](https://github.com/huggingface/swift-transformers) | Tokenization and model utilities in Swift | Component-level use; check exact package APIs and architecture. | P1 |
| **ExecuTorch** | [pytorch/executorch](https://github.com/pytorch/executorch) | Edge model inference runtime | Candidate for small-model deployment with explicit iOS backend proof. | P1 |

### Further on-device speech and an optional hardware counterexample

| Project | Upstream | Why interesting | Important boundary | Triage |
| --- | --- | --- | --- | --- |
| **Speech Swift** | [soniqo/speech-swift](https://github.com/soniqo/speech-swift) | MLX/Core ML on-device speech recognition, synthesis and related audio models | Verify exact **iPhone Air + German** model performance, model licensing, streaming latency, battery and privacy; broad README benchmarks are not our measurements. | **P0** |
| **Phone Agent (ESP32)** | [Kastarter/phone-agent](https://github.com/Kastarter/phone-agent) | On-phone planner + **ESP32-S3 Bluetooth HID dongle** for UI input, source claims iOS 27 end-to-end | **Reference only:** conflicts with iGentic's **no additional hardware** preference; useful as alternate technique, not the target product path. | Watch |
## F. Research-grade phone GUI agents and planning

| Project | Upstream | What to learn | Evidence limitation | Triage |
| --- | --- | --- | --- | --- |
| **Open-AutoGLM** | [zai-org/Open-AutoGLM](https://github.com/zai-org/Open-AutoGLM) | Multimodal screen grounding, planning and human takeover; iOS setup guide exists | Primary flow is Android/ADB; iOS needs separate WDA setup. Large phone models do not imply an iPhone Air on-device run. | P1 |
| **Mobile-Agent family** | [X-PLUG/MobileAgent](https://github.com/X-PLUG/MobileAgent) | Planning, reflection, GUI grounding, long-horizon task evaluation | Research/framework, **not** a ready-to-install standalone iPhone controller. | P1 |

### What **not** to infer

- "Works on iOS" may mean only an Xcode **simulator**; for example Maestro/mobile-use.
- "Controls a real iPhone" commonly means a **running Mac/Windows host**, WDA/XCTest, USB, pairing and Apple signing.
- "No Mac required" may describe **after initial provisioning** and may still require a network/model account, developer mode or non-App-Store mechanisms.
- README capabilities are **project claims**, not reproduced results, and cannot establish current iOS 26 support unless explicitly scoped to that version.
- An MCP server, HID adapter or accessibility tree does not bypass Apple permissions, iOS sandbox restrictions, lock state, user consent or data protection.
- Third-party screen contents are **untrusted instructions**. Never let text in a notification or app page issue tool directives.
- "Local inference" requires measuring **exact iPhone execution**, not merely linking MLX/llama.cpp or citing Mac benchmarks.

## Cross-chat consolidation: where work already overlaps

The discoverable prior iGentic discussions cluster into **four workstreams**, not separate products: (1) **phone-native agent** without a continuously running Mac, (2) **Mac-host device control and acceptance tests**, (3) **local AI/voice runtimes**, and (4) **policy / approval / App Intents**. Earlier project discussions also identified `iphone-use-app`, `cell-use`, OpenMinis/`iCTRL`, Fish Pocket and Pinky, which were **missing from the original 33-project catalog**. This update reconciles them; do not open new implementation PRs merely to rediscover the same projects.

- **Canonical product:** `pokekarten/igentic-iphone` Swift `AgentKernel`, `PolicyEngine`, `ApprovalManager`; product goal is **Mac-free after development/install**, even if some *test tools* stay Mac-bound.
- **Existing integration lane:** [iGentic ARTEMIS Draft PR #378](https://github.com/pokekarten/igentic-iphone/pull/378), an opt-in Mac/Xcode/WDA **test path**, not the standalone iPhone runtime or a live PolicyEngine capability bridge.
- **Existing research lane:** this atlas in Draft PR #379. Expand it rather than spawning another link-only or overlapping integration PR.
- **Model-research lane:** follow `MODEL_STRATEGY.md` and the frozen runtime/physical-device evidence contracts before changing models; `Resident`, `loopl`, `AnyLanguageModel` and `Speech Swift` are comparisons, not automatic dependencies.
- **Hard constraint:** do not swap product goals for a Bluetooth dongle, remote/cloud iPhone farm, persistent Mac worker or unaudited privileged UI automation. Those may inform a *development experiment* but not iGentic's shipped phone-alone requirement.

### Deep-research insights worth testing before integration

1. **No Mac is not no dependencies:** phone-only models may still need initial signing, pairing, LocalDevVPN / packet tunnel, on-phone Developer Mode and provider network calls. Record **after-install Mac independence** separately from **offline intelligence** and **system-wide UI access**.
2. **The effective iOS version is a decisive filter.** For iOS 26 shortlist `iphone-use-app`, `Poki`, `iCTRL` (subject to setup/security verification); do **not** mistake `cell-use` native phone-control or `iphone-cli` for established iOS-26 paths. Some projects claim wide OS support but document physical-device testing on newer OS only.
3. **Separate three authorities:** (a) what the model proposes, (b) what a low-level device driver can technically do and (c) what iGentic **authorizes**. Agent prompts, a paired device certificate or a UI "Are you sure?" button alone cannot replace typed Swift authorization.
4. **Useful borrowed architecture patterns:** `iCTRL` authenticated pairing and offline clients; `iphone-use` action outcomes / replay and leases; `Pinky` gateway-side approval; `Resident` lazy tool disclosure/context budgets; `loopl` streaming tool events; `phone-use` bounded host adapters; all require source/security review.
5. **Compatibility/licensing warnings:** AGPL (`Poki`, `iphone-use-app`), GPL (`OpenMinis`), PolyForm Shield (`iphone-use`) and Fish Pocket's altered MIT claims are **different** from iGentic Apache-2.0. **Do not copy code** without checking the exact committed license and notices.
6. **Personal phone is not a test sandbox.** Developer-service agents can observe other apps, personal notifications and authentication surfaces. Start with a dedicated/synthetic simulator, then use a consented physical device only after minimum-authority tests.

### Research provenance

This revision used (a) thematically relevant earlier iGentic chats for **discovery/coordination only**, (b) Exa multi-angle search for candidate discovery and (c) **direct primary GitHub README and repository existence checks** for the new projects. Descriptions above are `source_claim` unless explicitly marked otherwise. No code, device pairing, local-model runtime, or cloud account was used to verify operational claims. Search is broad, not exhaustive. Consult each upstream repository's current issues/releases and `LICENSE` before treating README prose as a stable contract.


## G. November 2026 gaps: durable execution, native workspaces, reproducible agent quality

These projects were found and their **primary GitHub READMEs were checked on 2026-11-21**. They remain source claims, not verified iGentic runtime or physical-device results. Adding them does not approve code vendoring, installation, tool access, cloud traffic or a production release.

| Project | Upstream / source license | What the upstream describes | iGentic question and boundary | Triage |
| --- | --- | --- | --- | --- |
| **PiDurableKit** | [finnvoor/PiDurableKit](https://github.com/finnvoor/PiDurableKit) · CC0-1.0 (repository LICENSE; transitive packages need review) | Swift API to a JavaScriptCore agent harness; SQLite or JSONL persistence, durable tasks/subagents, tool events and restart recovery; iOS 17+ claimed | Can we persist synthetic proposals and state without replacing `PolicyEngine` or repeating already authorized external effects? No promise of execution while iOS has suspended the app. | **P0 research** |
| **DurableAgents** | [Think-Define-Create/DurableAgents](https://github.com/Think-Define-Create/DurableAgents) · MIT | Swift event journal, typed effect classification (`pure`, `idempotent`, `transactional`, `external`), approval-resume tokens, optional encryption | Compare crash/reconciliation semantics against iGentic's intentionally process-local one-shot execution capabilities. Any third-party resume token must **not** authorize a new effect without an iGentic-approved capability. | **P0 research** |
| **AgentKit** | [AkinoKaede/AgentKit](https://github.com/AkinoKaede/AgentKit) · MIT | Swift model/tool loop with explicit permissions and persistent conversation state | Compare bounded proposal-tool orchestration; external permission model is advisory relative to iGentic Swift authority. | P1 |
| **Floe Agent** | [JiangNanGenius/floe-agent](https://github.com/JiangNanGenius/floe-agent) · MPL-2.0 | iOS 26+ on-device workspace with files and a Linux environment, plus cross-device workflows | Product/UX comparison, not proof of free cross-app UI access or permanent background rights. | P1 |
| **Thumbly** | [timurcatakli/thumbly](https://github.com/timurcatakli/thumbly) · mixed Apache-2.0/GPL-3.0 labeling; inspect per component | macOS CoreDevice iPhone controller with explicit client approval, activity history, stop control and MCP/remote integration | Strong host-controlled UX/security comparison; **Mac must run** and phone pairing is required. Verify exact component licenses before any reuse. | P1 |
| **iOSWorld** | [ljang0/iOSWorld](https://github.com/ljang0/iOSWorld) · inspect exact revision/license | iOS simulator benchmark with 26 synthetic SwiftUI apps, one fictional profile and 133 tasks across app/multi-app settings | Measure independent action success and cross-app reliability. Simulator measurements are **not** real iPhone Air results. | **P0 benchmark** |
| **AppControlBench** | [software-mansion/app-control-bench](https://github.com/software-mansion/app-control-bench) · inspect exact revision/license | Reproducible model-versus-tool comparisons for real iOS apps **in simulator**; its November 2026 README explicitly states the new edition is **not run yet** | Use published configurations/results only for the editions actually executed; no unmeasured November pass rates. | **P0 benchmark** |

### Proposed synthetic durability and approval test matrix

1. Assign a stable task ID, immutable payload fingerprint, data class, risk, desired target, and an initial approval status. Test with **synthetic data only**.
2. Interrupt the process **before** a read-only step, **during** a model/tool step, and **after** a simulated external side effect whose completion is unknown.
3. On recovery, ensure completed internal pure work is not lost, but an uncertain external side effect goes to `unknownOutcome` / human reconciliation instead of automatic replay. An expired or payload-mismatched approval must **not** revive execution authority.
4. Simulate the Mac offline: queue only scoped, non-private test metadata. Reconnect and verify one job ID is delivered exactly once **logically**, with idempotent acknowledgement; do not claim exactly-once network delivery.
5. Compare recovery time, data exposure, transaction integrity, cancellation and failure semantics separately on Linux/host, iOS simulator and physical iPhone. iOS process restoration does **not** grant an unrestricted background execution entitlement.

**Implementation order:** use the existing iGentic `ToolRegistry`, `PolicyEngine`, `ApprovalManager`, `SafeActionExecutionCapabilityLedger` and `AuditLog` as the fixed authority. First model a **read-only, no-side-effect** diagnostic App Intent and a journalled synthetic operation; only after security admission #286/#287 and exact simulator/device evidence consider a typed host/iCTRL adapter. Keep [PR #378](https://github.com/pokekarten/igentic-iphone/pull/378) as the sole device implementation candidate, with no new competing wide device-control PR.

## G. iOS 27 native agent architecture (new platform options)

The 2026 Apple platform release changes model-provider and eval architecture enough to deserve a **first-party-first** comparison. This is more directly reusable in an iGentic iPhone Swift app than another Mac-only WDA host.

| Project / official technology | Primary source | New value | Requirement / boundary | Triage |
| --- | --- | --- | --- | --- |
| **Apple Foundation Models utilities** | [apple/foundation-models-utilities](https://github.com/apple/foundation-models-utilities) | Official Swift skills, context transformations, rolling history and Chat Completions-based provider adapters | Check exact beta/API revision, iOS 27 tooling, provider/cloud privacy, and our existing `PolicyEngine` before adoption | **P0** |
| **Core AI models** | [apple/coreai-models](https://github.com/apple/coreai-models) | Official Python export recipes and Swift on-device runtime utilities | Explicit **macOS/iOS 27+** platform, exact model build/quantization required; not proof of physical iPhone Air success | **P0 research** |
| **FoundationModelsAgent** | [rudrankriyam/FoundationModelsAgent](https://github.com/rudrankriyam/FoundationModelsAgent) | Native Swift `LanguageModel` harness with action policy, receipts, budgets, checkpoints and memory options | **High overlap with existing iGentic authority**: compare internals before considering any dependency; iOS 27+ and Swift 6.4 claimed | P1 |
| **Swarm** | [christopherkarani/Swarm](https://github.com/christopherkarani/Swarm) | Swift 6.2 agent runtime, typed tools, streaming, memory and backend adapters, including Linux test fixtures | Another agent runtime is not automatically needed; select zero/one harness on measurable gap | P1 |
| **Claude for Foundation Models** | [anthropics/ClaudeForFoundationModels](https://github.com/anthropics/ClaudeForFoundationModels) | Official Anthropic Swift adapter to Apple's `LanguageModel` protocol | Server-backed, **not offline**; repo says beta for OS 27 APIs, credentials and paid provider remain a delegation boundary | P1 |
| **open-apple-models** | [SpaceCorps/open-apple-models](https://github.com/SpaceCorps/open-apple-models) | Swift tool-loop and structured tool policies around Apple Foundation Models | iOS 27/Xcode 27; source claims do not imply device compatibility or authority parity | Watch |
| **Apple Evaluations framework** | [Apple docs](https://developer.apple.com/documentation/evaluations) | Native evaluation of generated outputs, tool calls, argument values and ordering | Available with OS/Xcode 27; compare to immutable iGentic V0 benchmark without replacing it | **P0** |

[Architecture reassessment and prioritized experiments](TECHNICAL_REASSESSMENT_2026_11_21.md) distinguish product APIs, developer-mode cross-app research and Mac-hosted testing. The Apple on-device system model documents a [4,096-token shared context](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window); custom/remote `LanguageModel` providers may have different limits. The common provider API does **not** imply that any model is local or authorized to execute side effects.

## H. Reproducible iPhone model and memory benchmarks

| Project | Upstream | Why it matters | Guardrail | Triage |
| --- | --- | --- | --- | --- |
| **Pocket AI Lab** | [ananasDDA/pocket-ai-lab](https://github.com/ananasDDA/pocket-ai-lab) | iOS 26+ runtime comparison of MLX, llama.cpp, Apple model and more; **actual process memory/jetsam budget** and Metal working-set reporting, live CPU/thermal diagnostics | Upstream measurements come from other devices. No claim that our iPhone Air has the same budget or performance. | **P0 method** |
| **edge-llm-bench** | [john-rocky/edge-llm-bench](https://github.com/john-rocky/edge-llm-bench) | Reproducible trial fixtures and raw result records for MLX, LiteRT-LM, llama.cpp, Core AI and others across real devices; preserves failures and avoids unsupported headline rankings | Independent methodology and external device results only; exact model artifact and version pins matter. | **P0 method** |

**Officially supported experiment to investigate:** [Apple's Qwen3 Core AI export recipe](https://github.com/apple/coreai-models/blob/main/models/qwen3/README.md) currently documents the existing iGentic Qwen3-0.6B family as an iOS export candidate. Example command `uv run coreai.llm.export Qwen/Qwen3-0.6B --platform iOS` is a **source example only**, **not executed by this PR**. First pin exporter and source revision, compare against the existing frozen benchmark, and evaluate the process memory limit without silently granting entitlements or mixing different model checkpoints. See the [reassessment](TECHNICAL_REASSESSMENT_2026_11_21.md).

## I. Focused 2026-11-21 findings: Eiscue and safe agent tools

Additional Exa discovery was checked against the **primary GitHub READMEs** and Apple's developer documentation on 2026-11-21. These are **source claims and design comparisons**, not an iGentic iPhone Air result. They do not authorize installation or code reuse.

| Project / reference | Source-backed finding | Why it matters for iGentic | Hard boundary / priority |
| --- | --- | --- | --- |
| **Eiscue** | [LLLLLayer/Eiscue](https://github.com/LLLLLayer/Eiscue): iOS **26+** phone-resident agent using configured HTTPS vision/tool models, developer services (XCTest; newer DisplayService/HID) or optional ESP32 HID. On iOS 26, developer-service control requires one-time Mac pairing. A screenshot `frameId` is consumed for **one** action, checked for freshness/session/orientation; an uncertain action delivery stops without blind replay. Device tasks use `BGContinuedProcessingTask`. | **High-priority phone-alone architecture comparison.** Evaluate screenshot-to-action binding, no-implicit-fallback route selection, uncertainty handling, privacy-preserving reports, and resumable task UX. | **P0 research, no vendoring.** Preview 0.1.0; not App Store-distributed; screenshots travel to configured model endpoint; developer services use private interfaces. No unified distribution license; GPL-3.0 and custom-licensed components require separate review. On-phone reasoning is not offline inference. |
| **FoundationModelsKit** | [rryam/FoundationModelsKit](https://github.com/rryam/FoundationModelsKit): Swift **6.2+, iOS 26+, Xcode 26+**, MIT. Runtime readiness, structured generation/schema validation, per-turn tool budgets and loop detection, app-owned authorization plus confirmation, EventKit read/mutation separation, and mutation receipts including `unknown` for uncertain writes. | **P0 Swift design comparison** for existing iGentic `PolicyEngine`, `ApprovalManager`, `AppleFoundationModelsRuntime`, `SafeActionExecutionCapabilityLedger` and draft reminder flow. An `unknown` write is not safely retryable. | Do not add a parallel authoritative policy, silently enable live EventKit writes, or conflate platform permission with approval. Prototype only synthetic in-memory tests and compare interface/behavior before considering a pinned dependency. |
| **Apple WWDC26 agentic security** | [Official Apple session 347](https://developer.apple.com/videos/play/wwdc2026/347/): untrusted model/tool inputs create prompt-injection and data-exfiltration risk; use action-stage deterministic checks, explicit confirmation and lock-screen authentication. Session covers model tool-call interception and App Intents risk metadata. | Security test checklist for reading screen content, tool outputs, cross-app clipboard/context, and any new App Intent. The *model* may suggest a tool, but policy and action authentication must remain outside the prompt. | Check exact SDK/API availability before coding newer lifecycle modifiers; do not interpret prompt instructions or dynamic system confirmation as a replacement for iGentic's mandatory typed approvals. |
| **Apple continued background work** | [Official BackgroundTasks guide](https://developer.apple.com/documentation/backgroundtasks/performing-long-running-tasks-on-ios-and-ipados): `BGContinuedProcessingTask` can continue **user-initiated foreground tasks** while the app backgrounds, with progress, user cancellation and system expiration. | A valid iOS 26 partial solution for bounded phone-only work and progress UI. Combine with a durable journal that distinguishes completed, unattempted and unknown-outcome effects. | **Not an always-on agent permission** or guaranteed runtime after a force-quit; validate lock, background, cancellation, thermal and reboot behavior on a physical device. |

### Smallest decisive iGentic experiments

1. **Synthetic screenshot lease:** build a pure-Swift validator for `frameId` + timestamp + orientation + session + one-action consumption; reject stale, reused or mismatched frames, then compare it against Eiscue's actual code. This is **not** authorization to touch another app.
2. **Typed uncertain effect:** using an injected fake reminder service, simulate an error after write dispatch and require `unknownOutcome` / manual reconciliation rather than automatic replay; ensure existing iGentic approval receipts remain authoritative.
3. **Phone-alone background proof:** on a disposable test iPhone running iOS 26, start one explicitly approved synthetic diagnostic run in the foreground, background/lock the device, cancel from system UI, force-quit and reopen; record exact state transitions. Never assert indefinite background access.
4. **Security regression:** feed an adversarial synthetic screenshot/tool result such as an instruction to exfiltrate unrelated text; assert that deterministic allowlists, current data class, authentication/approval and external-model privacy gates still refuse unauthorized actions.

**Decision:** Eiscue is the most novel **Mac-free-after-setup device-control comparison** in this pass; FoundationModelsKit is the most immediately applicable **iOS-26 Swift tool-safety reference**. Keep both in research under [Draft PR #379](https://github.com/pokekarten/igentic-iphone/pull/379); [ARTEMIS Draft #378](https://github.com/pokekarten/igentic-iphone/pull/378) remains the sole Mac-host implementation candidate.

## Decision matrix: what should iGentic actually try?

| Question / use case | Compare first | Why | Acceptance signal |
| --- | --- | --- | --- |
| **Mac-free real iPhone autonomy after setup** | Poki, PhoneAgent; iGentic Swift + App Intents | Only directly relevant candidates for an on-phone experience; each has important platform/security qualifications | Synthetic note/reminder draft on iPhone with Mac **disconnected**; no leakage; user approval proven |
| **Codex/ChatGPT controlling a tethered phone** | Mobile MCP + mobilecli, agent-device, Mobdev | MCP/readable UI + broad device access; three competing adapters worth comparing | Same physical-device, same task, same OS; capture read-only and synthetic test outcomes |
| **No Xcode/WDA physical control** | iphone-cli | Rust alternative with direct developer services | **Stop on iOS 26**; reconsider for documented iOS 27+ device only |
| **Reproducible iOS test suite** | Maestro, ios-simulator-mcp | Synthetic UI regression without private data or personal phone | CI or host simulator flow, precise app build and simulator identity |
| **Safe user-level automation without UI scraping** | App Intents, iOS Shortcuts MCP for authoring, intents-mcp for design | Typed actions and approval bridge fit the existing policy kernel | One action-specific, revocable approval and verified result |
| **On-phone language and voice** | Apple Foundation Models, AnyLanguageModel, MLX Swift LM, whisper.cpp | Proposals/speech without granting tool authority to a model | Same frozen benchmark and physical-device evidence protocol |

### Recommended integration boundaries

```text
User / Siri / Shortcut / iGentic UI
        -> iGentic deterministic PolicyEngine + DataClassification
        -> typed action draft + scoped ApprovalReceipt
           -> on-device App Intents (first-party, approved actions)
           -> optional reviewed host capability bridge (lab only)
                  -> one of Mobile MCP / agent-device / ARTEMIS
        -> verify result -> redacted AuditLog
```

**Do not merge competing broad device integrations.** There is already an active ARTEMIS host integration proposal: [iGentic PR #378](https://github.com/pokekarten/igentic-iphone/pull/378), based on [Google ARTEMIS iOS PR #175](https://github.com/google/artemis/pull/175). This atlas is deliberately **documentation-only**, complementary to that one implementation PR, and does not imply ARTEMIS's device tests succeeded. Any future host adapter must be independently gated against Swift policy/approval before app control.

## Proposed lab experiment: apples-to-apples, non-destructive

1. Select **one** owned, unlocked iPhone and record OS version, build, host version, Xcode/tool versions **privately**; do not publish UDIDs, screenshots or credentials.
2. Establish a synthetic iGentic Diagnostics app and a **separate** booted simulator; initially forbid other app bundles, messages, accounts and Settings writes.
3. For each eligible adapter run: `doctor`, device listing, **read-only** UI tree, screenshot after redaction, synthetic click, expected UI state check, session shutdown.
4. Record: time per observation/action, UI ref stability, macOS dependencies, authentication/exposure, screenshot exfiltration path, failure/error behavior, termination, license, install friction, actual iOS version.
5. Separately test the **on-phone** path with the Mac disconnected, explicitly observing whether lock/background state suspends the agent. For loopback-VPN tools, compare Wi-Fi vs **cellular-only**, connection/reconnection, VPN coexistence and the behavior on the exact iOS patch version; record any cellular-toggle workaround separately.
6. Make a **decision after actual measurements**. The lowest-friction README is not automatically the safest or most autonomous tool.

### Stop rules / privacy / legal checks

- Never install unreviewed outside agent code onto a personal phone or run against banking, authentication, health, messages or private work data.
- Prefer pinned commit or release and hash-check binaries; do not use `curl | sh` blindly or give arbitrary MCP clients global device control.
- Keep mobile-host MCP on stdio or authenticated local-only transport. Treat WDA HTTP/network exposure as a security risk.
- No telemetry/cloud fallback by default. Explicitly inspect whether the connected LLM client transmits screen content.
- Inspect license **per pinned revision** before vendoring or derivative use; Poki's AGPL-3.0-only license is particularly important.
- Keep authorization **outside model prompts**: deterministic action types, app/device allowlists, one-shot receipts, rollback/timeout, redacted logs.
- iOS App Store distribution, device-management APIs, XCTest/Developer Mode and any private API must be assessed separately for permitted deployment. This atlas is not a promise of an App Store-compatible system-wide agent.

## 2026-11-21 Exa follow-up: distinct new repository candidates

**Source class:** upstream GitHub README inspected through Exa Search/Fetch on 2026-11-21. These are **source claims only**, not build, trust, license-admission or iPhone Air execution evidence. Compared with the previously listed `HyunSeob/iphone-cli` and `Derrors/iphone-control`, the following four repository identities were missing; do not count their overlap or forks as independent proof.

| Newly identified repository | Primary source and claimed role | iGentic research decision / important caveat |
| --- | --- | --- |
| **iospilot** | [WaziXuan/iospilot](https://github.com/WaziXuan/iospilot) — Python MCP host for iOS 27+ CoreDevice accessibility tree, touch/HID and screen-settling detection; USB, DDI/Developer Mode | **P1 host-test candidate.** Compare read-only element observation with existing iPhone CLI and ARTEMIS on a disposable or synthetic device. Requires a live **host**, not phone-only autonomy. Verify license, revision and device support before running. |
| **devicehub_rs** | [jkcoxson/devicehub_rs](https://github.com/jkcoxson/devicehub_rs) — Rust CoreDevice display/HID hub with MCP, GUI and VNC | **P1 transport/security comparison.** Examine screenshot-to-coordinate normalization, local-only MCP and cancellation. Its VNC description says it accepts any password, and MCP is unauthenticated: do not expose beyond loopback or install on a personal device without review. Requires a host. |
| **Roubao 2.0 iOS** | [Turbo1123/roubao](https://github.com/Turbo1123/roubao) — Swift/Rust iPhone-resident agent based on `iphone-use-app`; developer pairing, local loopback VPN, resumable tasks and manual consent | **P1 on-phone lifecycle comparison, not an independent transport design.** Investigate resumability, unknown-outcome/repeated-write handling, cellular/VPN coexistence and consent UI. Its **iOS-specific licensing is declared AGPL-3.0** despite the repository's mixed platform/license metadata; no code copying without separate license review. Cloud model API remains distinct from offline local inference. |
| **poki-for-linux** | [carrotciallo/poki-for-linux](https://github.com/carrotciallo/poki-for-linux) — unofficial AGPL Poki Linux-host adaptation using Rust/idevice and Node MCP | **Reference only / lower priority.** Useful for understanding USB/RemoteXPC portability, but it is an upstream-derived host integration, not an independent Mac-free native iPhone agent. Its network/Tailscale claims require separate validation. |

**Most important research result:** treat **host-driven CoreDevice iOS 27** and **phone-resident loopback-tunnel automation** as separate capability lines. Neither gives an App Store app blanket cross-app permission. For iGentic, keep Swift policy, approval receipts, explicit app-scoped action allowlists and synthetic tasks outside third-party model prompts. A claimed `unknown` external write must be reconciled before retry; no unattended production message/payment/delete experiments.

**Proposed bounded experiments:** (1) implement/verify an iGentic XCTest UI-navigation smoke test inside our own app; (2) on a disposable or simulated environment evaluate host accessibility observation from one pinned tool (without installing every candidate); (3) on an authorized disposable physical iPhone test the phone-native path with Mac detached, flight/cellular transitions, locked/background interruption and explicit output audit. Keep a source-and-license manifest and update this entry when exact SHAs are tested.

## 2026-11-21 evaluation and safety research follow-up

**Research-only references** (not iGentic test outcomes; benchmarks on Android or synthetic iOS do not prove physical iPhone Air autonomy):

| Research / code | What is reproducible or measured | Application to iGentic |
| --- | --- | --- |
| [iOSWorld](https://github.com/ljang0/iOSWorld) / [paper](https://arxiv.org/abs/2606.09764) | 26 synthetic interconnected SwiftUI apps, 133 tasks, per-task rubrics; separates vision-only from privileged XML+vision observation; reported best overall 51.9%, multi-app 36.7% | **P0 benchmark design reference**; borrow rubric patterns and synthetic state checks, not benchmark success claims. Exists elsewhere in this atlas; this is a measurement update, not a newly discovered unique agent |
| [MobileWorld](https://github.com/Tongyi-MAI/MobileWorld) / [ACL 2026](https://aclanthology.org/2026.acl-long.278/) | Containerized Android tasks with deterministic back-end state verification and MCP + human-interaction flows; 201 tasks over 20 apps | **P1 evaluation methodology**; adapt outcome checks, snapshots, human handoff and state reset to iGentic's typed Safe Action and XCUITest smoke gates |
| [MobileWorldSafety](https://arxiv.org/abs/2608.17659) | 142 Android mobile-agent environmental-injection risk tasks; published attack-success range 40.4%–66.9% across six tested agents | **P0 red-team methodology**; add synthetic on-screen adversarial instructions, require deterministic refusal/no unauthorized side effect and independent post-action state verification; Android numbers must not be quoted as iOS/iGentic rates |
| [MAI-UI / Qwen-UI-Agent](https://github.com/Tongyi-MAI/MAI-UI) | Mobile GUI model and evaluation research, with reported hybrid GUI/CLI and device benchmarks | **Watch** for model behavior and task-generation techniques; larger model and reported aggregate performance do not establish local iPhone Air feasibility |

**Suggested acceptance fixture** for the next iGentic UI test: a synthetic task with a unique state marker; start from a clean simulator state; verify visible UI by accessibility identifier; inject a misleading instruction in an untrusted UI label; ensure policy and approval are unchanged; simulate cancellation or uncertain completion; validate final state in a separate, deterministic verifier. Preserve an explicit distinction between **action requested**, **action dispatched**, **side effect observed**, **side effect unknown**, and **side effect not sent**. Treat source content as data, not authorization.

## Maintenance

- Review on **iOS major releases**, agent-control API changes, new device test evidence, upstream license/security advisories, or every 90 days.
- Evidence required for promotion to "works on iGentic physical iPhone": exact upstream SHA/release, test script, iPhone model + iOS version, Mac/Xcode versions when present, no-personal-data test transcript, expected/actual results and privacy review.
- The list is manually curated, not exhaustive; a repository existing or appearing here is not an endorsement.
- Durable project safety, evaluation and platform contracts remain canonical in [`docs/KNOWLEDGE_MAP.md`](../KNOWLEDGE_MAP.md), [`docs/SOURCE_VERIFICATION.md`](../SOURCE_VERIFICATION.md), [`docs/app-intents-safety.md`](../app-intents-safety.md) and [`docs/model-research/RUNTIME_EVIDENCE_MATRIX.md`](../model-research/RUNTIME_EVIDENCE_MATRIX.md).
