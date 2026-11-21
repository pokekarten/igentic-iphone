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
5. Separately test the **on-phone** path with the Mac disconnected, explicitly observing whether lock/background state suspends the agent.
6. Make a **decision after actual measurements**. The lowest-friction README is not automatically the safest or most autonomous tool.

### Stop rules / privacy / legal checks

- Never install unreviewed outside agent code onto a personal phone or run against banking, authentication, health, messages or private work data.
- Prefer pinned commit or release and hash-check binaries; do not use `curl | sh` blindly or give arbitrary MCP clients global device control.
- Keep mobile-host MCP on stdio or authenticated local-only transport. Treat WDA HTTP/network exposure as a security risk.
- No telemetry/cloud fallback by default. Explicitly inspect whether the connected LLM client transmits screen content.
- Inspect license **per pinned revision** before vendoring or derivative use; Poki's AGPL-3.0-only license is particularly important.
- Keep authorization **outside model prompts**: deterministic action types, app/device allowlists, one-shot receipts, rollback/timeout, redacted logs.
- iOS App Store distribution, device-management APIs, XCTest/Developer Mode and any private API must be assessed separately for permitted deployment. This atlas is not a promise of an App Store-compatible system-wide agent.

## Maintenance

- Review on **iOS major releases**, agent-control API changes, new device test evidence, upstream license/security advisories, or every 90 days.
- Evidence required for promotion to "works on iGentic physical iPhone": exact upstream SHA/release, test script, iPhone model + iOS version, Mac/Xcode versions when present, no-personal-data test transcript, expected/actual results and privacy review.
- The list is manually curated, not exhaustive; a repository existing or appearing here is not an endorsement.
- Durable project safety, evaluation and platform contracts remain canonical in [`docs/KNOWLEDGE_MAP.md`](../KNOWLEDGE_MAP.md), [`docs/SOURCE_VERIFICATION.md`](../SOURCE_VERIFICATION.md), [`docs/app-intents-safety.md`](../app-intents-safety.md) and [`docs/model-research/RUNTIME_EVIDENCE_MATRIX.md`](../model-research/RUNTIME_EVIDENCE_MATRIX.md).
