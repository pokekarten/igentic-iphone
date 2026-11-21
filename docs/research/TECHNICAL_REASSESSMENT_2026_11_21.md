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
