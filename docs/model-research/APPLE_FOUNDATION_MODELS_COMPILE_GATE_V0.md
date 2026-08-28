# Apple Foundation Models Compile Gate V0

Status: software compile and availability-contract evidence only  
Sources reviewed: 2026-08-28  
Parent: #316 and #74

## Purpose

This contract defines the first executable iGentic boundary for Apple's on-device Foundation Models system backend without performing inference.

The gate answers only:

> Can the current `AgentCore` represent Apple's documented system-model availability safely, remain compatible with the repository's older deployment targets, and compile the real `FoundationModels` branch with a current Xcode 26 toolchain?

It does **not** answer model quality, runtime readiness, physical-device performance or whether Apple Intelligence is available for a particular person or device.

## Apple source contract

The current Apple Foundation Models documentation states that:

- `SystemLanguageModel.default` provides the base on-device system language model;
- callers must inspect `SystemLanguageModel.availability` before making requests;
- the availability state is either `available` or `unavailable(reason)`;
- documented unavailable reasons are `deviceNotEligible`, `appleIntelligenceNotEnabled` and `modelNotReady`;
- the system model can support text generation, structured/guided generation, summarization and classification/judgment tasks;
- Apple periodically updates the on-device model with OS updates, so an iGentic system-backend record must not invent an immutable Apple model revision.

Primary Apple sources:

- https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
- https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason
- https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models
- https://developer.apple.com/documentation/Updates/FoundationModels

## iGentic runtime boundary

`AppleFoundationModelsRuntime` conforms only to the existing `LocalModelRuntime` metadata and availability interface.

Its descriptor is intentionally conservative:

```text
identifier: apple-foundation-models-system
modelFamily: apple-system-language-model
executionKind: system
capabilities: textGeneration, structuredProposal, summarization, classification
maximumDataSensitivity: contextualPrivateData
contextBudgetClass: standard
memoryBudgetClass: moderate
```

The context and memory classes are routing/planning metadata, not measured Apple model limits or physical-device resource observations. `standard` is sufficient for the current 512/1,024-token Benchmark V0 planning profiles. `moderate` is a conservative existing enum value; it is not a memory measurement.

The data ceiling deliberately stops below `highlyPrivateData`. On-device execution alone does not waive iGentic policy, approval or data-handling rules.

## Availability mapping

The adapter normalizes only availability metadata:

| Apple/runtime observation | iGentic availability |
| --- | --- |
| `available` | `available` |
| `deviceNotEligible` | `unavailable(.deviceNotEligible)` |
| `appleIntelligenceNotEnabled` | `unavailable(.appleIntelligenceNotEnabled)` |
| `modelNotReady` | `unavailable(.modelNotReady)` |
| Foundation Models module or required OS API unavailable | `unavailable(.unsupportedPlatform)` |
| future/unknown Apple availability state | `unavailable(.unknownSystemCondition)` |

Unknown future states fail closed rather than being promoted to availability.

## Compatibility and compile evidence

The Swift package keeps its existing minimum platforms:

```text
iOS 17
macOS 14
```

Production source therefore uses conditional module import plus OS availability checks. That compatibility path alone is **not** accepted as proof that the Foundation Models branch compiles, because an older SDK can make `canImport(FoundationModels)` false.

Phase 0 preserves the normal package build/test on its existing default macOS toolchain and Linux. It also performs an additional `AgentCore`-only build with:

```text
DEVELOPER_DIR=/Applications/Xcode_26.3.app/Contents/Developer
swift build --target AgentCore
```

The current `macos-15` GitHub-hosted image exposes Xcode 26.3 at that path while keeping Xcode 16.4 as its default. This gives two distinct proofs:

1. existing package compatibility still compiles/tests on the normal repository toolchain; and
2. the actual `FoundationModels` code path type-checks and compiles under Xcode 26.

If the Xcode 26 installation or Foundation Models module disappears or becomes incompatible, the compile gate fails rather than silently accepting the fallback branch.

## What is not executed

This V0 gate does not create or call:

- `LanguageModelSession`;
- prompts or instructions;
- guided-generation responses;
- model tools;
- Private Cloud Compute;
- network requests;
- a Benchmark V0 model run.

No raw prompt, user content or model output is produced.

## Evidence classification

A green gate may establish only:

```text
APPLE_FOUNDATION_MODELS_API_SOURCE: verified
FOUNDATION_MODELS_XCODE26_COMPILE: pass
LOCAL_MODEL_RUNTIME_AVAILABILITY_MAPPING: tested
SYSTEM_MODEL_INFERENCE: not_run
IPHONE_AIR_PHYSICAL_DEVICE: not_run
QUALITY_BASELINE: not_run
```

A simulator, CI runner, Mac or compile result must never be relabeled as physical iPhone Air evidence.

## Follow-up boundary

A later Apple untouched-baseline execution must be separately authorized. It must record at minimum:

- exact iGentic repository revision;
- OS and SDK/framework version;
- observable Apple system-model version/variant provenance available through the API at that time;
- locale/language support and context limit used;
- Benchmark V0 profile and evaluator artifact identity;
- execution evidence class;
- explicit statement that policy, approval, schema validation and execution remain deterministic Swift authority.

Because Apple updates the system model with OS releases, do not invent an immutable Hugging-Face-style model revision for this backend.

## Stop rules

Stop before inference, tool calling, PCC/network use, signing/entitlement changes, deployment-target changes, private data, or physical-device claims. If Xcode 26 cannot compile the real Foundation Models branch, record that as an SDK compile blocker rather than weakening the gate with a fallback-only test.
