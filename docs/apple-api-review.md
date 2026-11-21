# Apple API Review

Status: Phase 0 research artifact
Original Phase-0 review: 2026-06-12; platform reassessment: 2026-11-21

This document records what Apple APIs and platform concepts are relevant to iGentic iPhone before we add real App Intents, local model runtimes, or device-specific behavior.

## Decision summary

The project should treat the iPhone as the local trust and control plane. Apple APIs can support that direction, but they do not remove the need for our own policy, approval, data classification, and audit layers.

## Source labels

- `Apple-officially available`: documented by Apple.
- `Prototype candidate`: plausible for this repo, but not wired yet.
- `Speculative / later`: needs device tests or API maturity before use.

## API candidates

| Area | Status | Use in this repo | Phase |
| --- | --- | --- | --- |
| App Intents | Apple-officially available | Expose safe app actions after `ToolRegistry` and approval gates exist. | Phase 2+ |
| Shortcuts | Apple-officially available | User-controlled automation surface; should stay opt-in. | Phase 2+ |
| Foundation Models framework | Apple-officially available | Candidate for Apple-native local or PCC-backed language features. | Phase 3 |
| Core AI | Apple-officially available | Candidate runtime path for on-device AI models. | Phase 3 |
| Core ML | Apple-officially available | Candidate for traditional ML models and converted models, not first LLM path. | Phase 3 |
| Private Cloud Compute | Apple-officially available | Only a policy-gated delegation target, never default. | Phase 4+ |
| BackgroundTasks | Apple-officially available | Only for limited background maintenance; not a permanent agent loop. | Later |
| SwiftUI | Apple-officially available | Diagnostic UI shell after kernel safety is stable. | Phase 2 |

## Findings

### Apple Intelligence and App Intents

Apple describes Apple Intelligence as a personal intelligence system that includes personal context understanding, app actions, and on-screen awareness across Apple platforms. Apple also says app content and actions can be integrated into Siri AI and the system via App Intents.

Project implication:

- App Intents are the correct future action bridge.
- We should not expose actions directly before `PolicyEngine`, `ApprovalManager`, `AuditLog`, and `ToolRegistry` are stable.
- App Intents should initially be diagnostic and draft-first.

### Foundation Models framework

Apple describes the Foundation Models framework as a native Swift API for Apple Foundation Models on device and in Private Cloud Compute, plus model providers that conform to the Language Model protocol.

Project implication:

- Foundation Models may become the preferred Apple-native language layer.
- It should be integrated only behind `LocalModelRuntime` and `PolicyEngine`.
- It must not become a bypass around approval or data-classification rules.

### Core AI and Core ML

Apple describes Core AI as an on-device AI model path for Apple Silicon with zero server dependencies and zero token costs. Apple positions Core ML for fast integration of traditional ML models and points developers toward Core AI for LLMs and generative AI.

Project implication:

- Core AI is the strongest candidate for native on-device AI experiments.
- Core ML remains useful for smaller non-generative models or converted models.
- Runtime testing must happen on actual devices before making performance claims.

### Private Cloud Compute

Apple describes Private Cloud Compute as cloud AI processing designed for privacy, extending Apple device security into the cloud. It is still cloud delegation and should be treated as non-local.

Project implication:

- PCC is a delegation target, not a default runtime.
- Requests must be minimized, redacted where possible, and audit logged.
- Level 4 data should remain blocked from automatic delegation.

### Background behavior

BackgroundTasks should not be treated as permission to run a persistent autonomous agent. It can be evaluated later for maintenance tasks, but not for always-on reasoning.

Project implication:

- The diagnostic shell should focus on foreground, user-initiated flows first.
- Background work needs a separate device test plan.

## Non-goals for now

- No real App Intents yet.
- No Siri action execution yet.
- No external provider integration yet.
- No model weights in repo.
- No App Store or signing configuration.

## Phase-0 conclusion

Apple APIs support the project direction, but the safe order remains:

1. policy,
2. approval,
3. audit,
4. tool metadata,
5. memory boundaries,
6. diagnostic UI,
7. App Intents,
8. model runtime.


## November 2026 update: iOS 27 and the public/private API boundary

This section supersedes the **time-specific** conclusions from June 2026, not the enduring policy and privacy rules. All capabilities below are **Apple-officially documented**, not proven on iGentic's physical iPhone Air.

- [App Intents updates](https://developer.apple.com/documentation/updates/appintents): newer execution-target controls, system shortcut support and app-schema integration improve **declared actions**. The operating system still does not grant every third-party app unrestricted read/write access to other apps just because it exposes App Intents.
- [Foundation Models](https://developer.apple.com/documentation/updates/foundationmodels): on iOS 27, `LanguageModel` is a provider-neutral API for compatible on-device and cloud language models. Native sessions can use guided generation, supported tool-calling modes and availability checks. The interface does **not** confer execution authorization; tool handlers still pass through iGentic's deterministic policy and approval.
- [Evaluations framework](https://developer.apple.com/documentation/evaluations): Swift tool-call and output evaluation is newly available in Xcode 27. Evaluate against `igentic-action-benchmark-v0.jsonl` without changing frozen cases or treating results as physical device evidence.
- [Foundation Models framework utilities](https://github.com/apple/foundation-models-utilities) and [Core AI models](https://github.com/apple/coreai-models): Apple-hosted open-source packages provide context/skills/provider utilities and export recipes respectively. Core AI model recipes target **iOS 27+**; old iOS builds need conditional compilation or separate backends.
- [Apple's app distribution guidance](https://developer.apple.com/app-store/review/guidelines/) and [Developer Program agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/): **developer-mode/sideloaded cross-app testing** with XCTest/CoreDevice/DDI/loopback-VPN is a **separate lab capability** and not assumed to be permitted as an ordinary App Store feature. Do not enable it via a model prompt or bundle it into the production App Intents action surface.
- [Model availability](https://support.apple.com/de-de/121115) depends on eligible hardware, OS, locale and actual system state. The iPhone Air is listed as Apple Intelligence compatible, but this is not proof the model is available or fast on the tested device.

**Current recommendation:** build a typed safe App Intents/action path first; treat any unrestricted phone-control transport as optional, separately approved research; use the native OS-27 model API before adding a second session framework; maintain an explicitly tested older-OS fallback. The [technical reassessment](research/TECHNICAL_REASSESSMENT_2026_11_21.md) documents alternatives and stop conditions.
