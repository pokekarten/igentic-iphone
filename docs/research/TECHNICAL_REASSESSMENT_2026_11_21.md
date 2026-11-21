# iGentic iPhone: technical reassessment and execution priorities (2026-11-21)

**Decision status: proposal for review, not an implemented architecture change.** This is the engineering interpretation of current source code, source-backed 2026 Apple platform changes, and the adjacent agent ecosystem. Source claims are **not** iGentic device results. This document does not authorize any new iPhone permissions, data handling, model downloads, remote control or real side effects.

**Repository baseline inspected:** `main` at `0bb24b750d90da9f810af9648aae5fc2058a7069` (2026-09-24). The file tree, Swift agent kernel, app shell, model strategy, tests and existing ARTEMIS host adapter PR were inspected through GitHub. Relevant outstanding issues include [owner-enforced commit-email privacy #286](https://github.com/pokekarten/igentic-iphone/issues/286) and the [dependent content admission #287](https://github.com/pokekarten/igentic-iphone/issues/287). No full repository checkout, iOS simulator, hardware test or third-party runtime execution was available in this research pass.

**Verified owner blocker (2026-11-21):** GitHub API `GET /branches/main` returned `protected: false`, and `GET /rulesets` returned `[]`. An individual `commit-email-privacy` job can be green while **merging is not required to honor it**. The branch protection detail endpoint returned 403 to this integration. The owner must configure and verify the default-branch ruleset as already spelled out in [#286](https://github.com/pokekarten/igentic-iphone/issues/286); this is a real trust boundary, not a reason to write more checker code.

## 1. What earlier decisions still make sense?

| Earlier assumption / implementation | Reassessment | Evidence and next action |
| --- | --- | --- |
| Swift `PolicyEngine`, `ApprovalManager`, receipt binding and `AuditLog` own authority | **Keep.** This is a differentiator against unconstrained GUI agents. A model or paired MCP client never approves its own action. | Current `ios/Sources/AgentCore/` has these components, with tests. Preserve their invariants through any new adapter. |
| Read-only diagnostic app and synthetic action simulation | **Keep as test fixture, stop treating as the destination.** The shell is not yet a useful standalone agent. | Make one short, user-initiated, app-scoped end-to-end flow measurable after admission gates. |
| Every model/backend needs bespoke iGentic infrastructure | **Reconsider.** OS 27 Foundation Models now provides a shared `LanguageModel` protocol and `LanguageModelSession` for Apple, compliant third-party and on-device model adapters. | Prefer a **thin, capability-checked** model-proposal boundary over another general framework. Retain an OS 26 fallback rather than raising the deployment floor by accident. |
| Fine-tune FunctionGemma 270M first | **Defer specialization as a product prerequisite.** Do not discard the frozen benchmark or model candidate: first compare Apple system model, existing Qwen untouched baseline and the small-router candidate where actually available. | `MODEL_STRATEGY.md` and `docs/model-research/` remain canonical; do not re-train on the immutable test set or claim iPhone parity from Mac tests. |
| Large local models are needed to plan every action | **Challenge.** Try short typed intents, curated tools and deterministic state transitions. A full GUI VLM may be necessary only for UI tasks that have no safer public API. | Compare iOS 27 Apple model, `Resident`/`loopl` tool-constrained harnesses and `apple/foundation-models-utilities` context management. |
| The iPhone should be Mac-free at runtime | **Keep, but define precisely.** No continuously available Mac for the **phone product**; Mac-hosted ARTEMIS/Mobile MCP remain development/acceptance tools. | Track installation Mac usage, recurring signing, OS requirement, VPN/Developer Mode and cloud model dependence separately. |
| iOS cross-app control can be treated like an App Intents tool | **Reject.** App Intents expose declared actions; developer-service / XCTest / DDI / loopback-VPN GUI control is a different, privileged experimental channel. | Separate product API actions from optional owner-consented sideloaded laboratory mode; do not promise App Store-compatible arbitrary UI control. |
| Risk score, tool registry or memory can grant permission | **Continue to reject.** Diagnostic risk metadata, tool availability and memory are not authority. | No new bypass in `AgentKernel`, `TaskRouter` or `ToolRegistry`; treat notification/webpage text as untrusted data. |
| Extra approval documents, slots and process gates increase quality | **Only when causal.** Existing hard privacy/merge gates are warranted; stale handoffs, duplicate PRs and hypothetical gates are not product capabilities. | Maintain one active implementation PR; record evidence rather than generating new tasks for activity. |

## 2. New official Apple capabilities that change the options

**iOS 27 / Xcode 27: assess in a separate, version-gated prototype, never silently require these APIs on iOS 26.**

| Official source | 2026 change | iGentic implication |
| --- | --- | --- |
| [Apple Foundation Models](https://developer.apple.com/documentation/foundationmodels) and [iOS 27 WWDC overview](https://developer.apple.com/ios/whats-new/) | Native `LanguageModel` abstraction for Apple on-device, Private Cloud Compute and compatible external provider models, common session/tool/guided-generation APIs | Model diversity no longer means **automatically** writing a new session abstraction. Our own authority remains **outside** that session. A provider package does not imply a local model. |
| [Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels) | Token counting, context size inspection, new tool-calling modes, iOS 27 improved model and errors | Build runtime `availability` and `capabilities` checks; record OS/build and tool-call behavior rather than freezing a single system-model revision that Apple controls. |
| [Apple model context guide](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window) | The system on-device model uses a **4,096-token shared context window**; inspect the actual `contextSize` at runtime | Keep tool schemas, chat history, skills and action proposals compact. Avoid assuming a long autonomous context fits; emit explicit `contextSizeExceeded` failures. Other providers can have different limits. |
| [Apple Evaluations framework](https://developer.apple.com/documentation/evaluations) | Native Swift metrics and trajectory/tool-call evaluation in Xcode 27 | Map frozen iGentic benchmark cases to an **additional** evaluated backend. Preserve existing evaluator metrics and schema; verify cross-backend equality, do not silently replace the original evaluation contract. |
| [apple/foundation-models-utilities](https://github.com/apple/foundation-models-utilities) | Apple-maintained utilities for Chat Completions providers, JIT skills, rolling/summarized context and completed-tool-call removal | **First third-party-ish package to inspect is the Apple one**, not a stack of parallel agent frameworks. Pin an exact revision and check platform/compiler/API compatibility. |
| [apple/coreai-models](https://github.com/apple/coreai-models) | Official export recipes and Swift runtime helpers for Core AI models on **iOS 27+** | Prefer real export/runtime evidence for custom models; do not equate existence of recipes with iPhone Air latency or memory results. |
| [App Intents changes](https://developer.apple.com/documentation/updates/appintents/) | More execution targets, app-schema integrations and system shortcuts | Favor *typed, user-invoked, app-scoped* actions before screenshot-based cross-app control. |
| [Apple app-review rules](https://developer.apple.com/app-store/review/guidelines/) and [Developer Program agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/) | Distribution remains constrained to documented APIs and approved permissions | Maintain separate **App Store-compatible** and **developer/sideload lab** capability profiles. An upstream demo is not distribution clearance. |

The iPhone Air appears in Apple's [Apple Intelligence eligibility guidance](https://support.apple.com/de-de/121115), but a given phone's enabled features, locale, OS, model readiness, storage and restrictions must still be checked **on that device**. `PrivateCloudComputeLanguageModel` and cloud-based custom providers are **non-local delegation** in iGentic, regardless of privacy properties claimed by the vendor. Do not enable them by default.

### Concrete Qwen3-0.6B Core AI path, without premature fine-tuning

The current model manifest already lists `Qwen/Qwen3-0.6B` as the untouched Apache-2.0 multilingual baseline, with an immutable revision in the existing Qwen adapter contract. **Apple now ships a directly relevant official export recipe** in [apple/coreai-models/models/qwen3/README.md](https://github.com/apple/coreai-models/blob/main/models/qwen3/README.md), including an iOS 27 export for the same *model family*:

```bash
# Examples to review on an eligible Xcode 27 Mac; NOT executed in this reassessment.
uv run coreai.llm.export Qwen/Qwen3-0.6B --dry-run
uv run coreai.llm.export Qwen/Qwen3-0.6B --platform iOS
```

These commands alone are **not** a pinned benchmark or proof that our frozen `Qwen3-0.6B` revision, tokenizer, chat template, tool encoding, quantization and output profile exactly match the upstream export default. Do not execute `--platform iOS` automatically: first inspect and SHA-pin Apple's exporter, third-party dependencies, model snapshot and generated artifact. The source also warns that exported model memory may exceed an iOS app's memory allowance; an optional increased-memory entitlement must **never** be silently enabled. Evaluate default entitlement/no entitlement first, with a small known fixture, then measure an explicitly authorized alternative.

**New memory methodology references:** [Pocket AI Lab](https://github.com/ananasDDA/pocket-ai-lab) distinguishes an app's *actual per-process jetsam allowance* from device advertised RAM and Metal working-set budgets. [edge-llm-bench](https://github.com/john-rocky/edge-llm-bench) publishes reproducible iPhone/Mac/Android runs for Core AI, MLX, llama.cpp, LiteRT-LM and other engines, preserves raw trial data and failure outcomes, and explicitly avoids cross-session headline rankings. These are **upstream methodologies and other people's device results**, not an iGentic iPhone Air benchmark.

The revised minimal model decision tree is: (a) deterministic fixture and Apple on-device system model when available; (b) untouched, revision-pinned Qwen3-0.6B using *one* eligible iOS runtime (Core AI 27 or a separately pinned older-OS MLX/GGUF path); (c) another model only if the exact benchmark reveals an unacceptable functional deficit. Record tool-call correctness, German intents, privacy, per-process memory limit, model/encoder compatibility, first-token latency, steady-state tokens/s, warm/cold conditions, cancellation, thermal and energy over repeated sessions. New Qwen3.5 small models are exploratory candidates, not substitutes for frozen untouched baselines.

## 3. Compare small harnesses before adopting one

| Candidate | What we should learn | Decision |
| --- | --- | --- |
| [Apple Foundation Models utilities](https://github.com/apple/foundation-models-utilities) | Native session history transformation, just-in-time skills and a supported provider adapter | **Evaluate first** in an OS-27-only sample; keep upstream code out of `main` until tested |
| [Resident](https://github.com/Jflick58/resident) | Scoped/lazy tool disclosure, small-model prompt economy, optional MCP and memory | Study architecture; benchmark against our simple deterministic tool surface |
| [loopl](https://github.com/cagataycali/loopl) | Compact Swift agent loop, model → tool → result, typed events and approvals | A useful independent lean-harness baseline; avoid replacing Swift authority |
| [FoundationModelsAgent](https://github.com/rudrankriyam/FoundationModelsAgent) | Receipts, tool budgets, checkpoints, per-run policy and model routing | **Overlap audit needed**: may re-implement `ApprovalManager`/`AuditLog`; prefer borrowing isolated concepts over introducing a second policy engine |
| [Swarm](https://github.com/christopherkarani/Swarm) | Swift concurrency, typed tools, offline model loops and optional integrations | Evaluate as a comparator, not an automatic new dependency |
| [ClaudeForFoundationModels](https://github.com/anthropics/ClaudeForFoundationModels) | External model provider via the **native** `LanguageModel` protocol | Proof of adapter architecture, **not** proof of privacy/local execution; require delegation consent |
| [AnyLanguageModel](https://github.com/huggingface/AnyLanguageModel) | API compatibility on older toolchains/providers | Reassess the need for a parallel API shim now that OS 27 has a first-party provider protocol |

**Selection rule:** choose **zero or one** agent harness after a measured gap appears. Avoid stacking two policy engines, two approval systems or three model abstractions. First-party frameworks plus our existing Swift gate may be enough.

## 4. Separate shipping actions from unrestricted phone UI control

| Track | Scope | Candidates | Release rule |
| --- | --- | --- | --- |
| **A — product path** | Local iGentic SwiftUI/Shortcuts/App Intents, bounded actions such as draft/reminder after explicit user approval | Existing `AppActionCoordinator` + `CreateReminder` bindings, Apple public App Intents/EventKit | Official API + policy-gated `ApprovalReceipt`, independently verified outcome, audited without raw private data |
| **B — optional lab path** | Experimental cross-app screenshot, tap, type and navigation on an owned, sacrificial iPhone | [iphone-use-app](https://github.com/EliotAndres/iphone-use-app) (source claims iOS 26+), [iCTRL](https://github.com/OpenMinis/iCTRL), [Poki](https://github.com/JosssphZhou/poki), [Pinky](https://github.com/DIYgod/pinky) | Developer Mode/signing/pairing/entitlement and license review; no production/private account testing; per-action approval **even if pairing succeeded** |
| **C — developer acceptance** | Simulators and attached-device diagnostics via a running Mac | Existing [ARTEMIS PR #378](https://github.com/pokekarten/igentic-iphone/pull/378), Mobile MCP, agent-device, Maestro (simulator) | Development/test tooling only. Never describe the host adapter as a phone-native agent. |
| **D — defer** | Unattended third-party messages, payments, wallet, password-manager control or banking automation | None selected | No implicit authorization, no credential/OAuth leakage and no blanket all-app access |

**Critical OS split:** `cell-use` phone-control runtime and `iphone-cli` direct-control path advertise **iOS 27+**; their package/iOS deployment targets are not evidence that full iPhone automation works on iOS 26. On iOS 26, the iPhone-use-app and iCTRL paths deserve **source/security review**, not a claim of successful operation.

A paired device-agent transport can grant much broader authority than the app's declared action. Exposing its tool directly to a language model bypasses iGentic. A future bridge must bind **user action, exact app/device, sanitized args, receipt, TTL, execution count and audit** before any side effect. Treat screenshots and UI labels as **untrusted data**, not instructions. App switching after the preflight must not be considered confined by a natural-language test prompt.

## 5. Concrete shortest path to a useful product

1. **Unblock repo admission:** owner-enforce the already implemented commit-email privacy status check ([#286](https://github.com/pokekarten/igentic-iphone/issues/286)), then evaluate [#287](https://github.com/pokekarten/igentic-iphone/issues/287). These GitHub settings cannot be made authoritative by adding another doc or optional CI. Confirm enforcement on a **real PR and protected `main`**.
2. **Pick one measurable app-scoped task:** a human-approved **create reminder** from a synthetic user request through a typed draft, destination binding, authorization and result verification. Current `main` has a **pre-save** foundation, not a proven real save. Do not enable side effects until authorization, privacy and review constraints are satisfied.
3. **Make the proposal backend interchangeable:** compare a fixed proposal fixture against the existing `AgentKernel` policy path; add an opt-in OS-27 Apple model spike **after** the mandatory repo gates and approvals. No raw user data; no mandatory OS floor change.
4. **Evaluate exact cases before fine-tuning:** reuse `igentic-action-benchmark-v0.jsonl` untouched; track allowed/blocked tool suggestions, wrong arguments, omissions, recoverability, latency, token count, and number of approval requests. Use Apple's Evaluations framework as *additional corroboration* only.
5. **Device acceptance:** macOS Xcode simulator first (real compiled app and synthetic data), then explicit owner-approved iPhone Air runs, recording iOS version, language, model availability, battery/thermal and safe cancellation. Do not turn unit-test green into device readiness.
6. **Optional GUI research:** only after Track A demonstrates a safe completion path, compare **one** lab driver (iCTRL vs iphone-use-app) in a disposable context. The ARTEMIS Mac path is a QA comparator, not a product dependency.

### Exact acceptance gates for the first useful action

- Exact draft/payload/destination match; a user-visible approve or deny decision; an approval cannot be replayed.
- One side effect **at most**; failure, timeout, cancellation and interrupted authorization do not create duplicate reminders.
- Read-only EventKit discovery does not enumerate unrelated existing reminders; target changes invalidate the draft.
- Sensitive information, model transcripts, raw source/account identifiers, and credentials are not written to public audit evidence.
- Actual saved state is verified against expected state (with a privacy-preserving verification strategy), separate from a model's "done" text.
- Source code, build/test IDs and physical-device evidence remain distinct.

## 6. What to simplify or archive later (after verification)

- **Historical model-first sequencing:** specialization should not block a basic safe user action. Keep frozen experiments as research, not the product-critical path.
- **Old phase-0 conclusions:** `docs/local-runtime-review.md` still says "runtime work should not start yet" from June 2026 even though model-runtime *interfaces* and synthetic diagnostics are now present. Replace the outdated temporal claim without inventing actual model runs.
- **Duplicated controller/handoff machinery:** use live issues/PRs rather than resurrecting obsolete five-slot/Brain coordination or creating parallel agent PRs.
- **Unrelated workflows:** the repository tree includes multiple `.github/workflows/actuarial-*` jobs. **Audit current use, triggers, secrets, and ownership** before deciding if they belong in iGentic. Do not remove or run them blindly.
- **Vendor-specific policy:** use the existing deterministic Swift rules; do not adopt an upstream "safety gateway" as a replacement without an adversarial test.

### Proof boundary and blockers

This review **does not** claim Apple framework compilation, physical-device behavior, model benchmarking, protected-branch enforcement or a working iOS 27 app. The available Mac runner is not connected in this run. A source page saying "works on iPhone" is not enough; upgrade evidence only after an independently observed test.

**Next decisive question:** can we get **one** safe, end-to-end, user-approved action working and measured on iPhone Air while maintaining the Swift policy, privacy and audit requirements? Answering this is more valuable than adding another list of 50 repos or another theoretical coordinator.

## 7. Latest-OS and Xcode 27.2 execution plan (2026-11-21)

**Changed planning assumption:** The owner reports the Mac and iPhone have their newest OS releases and Xcode is now installed. This is **user-reported setup, not a remotely verified OS/Xcode build**. The connected Mac endpoint was offline during this research. Do not infer that Xcode 27.2, iOS 27.2, an installed simulator, Apple Intelligence model assets, Developer Mode or a paired target were actually observed. For this work, **prefer iOS 27/Xcode 27 capabilities**, while retaining the existing iOS 17 package floor until a deliberate compatibility decision.

**Verified official release:** [Xcode 27.2](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes) shipped on 2026-10-30, with Swift 6.4, iOS 27.2 SDK and macOS Tahoe 26.6+ requirement. Xcode 27.3 beta is a separate non-default option. Xcode 27.2 also adds a JSON-based `.xcproj` format: **do not automatically convert** the existing working diagnostics project.

### A. First-party Mac and connected-device baseline — execute locally only

Run these non-mutating checks first on the owner-authorized Mac. Keep real device UDIDs, screenshots and signing/account data **off GitHub**:

```bash
sw_vers -productVersion
xcode-select -p
xcodebuild -version
xcrun swift --version
xcrun simctl list devices available
xcrun devicectl list devices
```

**Prefer Apple's Xcode MCP bridge before adding another host-side controller.** Apple documents the following opt-in Codex setup in [Giving external agents access to Xcode](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode):

1. Open **Xcode → Settings → Intelligence → Model Context Protocol** and set **Allow External Agents to Use Xcode Tools → While Xcode is Open** (not unrestricted always-on access).
2. Open the reviewed iGentic Xcode project. With the owner's consent, on that Mac run `codex mcp add xcode -- xcrun mcpbridge`, then `codex mcp list`. This changes local Codex MCP configuration and must **not** be assumed performed by the research PR.
3. In **Xcode → Open Developer Tool → Device Hub**, prepare a disposable iOS 27 simulator. Apple's [Device Hub guide](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub) also documents **Pair Nearby Device** for physical devices on iOS 27+, using owner-confirmed pairing/Developer Mode. Keep a physical personal phone out of the first cross-app automation pass.
4. Use only owner-approved build, test, diagnostics and read-only device enumeration initially. Record the exact simulator runtime and build ID. Xcode MCP/Device Hub are developer tools; they **do not grant the iGentic app general iOS sandbox privileges**.
5. **Never** turn on a global unsafe 'allow all agents' mode just to bypass Xcode prompts; keep consent scoped to the active development session.

**ARTEMIS [Draft #378](https://github.com/pokekarten/igentic-iphone/pull/378)** stays a test adapter for comparison, but no longer needs to be the mandatory starting point for Xcode build/test/device observation. Its upstream Python, WDA and model-provider surfaces still require their own review.

### B. First useful phone capability, not another research framework

The exact current `main` file tree contains **no AppIntent implementation**. `ios/Sources/AgentCore/AppleFoundationModelsRuntime.swift` checks model **availability**, not an end-to-end agent inference/action session. `ios/Sources/AgentCore/AppActionCoordinator.swift` and the reminder UI are intentionally side-effect-free; the production reminder save remains gated.

**Smallest product sequence (avoid overlapping implementation work; respect #286 → #287, ARTEMIS #378 and the now-open independent read-only App Intent #380):**

1. **Read-only App Intent first:** a user-invoked iGentic Diagnostics/Task Status intent returning only synthetic or redacted data. No contacts, account identifiers, reminders save or global app control. Test with [AppIntentsTesting](https://developer.apple.com/documentation/AppIntentsTesting), which exercises actual system intent dispatch, plus unit tests and Siri/Shortcuts smoke tests as supported.
2. **Model proposal proof:** an iOS-27 availability-gated `LanguageModelSession` using the Apple on-device model only; model proposes a typed intent and **cannot directly execute** its `Tool` side effects. Existing `PolicyEngine`, `ApprovalManager`, fingerprint/one-shot receipts and audit remain sole authority. Evaluate German requests and injection attempts from untrusted screenshots/web text.
3. **Controlled first write:** only **after** repository enforcement (#286) and content admission (#287), add one real user-approved reminder save with destination recheck, explicit user confirmation and `committed/notCommitted/unknown` evidence. No automatic retry after an unknown external write.
4. **Apple's own evaluation:** add [Evaluations tool-call scoring](https://developer.apple.com/documentation/evaluations/evaluating-tool-calling-behavior) and [AppIntentsTesting](https://developer.apple.com/documentation/AppIntentsTesting) as **additional** validation, preserving frozen iGentic benchmark cases and refusal metrics. A green simulator test is not physical device acceptance.

Apple's [iOS 27 App Intents update](https://developer.apple.com/ios/whats-new/) adds **App Schemas**, **View Annotations** and **AppIntentsTesting**. These are valuable public integration points for Siri AI, but **do not authorize arbitrary third-party-app UI control**.

### C. iOS 27 local model bake-off

**Run on an actual iPhone Air, not inferred from Mac performance.** The phone is listed in [Apple's Apple Intelligence eligibility guidance](https://support.apple.com/de-de/121115), but must report model availability and the required assets at runtime.

| Candidate | Implementation | Test evidence needed |
| --- | --- | --- |
| Apple on-device Foundation Models | First-party `SystemLanguageModel`, version/capability checked | 30+ synthetic German intents, typed JSON/tool correctness, refusal/error behavior, actual context budget, cold/warm times, privacy |
| Frozen `Qwen/Qwen3-0.6B` baseline | Exact revision and tokenizer; [Apple Core AI Qwen3 exporter](https://github.com/apple/coreai-models/blob/main/models/qwen3/README.md) for an **iOS 27** experiment | First compare `--dry-run`; check license, SHA and memory without new entitlement; then explicit on-device model export/load + repeated trials |
| Alternative small local model | One evidence-selected MLX/Core AI/GGUF candidate, not an unlimited model zoo | Add only if a meaningful failure occurs; compare latency, process memory/jetsam, battery/thermal, German tool calls and offline behavior |

Use [edge-llm-bench](https://github.com/john-rocky/edge-llm-bench) methodology and raw trial logs for cold/warm, throttling and memory, **not** its other devices' published speed as an iPhone Air result. A `LanguageModel` conformance is **not** evidence that its provider is local.

### D. Choose only one experimental cross-app track

**For iOS 27, re-rank [cell-use](https://github.com/Raynan00/cell-use) to P0 for phone-resident UI control.** Its upstream README explicitly states the phone-control runtime needs iOS 27, separate from the lower target of its Swift API/tunnel. Compare [Eiscue](https://github.com/LLLLLayer/Eiscue) (`frameId` one-action lease, no blind replay), [iCTRL](https://github.com/OpenMinis/iCTRL) (paired-key authenticated phone-local test runner) and [iphone-use-app](https://github.com/EliotAndres/iphone-use-app) (VPN/cellular limitations).

Use [iphone-cli](https://github.com/HyunSeob/iphone-cli) as a **Mac/Windows-hosted independent iOS 27 test backend** with a native accessibility tree, not as evidence of a standalone phone app. Its README reports tests on very few phone/OS configurations. Study `done/not_sent/unknown` action outcomes as a host reference.

Keep two product profiles: **A. public-API/possible App Store distribution**; **B. explicitly owner-consented developer-mode/sideloaded cross-app research**. Review license at a pinned SHA (cell-use Apache-2.0, iphone-cli MIT; Eiscue multi-license including GPL/custom; iphone-use-app AGPL). Do not run arbitrary UI drivers or transmit screenshots from the user's personal phone during initial comparisons.

**Mandatory synthetic failure cases:** wrong active app, stale/replayed screenshot, user denial, device locks, model asks for secret/external URL, foreground-to-background, force-quit, cellular-only VPN, no model endpoint, unknown outcome after a UI tap. A robust iGentic lab bridge must fail closed and never treat agent prompts as execution permissions.

### E. Execution and acceptance definition

The **next meaningful green result** is *one buildable iGentic app with a read-only App Intent callable from system pathways, whose proposed action passes through the unchanged Swift authorization chain, verified in Xcode 27.2 simulator*. Then collect explicit, privacy-preserving evidence on the iPhone Air. Do not promote unverified hardware claims, enable a real reminder save, or merge the Draft PRs around #286/#287.

**Reason to change priority:** Apple's Xcode MCP / Device Hub and iOS-27 App Intents/Models are now foundational first-party capabilities; host ARTEMIS and general external agent frameworks are **optional comparisons**. The true blocker is an end-to-end authorized product action, not a lack of more agent repositories.

### F. Observed Xcode 27.2 Mac / simulator acceptance — 2026-11-21

**New direct, independent environment evidence (not merely upstream source claims):** An authorized remote macOS host was actually connected for this run. Read-only environment discovery showed **macOS 27.0.1, Xcode 27.2 (27B52), Apple Swift 6.4.2, and an already-booted iOS 27.2 iPhone Air simulator**. This establishes the development host and *simulated* phone, not an owned physical iPhone Air's OS, signing status, or Apple model availability.

Tested **unchanged `main` commit `0bb24b750d90da9f810af9648aae5fc2058a7069`** in the Mac's clean `~/Developer/igentic-iphone` checkout:

| Check | How it was run | Observed result |
| --- | --- | --- |
| Swift Package unit tests | `cd ios && swift test --jobs 2 --scratch-path /tmp/igentic-test-xcode27-20261121` | **PASS 288/288**, 0 failures, exit 0 |
| Real Xcode iPhone Air simulator build | `xcodebuild -project app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj -scheme iGenticDiagnostics -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone Air,OS=27.2' -derivedDataPath /tmp/igentic-xcode27-air-20261121 CODE_SIGNING_ALLOWED=NO build` | **BUILD SUCCEEDED**, exit 0 |
| Synthetic app simulator installation/start | `xcrun simctl install booted <built-diagnostics.app>` then `xcrun simctl launch booted org.example.iGenticDiagnostics` | Installed and launched; process ID returned, exit 0 |
| Repository structure validator on an archive of the tracked tree | `git archive HEAD | tar -x -C <temporary-dir>` then `python3 scripts/validate_repo_structure.py` | **PASS** (`Repo structure looks good.`), exit 0 |
| Validator on original Mac working directory | `python3 scripts/validate_repo_structure.py` | **FAIL** on existing ignored `ios/.build` generated build artifacts despite a clean `git status`. This is a local validator behavior gap, **not** a tracked-file failure; no build cache was deleted |

The Xcode build printed `Metadata extraction skipped, no AppIntents.framework dependency found`. This confirms the diagnostics target currently lacks a real App Intents integration; it is **not** an App Intents success claim. No user accounts, reminders, real device settings, cloud models or personal screenshots were accessed in these tests. The simulator launch does not prove interactive navigation, correctness of screenshots/vision, full action approval, iOS background recovery or real phone execution.

**Next measured product step:** add one read-only, synthetic App Intent to iGentic through the existing Swift authority (after the required repository admission/security review); compile and test it through Xcode + AppIntentsTesting, then validate on the physical phone separately. **Owner branch protection #286/#287 remains unresolved**; no merge or live write is authorized by these test results.



### G. Live follow-up: App Intent implementation branch #380 (2026-11-21)

After the initial main-baseline test above, [Draft PR #380](https://github.com/pokekarten/igentic-iphone/pull/380) was opened, **separately from this research PR and ARTEMIS #378**. At its initial head `6e98d436529c9251d8d54384ea048306d1270dd7`, the actual source diff adds `AppIntents`, a fixed-string `iGenticReadOnlyDiagnosticsIntent`, and two `AppShortcutsProvider` phrases in `app/iGenticDiagnostics/iGenticDiagnostics/iGenticDiagnosticsApp.swift`. It performs **no personal-data read or device-health query**. This is a minimal public-API implementation step, **not** yet a policy-gated real reminder, cross-app automation, or physical device success.

The PR description reports `swift test` **288/288**, Xcode 27.2 build, generated `Metadata.appintents`/shortcut resources, and `simctl` installation/launch on an **iOS 27.2 iPhone Air simulator**. The GitHub check suite on that SHA also reports successful required build/validation jobs, subject to exact current head and check reruns. Distinguish the **author's PR/CI evidence** from *independent physical phone observation*. These do **not** yet prove Siri/Shortcuts invoked the intent through the system at runtime, nor that the returned value was checked.

A connected Mac working tree on `feat/read-only-diagnostics-app-intent-20261121` was independently inspected **without modifying it**: it had uncommitted Xcode test-target and scheme changes, and an `AppIntentsTesting` test file defining `IntentDefinitions(bundleIdentifier: "org.example.iGenticDiagnostics")`, resolving `iGenticReadOnlyDiagnosticsIntent`, and calling `makeIntent().run()`. As observed, that test **did not assert the returned string**; the test additions were not yet pushed to #380. Avoid concurrent edits or running conflicting builds in that worktree while another agent owns the change. Require the final PR to provide exact-head Xcode test outcome and a deterministic assertion of the expected fixed response (or a documented API limitation), not just a successful no-assertion invocation.

**Updated next-step order:** finish and verify #380's **system-dispatched, read-only App Intent** test with no raw data, user-approved deployment or side effects; review independently; separately keep #378 as Mac-host diagnostic adapter. Then demonstrate a typed draft/approval flow through the **existing** Swift authority, with a request-bound receipt, no external model credentials, and a verified result. The original main-baseline table above remains a historical measurement and should **not** be reinterpreted as reflecting PR #380 source.


### H. Follow-up on exact PR #380 test commit

Shortly after section G, **PR #380 head advanced** to `84ccc01300cc9f323c150771528a73a40f6f01d0`. The test target, Xcode project/scheme changes and `iGenticAppIntentsTests.swift` were **committed** in a second commit. The Swift source now obtains the out-of-process App Intents result, converts `try result.value.as(String.self)` and uses `XCTAssertEqual` against the exact fixed synthetic string. The previously noted **missing result assertion is resolved in code**. GitHub CI for this newer SHA was still running when checked; the actual `AppIntentsTesting` execution result, a Siri/Shortcuts user invocation and physical-device acceptance were **not** yet verified by this research update. Continue to keep implementation PR #380 separate from the host-based ARTEMIS #378 and research-only #379. [See #380](https://github.com/pokekarten/igentic-iphone/pull/380).
