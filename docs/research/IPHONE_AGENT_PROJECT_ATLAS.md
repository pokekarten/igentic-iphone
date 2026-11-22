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


## 2026-11-22 extension: 24 additional upstreams, deduplicated against the existing atlas

**Review method:** multi-angle Exa source discovery (native app/local models, voice, in-app coding and sandboxes, physical-device tooling), targeted live GitHub source/README review, and web cross-checks. **Evidence level: upstream self-description only**; existence/README was checked, but packages were not downloaded, compiled, tested, security-audited or executed on an iPhone. The source URLs in the following tables were **absent from the preceding atlas** when this extension was assembled. Links, not GitHub star counts, are the durable identifiers. Repo metadata licenses are *signals*, not a complete review of dependencies, model weights, bundled assets or distribution terms.

### J. Native iPhone agents, coding and voice (newly identified)

| Project and upstream | Claimed capabilities / distinction | Boundary, relevance and next check | Priority |
| --- | --- | --- | --- |
| [Pocket Agent](https://github.com/meshoklv/pocket-agent) | iPhone-local Gemma/LiteRT-LM coding agent: reads a user-selected folder and proposes before/after diffs with explicit **Apply** | Strong reference for **review-before-write**, workspace scope and offline mode. Reproduce a synthetic 3-file edit and rejection path on target iPhone; local GPU claim is not our benchmark. MIT per repository metadata. | **P0** |
| [Pokeet](https://github.com/isaced/pokeet) | Phone-native coding agent that reads/edits/tests/commits within its own workspace; public TestFlight and early development | Compare file approval and Git credentials isolation, not general OS control. Verify actual iPhone capabilities before reuse. Apache-2.0 per metadata. | P1 |
| [Pi for iOS](https://github.com/dannote/pi-ios) | Native iOS Bun/JavaScript + terminal wrapper around a Pi coding agent and local file tools | **Important contradiction to distinguish:** tools run on device, but README requires an **OpenRouter API key** for model access. Thus not an offline LLM by default. MIT per metadata. | P1 |
| [Volocal](https://github.com/fikrikarim/volocal) | Experimental **fully local** streaming voice loop (ASR → LLM → TTS), barge-in and echo cancellation, iPhone-native | Best phone-native voice integration exemplar. Compare microphone permission, interruption, thermal/battery cost and background/screen-lock behavior under actual iOS rules. MIT per metadata. | **P0** |
| [FluidAudio](https://github.com/FluidInference/FluidAudio) | Swift/Core ML SDK for local speech-to-text, VAD, TTS and diarization, with Apple Neural Engine paths | High-value **component**, not a general iPhone agent. Test voice latency, multilingual German recognition, silence/interrupt handling and binary/model footprint; verify feature-specific model licenses. Apache-2.0 repository metadata. | **P0** |
| [Argmax Open-Source Swift SDK / WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) | Current canonical upstream for the WhisperKit, SpeakerKit and TTSKit family; the older `argmaxinc/WhisperKit` GitHub link resolves here | Independent Swift audio baseline vs FluidAudio. Confirm which SDK parts remain free/open versus explicitly separate **Pro** features. MIT repository metadata. | P1 |
| [Off Grid AI](https://github.com/off-grid-ai/OGAM) | On-device GGUF, multimodal, local tools, knowledge base, optional offline speech and image generation | Compare runtime UX, RAM budgets, tool-loop safety and model downloads. README distinguishes optional **paid Pro** features; do not assume every listed action is part of free/open functionality. MIT repository metadata. | P1 |

### K. Swift agent runtimes and sandbox building blocks (newly identified)

| Project and upstream | What to study | Boundary and evidence gap | Priority |
| --- | --- | --- | --- |
| [LLMLocal](https://github.com/no-problem-dev/swift-llm-local) | Swift MLX local inference, per-model tool capability, model download/memory management, agent-client adapter | iOS/macOS library, **not** device UI control; benchmark against existing iGentic model gate before considering dependency. MIT metadata. | P1 |
| [SwiftAgent](https://github.com/mzbac/SwiftAgent) | Qwen3/MLX, MCP and tool-calling in Swift; README advertises iOS 16+ | Evaluate tool-schema bounds and provider lifecycle; do not let the model own authorization. MIT metadata. | P1 |
| [Arbiter](https://github.com/sabby3861/Arbiter) | Unified Swift provider routing between Apple/on-device and cloud, explicit upstream feature-status claims | Compare policy-aware provider selection and avoid duplicate abstractions given Apple's iOS 27 provider API. MIT metadata. | P1 |
| [DeepAgents Swift](https://github.com/dsaad68/deepagents-swift) | Middleware, ReAct, MCP, lazy tool discovery, optional MLX adapter | Mac-specific action tools must not be presented as iOS app privileges. Validate actual iOS package target and transitive dependencies. MIT metadata. | P1 |
| [AgentRunKit](https://github.com/Tom-Ryder/AgentRunKit) | Typed Swift tool contracts, streaming, MCP and optional MLX support | Architecture benchmark only; iPhone runtime and Apple-platform compatibility require build evidence. MIT metadata. | P1 |
| [mlx-agent](https://github.com/abra-code/mlx-agent) | Swift MLX/Foundation backend, ACP over stdio, MCP permission gates and reproducible benchmark tools | Primarily **terminal/host-oriented**, not demonstrated as an on-phone native iOS sandbox. Study narrow tool-authority contract, don't port blindly. Apache-2.0 metadata. | P1 |
| [just-bash-swift](https://github.com/mweinbach/just-bash-swift) | In-process Swift shell interpreter with **virtual in-memory filesystem**, designed where iOS forbids ordinary subprocess execution | Promising contained code-tool sandbox; it is not system shell or unrestricted app filesystem access. **License not exposed in source metadata used here:** block code reuse until checked. | P1 |
| [pmai / PocketMai](https://github.com/trufae/pmai) | Swift agent core shared across terminal/phone, Apple local models and optional encrypted workstation pairing | **Hybrid:** phone UI and optional workstation delegation are not the same as fully autonomous on-phone terminal tools. Compare explicit host approval and secrets scope. MIT metadata. | P1 |
| [Makima](https://github.com/Maximoff19/makima) | SwiftUI personal assistant with voice/memory/calendar UI and self-hosted FastAPI/LLM gateway | Separate **self-hosted remote inference** from on-phone private inference; tools and logs may leave phone. Useful delegated-architecture contrast. MIT metadata. | Watch |
| [DSH iOS](https://github.com/everettjf/dsh-ios) | Native wrapper around iSH Linux userspace and a coding-agent harness on iPhone/iPad | **Explicitly experimental/discontinued:** upstream says limited performance and no further releases/App Store plan; patterns only, no production dependency. GPL-3.0 metadata. | Watch |

### L. Host-driven device control and remote agent supervision (newly identified)

| Project and upstream | Real operating model | Boundary / comparison | Priority |
| --- | --- | --- | --- |
| [ipb](https://github.com/ipbtools/ipb) | macOS-hosted iOS 27 CoreDevice **private HID/AX services**: native UI tree, taps, screen stream, MCP, no on-phone XCTest runner | **Not Mac-free and not a public production iOS API.** Compare typed, uncertainty-aware write receipts and stale tree handling; version/ABI break risk. Maintainer explicitly distinguishes source release from physical validation of new MCP effects. MIT metadata. | **P0 developer lab** |
| [ios-device-mcp](https://github.com/ChrisThoma/ios-device-mcp) | Mac USB/Xcode device test server + persistent XCUITest runner, structured MCP tools | Real iPhone testing/diagnostics only; requires developer tooling and trust. Compare isolated test sessions and cleanup. MIT metadata. | P1 |
| [iOS Agent Bridge](https://github.com/UgeeCodes/iOS-agent-bridge) | Host MCP and iOS 17+ WebDriverAgent/XCTest with CoreDevice tunnel recovery | Developer-mode physical-iPhone QA, **not** an App Store or Mac-free agent. Audit screenshot/AX exposure, reconnection, consent and host process lifetime. MIT metadata. | P1 |
| [iphone-use (hughlee824)](https://github.com/hughlee824/iphone-use) | Mac CLI for an AI client to operate real iPhone; source describes standard and runner modes | Alternative to host ARTEMIS/mobile-mcp. Host-side model may see screenshot/UI data. Compare minimal synthetic observation and stop/reconnect behavior. MIT metadata. | P1 |
| [PocketCtl](https://github.com/pocketctl/pocketctl) | iPhone/web client for *supervising coding agents running on a separate development machine* | A **remote control plane**, not on-phone local inference or cross-app UI driver. Hosted-service privacy and network dependency require review. MIT metadata. | P1 |
| [CC Pocket](https://github.com/K9i-0/ccpocket) | Native mobile client with QR-paired bridge to Codex/Claude processes on a host | Compare phone approval and session visibility; **host required**, bridge transport and agent-provider data flow require audit. MIT metadata. | P1 |
| [FluidUse](https://github.com/FluidInference/FluidUse) | Small Core ML decision model drives form filling via **macOS Accessibility**, not iPhone APIs | Valuable *architecture analogy*: typed local decisions + deterministic execution, **not** evidence of iOS all-app control. Apache-2.0 metadata. | Watch |

### Cross-reference and source reconciliation

- Existing entries **already cover** `Poki`, `iphone-use-app`, `OpenMinis/iCTRL`, `PhoneAgent`, `Mobile MCP`, `mobilecli`, `agent-device`, `iphone-cli`, `cell-use`, `ghosthand`, `Resident`, `loopl`, `Pocket AI Lab`, `Eiscue`, `ARTEMIS`, `apple/coreai-models`, `FoundationModelsKit` and many others. **Do not re-add these as "new".**
- The `argmaxinc/WhisperKit` legacy GitHub URL redirected to `argmaxinc/argmax-oss-swift` in the source-fetch review; retain **one canonical project identity**.
- Never confuse: **app sandbox** with other apps' data; **local model weights** with offline end-to-end data flow; **no continuously connected Mac** with no Mac/signing at initial setup; **developer CoreDevice/HID** with App Store-supported cross-app input.
- The above rows have **24 unique repository URLs**, checked against earlier atlas URLs in the same PR. An upstream README statement is still **not** an iGentic iPhone Air acceptance result. All usage and redistribution require an exact pinned revision, transitive license and security review.

### Highest-value next tests (source-backed, not executed in this extension)

1. **One safe native iPhone action:** preserve the existing deterministic Swift `PolicyEngine`, approval receipt, typed destination and audit boundary. Compare Pocket Agent's **diff-before-write** interaction with the existing reminder preview; assert a denied/expired approval performs zero writes.
2. **Offline voice micro-slice:** compare FluidAudio and Argmax locally for German ASR, streaming VAD and short utterances; measure first usable transcript, RAM, interruption, thermal state and audio data egress on actual hardware. Volocal provides a reference UX, not a copied authority layer.
3. **Native model fit:** compare the existing Apple Foundation Models baseline and *untouched* open-weight candidates through their current approval-gated preview. Use LLMLocal/SwiftAgent only as alternatives if measurable gaps emerge; avoid parallel session-stack proliferation.
4. **Synthetic device QA:** compare PR #378's ARTEMIS approach with `ipb`, `ios-device-mcp` and `iOS Agent Bridge` against the **same** signed iGentic Diagnostics test app. Check host requirement, OS version, source pin, screenshot/AX exposure, interruption cleanup and write-uncertainty. No automatic retries after ambiguous side effects.
5. **Phone-native coding sandbox (optional):** benchmark the approval-before-disk-write and folder scoping patterns of Pocket Agent/Pokeet; consider virtual filesystem tools such as just-bash-swift **only after** license and hostile-input review. No arbitrary shell or app-wide filesystem authority.

**Not performed:** no new implementation, model download, physical-device run, Swift build, signing, private-API execution, cloud account connection, permission grant or repository merge. These remain separately reviewed tasks.


## 2026-11-22: Own ChatGPT iPhone plugin — feasibility and implementation decision

**Decision status:** proposed architecture and source-backed feasibility assessment, not an implemented, installed, published or approved plugin. Requested by the owner to combine the strongest capabilities of the previously investigated projects. Target native product remains iOS 27+; older deployment advice above is historical. Use **iGentic** as the canonical project identity; “iGentic iPhone Connect” is a working product label only.

### Scope, evidence and coverage

This pass reconciles **107 distinct external GitHub repository identities** from the preexisting atlas and [iOS 27 runtime survey](IOS27_OPEN_WEIGHT_RUNTIME_SURVEY_2026_11_22.md). All 107 are assigned exactly once in the matrix below. This is a packaging/architecture classification of the existing research corpus, **not a fresh 107-repository code audit** or a claim to cover every repository/chat on the account. Apple framework pages, papers without repositories, transitive dependencies and unrelated user projects are outside that numerical count.

Additionally consulted the existing [seven-source audit](SEVEN_UPLOADED_REPO_SOURCE_AUDIT_2026_11_22.md), [five-runtime audit](FIVE_UPLOADED_IOS27_RUNTIME_SOURCE_AUDIT_2026_11_22.md), [completion plan](../PROJECT_COMPLETION_PLAN.md) and [physical validation report](../reports/iphone-air-validation-2026-11-22.md). The archived source-audit findings refer to those snapshots, not necessarily today's upstream code. Mimi Remote is considered separately as an existing remote-supervision setup, not invented as another repository identity. The connected Remote Desktop Commander tool catalogue was inspected for its device/file/process/session interface; its implementation and publication arrangement were not audited.

Eight current upstream READMEs and six top-level LICENSE files were fetched directly through GitHub on 2026-11-22. Blob identities below identify **documents**, not pinned complete releases or dependency audits:

| Upstream | README Git blob | LICENSE Git blob |
| --- | --- | --- |
| [mobile-next/mobile-mcp](https://github.com/mobile-next/mobile-mcp) | `413ae0323df899a27136d5e085f5236cbbb9fbe3` | `261eeb9e9f8b2b4b0d119366dda99c6fd7d35c64` |
| [callstack/agent-device](https://github.com/callstack/agent-device) | `1d0312d84aa724e820a787401bfa63e31180ef8d` | `e339c7e96e4f372b7f80d7ed7a19570dfc4f336d` |
| [OpenMinis/iCTRL](https://github.com/OpenMinis/iCTRL) | `80f7a6b86119a8261aa98e2a1402d10f3f192675` | `d645695673349e3947e8e5ae42332d0ac3164cd7` |
| [ipbtools/ipb](https://github.com/ipbtools/ipb) | `5681de699b01a8561f1781be73cd280d8b2ea6b4` | `452a50fab1bc5387efb6672d80690ed97e2c1057` |
| [DIYgod/pinky](https://github.com/DIYgod/pinky) | `5f02de36cc3790156afe90b174b5ad1afffc2023` | `57bc88a15a0ee8266c259b2667e64608d3f7e292` |
| [phoneuse-official/phoneuse](https://github.com/phoneuse-official/phoneuse) | `3843a46fe55976b5fea6420bc2cdfdb749100dc2` | Not reread in this pass; retain earlier source-review limits |
| [Jflick58/resident](https://github.com/Jflick58/resident) | `d2b017c4fe77e06ca92052a4505862021dc36de6` | Not reread in this pass; retain earlier source-review limits |
| [Raynan00/cell-use](https://github.com/Raynan00/cell-use) | `b970db789cf92228089372b08a57556c705b2798` | `d645695673349e3947e8e5ae42332d0ac3164cd7` |

Top-level LICENSE text currently identifies Apache-2.0 for Mobile MCP, iCTRL, Pinky and cell-use; MIT for agent-device and ipb. This makes them candidates for further review, not blanket clearance for bundled dependencies, Apple developer components, artwork, trademarks, model weights or redistribution. Existing AGPL/GPL, PolyForm, altered-MIT and source-available warnings elsewhere in the atlas remain relevant. A process boundary alone is not a license-compliance conclusion.

### What OpenAI currently supports

Official documentation fetched on 2026-11-22 establishes the following:

- **Plugin package:** reusable skills plus optional MCP server(s); new packages use root `plugin.json`, `mcp.json`, `skills/`, and optional `extensions.com.openai` metadata. A skill describes a workflow; it does not supply iPhone permissions or connectivity. [Build plugins](https://developers.openai.com/plugins/build/plugins)
- **Private connection:** ChatGPT can install a custom MCP server as a plugin, with read/write tools, via server URL or Secure MCP Tunnel. Workspace permissions still apply; account eligibility has not been checked here. [Custom MCP server](https://developers.openai.com/api/docs/guides/custom-mcp-server)
- **Private transport option:** Secure MCP Tunnel forwards requests from OpenAI to a private server through an outbound-running client. It requires appropriate organization/workspace access and a runtime credential. It is a possible later integration, not configured here, not proof of offline privacy, and not a production directory endpoint. [Secure MCP Tunnel](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels)
- **Public remote plugin:** stable public HTTPS MCP endpoint using Streamable HTTP, working authentication, verified publishing identity/domain, privacy information and OpenAI review. For private user actions, design OAuth 2.1 and authorization at every request. A temporary tunnel or an inaccessible laptop URL does not satisfy public submission. [Build MCP server](https://developers.openai.com/plugins/build/mcp-server), [review requirements](https://developers.openai.com/plugins/deploy/app-review)
- **Local desktop plugin:** local stdio MCP can package a host-side server. Public local-MCP submissions are currently restricted to approved/allowlisted partners; desktop-only plugins are installable from the desktop app and usable in locally running threads. Private/manual authoring is a separate path from public directory admission. [Desktop-only submission](https://developers.openai.com/plugins/deploy/desktop-only)
- **UI:** optional MCP Apps iframe with `_meta.ui.resourceUri` and the standard `ui/*` bridge; tools should work without the UI. Device selection, a task preview, current observation and stop button are appropriate. This does not itself provide native iPhone screen capture or low-latency video transport. [MCP Apps UI](https://developers.openai.com/plugins/build/chatgpt-ui)

Hardware/application-access-centric submissions may require product-specific review; the official migration/submission guidance explicitly asks developers to contact their OpenAI partner for such cases. Do not promise that a broad remote-iPhone-control plugin will be accepted merely because its MCP tools work. [Submission guidance](https://developers.openai.com/plugins/guides/submit-claude-plugin#complete-the-submission-requirements)

The current review page also excludes EU-data-residency projects from MCP submission and points to global projects. Record this as a publishing constraint to assess with the owner, **not permission to change residency or create an organization/project**. No organization, partner eligibility, billing, residency or distribution account was changed by this research.

### One product core, three explicit operating modes

| Mode | User-facing capability | Execution site and availability | Distribution assessment |
| --- | --- | --- | --- |
| **Native tasks** | Prepare and approve a reminder; later explicitly shared text/files and local voice | iGentic app and public Apple APIs. Foreground/user-triggered handoff first; Mac not required for the native task | Consumer iOS app candidate, subject to Apple review; ChatGPT connection is additional work |
| **Connected iPhone lab** | Observe a consenting test phone, inspect UI, navigate and verify a synthetic app task | Running trusted Mac + one developer adapter; USB first | Best first remote-control proof; local/private plugin first, public desktop distribution requires OpenAI eligibility |
| **Phone-resident experimental control** | Developer-service cross-app observation/input after setup | iCTRL or cell-use-style runtime on the phone, subject to lifecycle/signing/DDI/network constraints | Separate opt-in developer build. Not represented as normal App Store privileges or proven unattended phone autonomy |

Apple's public App Intents expose declared app capabilities to supported system surfaces. They do not establish an arbitrary remote-invocation channel from ChatGPT to every installed iOS app. ReplayKit provides screen recording/broadcast primitives, not the missing input-control capability. App Review rules require public APIs, respect for app containers and intended background modes. Apple's remote-desktop-client category is not permission to make an ordinary iPhone app a system-wide input server. These are architecture constraints, not a prediction of a particular submission outcome. [App Intents](https://developer.apple.com/documentation/appintents), [ReplayKit](https://developer.apple.com/documentation/replaykit), [App Review 2.5 / 4.2.7](https://developer.apple.com/app-store/review/guidelines/)

### Proposed architecture

```text
ChatGPT / Codex
  Plugin: skills + typed MCP tools + optional device/task UI
      |
      +-- local stdio (private desktop MVP)
      |       -> trusted Mac bridge -> one device-lab adapter -> iPhone test app
      |
      +-- authenticated HTTPS MCP (later private/web/public route)
              -> account/device-bound task service
              -> authenticated outbound companion connection
                   -> Mac bridge OR foreground iGentic iPhone companion

Every executor:
  validate identity + task + scope + expiry + current state
  -> existing iGentic policy and exact-action approval where required
  -> bounded execution -> independent readback
  -> verified / failed / cancelled / unavailable / unknownOutcome
```

The Mac lab lane extends the project without replacing the phone-alone product goal. iGentic's Swift authority must remain the canonical action path. A future Mac gateway must delegate to it or implement an explicitly reviewed compatible boundary; **there is no already-proven network bridge from the current Swift kernel to these MCP servers**. Wire that boundary before exposing mutations.

The public route needs deliberate device pairing and a reachable service; a remote ChatGPT server cannot reach the phone's or Mac's loopback address directly. Use an outbound authenticated companion channel to avoid exposing developer endpoints. Phone sessions can report `needsForeground` and require the user to open the companion. A push/deep link is a handoff mechanism, not guaranteed background execution. Lock, suspension, network loss and expired signing must produce explicit unavailable/paused states.

ChatGPT-assisted mode sends the selected inputs/tool results to OpenAI. A local driver, local model or encrypted transport does not make that conversation offline. Keep a separate native offline mode. Screen/AX data may contain private notifications; minimize scope before capture, prefer synthetic/app-scoped structured state, redact before egress, and disclose destination. No screenshot stream or arbitrary personal app observation is enabled by this design.

### Reuse decision for the complete indexed corpus

Each repository below appears in exactly one row; details and source caveats remain in its original atlas/survey entry. “Adapter” means a candidate for bounded integration, not approved code reuse or an executed test.

| Family | Existing repository identities | Plugin decision |
| --- | --- | --- |
| Host device adapters | `mobile-next/mobile-mcp`, `mobile-next/mobilecli`, `callstack/agent-device`, `HyunSeob/iphone-cli`, `niklas-schmidt-dev/mobdev`, `blitzdotdev/iPhone-mcp`, `mharizanov/iphone-agent`, `phoneuse-official/phoneuse`, `appium/appium-mcp`, `leeguooooo/iphone-use`, `semsturgut/open-iphone-use`, `Derrors/iphone-control`, `ghosthand-dev/ghosthand`, `Array-Ventures/open-phone`, `mobiumdev/mobium`, `timurcatakli/thumbly`, `WaziXuan/iospilot`, `jkcoxson/devicehub_rs`, `carrotciallo/poki-for-linux`, `ipbtools/ipb`, `ChrisThoma/ios-device-mcp`, `UgeeCodes/iOS-agent-bridge`, `hughlee824/iphone-use` | Wrap a selected adapter behind narrow iGentic tools; host remains necessary. Existing MCP support helps packaging but does not confer ChatGPT publication eligibility. PolyForm/mixed/AGPL and private-API caveats remain as recorded above. |
| Developer transport and QA infrastructure | `danielpaulus/go-ios`, `appium/WebDriverAgent`, `appium/appium`, `google/artemis` | Internal lab dependency or comparison; do not expose raw developer HTTP, shell or installation authority to ChatGPT. |
| Phone-resident cross-app experiments | `JosssphZhou/poki`, `EliotAndres/iphone-use-app`, `Raynan00/cell-use`, `OpenMinis/iCTRL`, `LLLLLayer/Eiscue`, `Turbo1123/roubao` | Possible phone-side adapter, subject to actual detached-phone, background, signing and revocation tests. Developer services/private interfaces; no consumer App Store guarantee. Preserve individual license constraints. |
| Hybrid phone/host agent products | `rounak/PhoneAgent`, `DIYgod/pinky`, `imsai-sh/fish-pocket` | Study session UX, gateway approval and handover; integrate the device boundary only. External model accounts and component licenses remain separate. |
| Native agent/workspace products | `OpenMinis/OpenMinis`, `Jflick58/resident`, `cagataycali/loopl`, `sandeepvijayarao09/Anu-iOS`, `JiangNanGenius/floe-agent`, `meshoklv/pocket-agent`, `isaced/pokeet`, `dannote/pi-ios`, `off-grid-ai/OGAM`, `trufae/pmai`, `Maximoff19/makima`, `everettjf/dsh-ios` | Selected native capabilities can sit behind our tool contract. MCP clients inside these apps are not automatically MCP servers for ChatGPT. Reuse bounded context/diff/workspace patterns, not entire apps or direct model-to-write authority. |
| Public action and shortcut bridges | `heznpc/AirMCP`, `truth0530/mcp-server-ios-shortcuts`, `VladUZH/intents-mcp`, `recursechat/mcp-server-apple-shortcuts` | Useful action-surface patterns; current Mac bridges do not magically run phone shortcuts remotely. Implement and verify our own native App Intent/foreground handoff. |
| Simulator tooling | `mobile-dev-inc/Maestro`, `joshuayoes/ios-simulator-mcp`, `facebook/idb`, `minitap-ai/mobile-use` | Development/test plugin capabilities only, with simulator-labelled results. No physical-device promotion. |
| Inference engines and provider adapters | `huggingface/AnyLanguageModel`, `ml-explore/mlx-swift`, `ml-explore/mlx-swift-lm`, `ml-explore/mlx-swift-examples`, `ggml-org/llama.cpp`, `mlc-ai/mlc-llm`, `huggingface/swift-transformers`, `pytorch/executorch`, `apple/coreai-models`, `anthropics/ClaudeForFoundationModels`, `no-problem-dev/swift-llm-local`, `pgorzelany/swift-llama-cpp`, `john-rocky/coreai-kit`, `simonmaddox/foundation-models-byo-model` | Optional native model component, not a remote-control plugin by itself. Start with existing Apple proposal path; add one measured provider only. Anthropic adapter is remote; model weights and transitive packages need separate admission. |
| Speech and conversational audio | `ggml-org/whisper.cpp`, `soniqo/speech-swift`, `fikrikarim/volocal`, `FluidInference/FluidAudio`, `argmaxinc/argmax-oss-swift` | Optional local ASR/VAD/TTS inside companion app. FluidAudio ASR/VAD first candidate, Argmax comparison; microphone, German quality, interruption and model licensing must be tested. |
| Harness, persistence and sandbox components | `finnvoor/PiDurableKit`, `Think-Define-Create/DurableAgents`, `AkinoKaede/AgentKit`, `apple/foundation-models-utilities`, `rudrankriyam/FoundationModelsAgent`, `christopherkarani/Swarm`, `SpaceCorps/open-apple-models`, `rryam/FoundationModelsKit`, `mzbac/SwiftAgent`, `sabby3861/Arbiter`, `dsaad68/deepagents-swift`, `Tom-Ryder/AgentRunKit`, `abra-code/mlx-agent`, `mweinbach/just-bash-swift` | Compare individual mechanisms: lazy discovery, context budgets, recovery, bounded virtual workspace. Retain iGentic policy and one-shot ledger; never import an alternative authority stack by default. |
| Evaluation and GUI research | `zai-org/Open-AutoGLM`, `X-PLUG/MobileAgent`, `ljang0/iOSWorld`, `software-mansion/app-control-bench`, `ananasDDA/pocket-ai-lab`, `john-rocky/edge-llm-bench`, `Tongyi-MAI/MobileWorld`, `Tongyi-MAI/MAI-UI` | Test design and external baselines, not shipped tool authority; retain Android/simulator/physical and source-only distinctions. |
| Model and local-app UX references | `john-rocky/coreai-model-zoo`, `a-ghorbani/pocketpal-ai`, `luckeyfaraday/local-models`, `JaviChulvi/hermit`, `Reezxy/Local-Ai-Vision-App`, `kilianbalaguer/Voltaire` | Study downloads, memory, RAG and multimodal UX. No need to ship these applications in our plugin; Voltaire restricted reuse remains excluded pending license clearance. |
| Reverse-direction remote supervision | `pocketctl/pocketctl`, `K9i-0/ccpocket` | Phone controls a host agent. Useful pairing/progress/approval UX, but opposite direction from ChatGPT operating an iPhone. |
| Out-of-target architecture references | `Kastarter/phone-agent`, `FluidInference/FluidUse` | ESP32 extra hardware and macOS Accessibility respectively; do not include as iPhone production backends. |

Existing owner projects remain knowledge inputs rather than new runtime dependencies: the completion plan already assigns provenance/context to private-brain, execution practice to dev-playbook, fixed evaluation to slm-lab and evidence boundaries to regulation-lab. Mimi/CC Pocket/PocketCtl supervise a host from the phone; that reverse-direction workflow can inform pairing and approvals but does not supply ChatGPT-to-iPhone input.

### What to combine first

1. **iGentic** supplies the product authority, task receipts, native reminder path and verified outcomes.
2. **Existing PhoneUse/WDA/ARTEMIS lane** supplies the cheapest initial lab adapter because setup and some historic device observations exist. Current WDA readiness is not assumed: the latest report records XCTest initialization failure. Recover once under a bounded diagnostic, then select a measured alternative if needed.
3. **agent-device** is the preferred first alternative for a typed host adapter (current README documents CLI, stdio MCP and typed Node API). **Mobile MCP** is the comparison baseline for tool coverage and mirroring. Expose a small reviewed subset rather than their entire install/delete/clipboard/log catalogue. Do not run three drivers against one phone.
4. **iCTRL** is the first phone-resident research candidate because source and limited authenticated device-info evidence already exist. **cell-use** is a separate iOS-27 transport alternative. Authenticated pairing is not per-action approval.
5. **Pinky** contributes gateway enforcement and human takeover patterns; **ipb/Eiscue** contribute freshness and uncertain-result handling. Private-ABI, pre-alpha and license limits remain.
6. **Resident + Pocket Agent** contribute selective context and immutable preview-before-write patterns. **FluidAudio** is the first later speech component, with Argmax as comparator; **Volocal** informs interruption UX after the documented concurrency/readiness defects are addressed.
7. Keep Apple's current local proposal path for the native product. MLX/GGUF/Core AI is optional measured work; ChatGPT already supplies a planner for the plugin, so a second local planner is not a prerequisite.

No third-party app is copied wholesale; there is one active backend per session and no silent driver/provider fallback. Unsupported capability returns a typed reason.

### Proposed first tool surface and behavior

These are design names, **not installed tools**:

| Tool | Intended effect | Contract |
| --- | --- | --- |
| `iphone_list_devices` | Return only paired, account-authorized device aliases and availability | No raw UDID/serial, installed-app inventory or personal names by default |
| `iphone_get_capabilities` | Describe actual backend/mode, observed readiness and restrictions | Separate supported, configured and verified; never infer readiness from installation |
| `iphone_start_session` | Acquire a short scoped session/lease | State-changing; bind account, device, allowed app, scope, expiry and explicit capture consent |
| `iphone_observe` | Obtain permitted structured app state; screenshot only when in scope | Bound freshness, orientation/app/session; content remains untrusted and minimized |
| `iphone_prepare_action` | Create immutable typed action preview | No device mutation; persisted task/approval state is still state-changing metadata |
| `iphone_execute_action` | Execute the exact approved proposal once | Resolve receipt on trusted executor; caller cannot supply `approved=true`; bind target/payload/expiry |
| `iphone_get_action_result` | Read receipt and independently checked outcome | Dispatch accepted is not success; no broad personal-data enumeration |
| `iphone_stop_session` | Cancel pending work and invalidate lease | Idempotent stop; cannot undo an already dispatched effect; reconcile unknown outcomes |

First action: open/navigate within our signed synthetic Diagnostics app and verify a unique nonpersonal marker. Avoid arbitrary coordinate tap/type, shell, free-form RPC, unrestricted URLs, app uninstall, pairing export and permission changes in the initial catalogue. Add typed UI actions only with observation freshness, target checking and a policy that acknowledges ambiguous semantic effects; a “Send” label detector is not an authorization system.

Later native reminder handoff: ChatGPT prepares the structured draft; the phone displays exact title/time/list, the person approves on the phone, and the existing EventKit workflow writes/readbacks. This requires a new transport integration. The prior approval for **one** test reminder is not permission to generate another reminder during plugin development.

MCP annotations must reflect actual behavior: starting a session, creating a persisted proposal or launching an app changes state. Reading screen data can still be privacy-sensitive. Annotations guide the client but never enforce server authorization. Task/receipt references returned to the model must be minimal, account-scoped and non-secret; approval secrets and pairing keys never appear in tool outputs or UI metadata.

### Concrete implementation order and acceptance

| Slice | Deliverable | Acceptance before promotion |
| --- | --- | --- |
| 1. Private desktop contract | Plugin package + MCP server with fake device backend; existing policy adapter boundary | MCP initialize/list/call; strict schemas; unknown tools denied; wrong identity/scope, replay, expiry, cancellation and unknown-outcome tests; no device access by default |
| 2. First real device path | Exactly one existing/pinned host backend, initially read-only and own-app scoped | Real ChatGPT/Codex invocation to physical phone; observed marker and independent result; unplug/lock/driver failure returns unavailable; stop releases lease/processes |
| 3. Native useful task | Foreground companion handoff to existing reminder proposal/approval/writer | Draft received unchanged; denial/changed/expired receipt causes zero writes; separately approved single synthetic write/readback; process death never replays a possible write |
| 4. Private remote access | OAuth/device-bound service or eligible Secure MCP Tunnel; no raw WDA/iCTRL exposure | Real end-to-end remote call; cross-account/device isolation, token revocation, disconnect, duplicate delivery, app suspension, egress and retention checks |
| 5. Product UI and distribution | MCP Apps device/task card, pairing/stop/recovery UX; consumer companion and developer lab clearly separated | Clean installation, accessibility/localization, publishing eligibility, dependency/license review, privacy policy and reproducible reviewer demo on supported surfaces |
| 6. Optional capabilities | Voice, selected workspace tools, stronger local runtime, detached-phone experiment | Per-capability physical evidence, resource budget and adversarial cases; no automatic authority expansion |

The first prototype can use stdio/local test tooling without an extra model API call. Public operation may require hosting, maintenance, a developer distribution account and current platform entitlements. Do not advertise permanent zero cost: exact provider costs/quotas are unverified. No paid service, cloud inference fallback, additional local model or billing activation is part of this decision.

**Required fault cases:** stale observation after rotation/app switch; indirect prompt injection in UI text; changed payload after approval; double submission; receipt expiry; concurrent clients; signing expiry; connection loss before versus after dispatch; offline/suspended companion; stop during inference/action; wrong tenant/device; revoked credentials; permission denied; unavailable model; incomplete capture/redaction. Unknown effect must be reconciled, never automatically retried through another backend. Readiness is per capability and mode, not a single global “connected” flag.

**Current evidence limits:** the latest physical report contains successful signed native app/model probes and one earlier manual approved reminder write/readback; German model results varied and no overall reliability score is established. iCTRL device-info/config checks are not general touch-control evidence; WDA has both historical navigation evidence and a newer initialization failure. No ChatGPT-to-iPhone plugin call, network approval bridge, remote companion, public submission, sustained screen stream, Mac-detached control or full lifecycle acceptance was executed in this assessment.

**Next causal implementation:** build slice 1 and then prove one harmless physical task through the intended plugin path. Keep existing feature PR #390 and research PR #379 unmerged; this source assessment adds no device permissions or execution authority.
