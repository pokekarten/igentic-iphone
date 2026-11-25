# Apple API Review

Status: Phase 0 research artifact
Last updated: 2026-06-12

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
