# Apple on-device structured action proposals — experimental adapter

This is a **stacked development branch** on top of
`feat/untrusted-model-action-proposal-gate-20261121` (PR #381).
The code is not part of `main` or of PR #380's system App Intent.

`AppleOnDeviceProposalPreview` is a narrow prototype of a **local, preview-only**
`FoundationModels.LanguageModelSession` adapter. It asks Apple's system model
to generate a Swift `@Generable` candidate with `actionName` and
`proposedText`, then sends the result into
`UntrustedActionProposalGate`. The result exposes **only** a disposition and
reason code; it does not return the prompt or generated text and has no tool
or save callbacks.

## Guardrails

- The caller MUST explicitly provide a trusted, independently determined `DataClassification` to `generateReview(for:trustedDataClassification:)`; no `publicDefault` fallback exists. The method fails at **compile time** when classification is omitted. A model-generated classification is not independent evidence.
- Only independently classified **public** prompts of at most **256 UTF-8
  bytes** reach the model; empty and recognized sensitive-pattern prompts
  are rejected before session construction.
- The system model must report local `structuredProposal` capability
  availability. No cloud model fallback or network client is provided.
- The session is fresh per request and has **no model tools**.
- The model does not authorize anything: a separate pure gate accepts only
  `diagnostics.read` as a preview (with empty payload) or
  `reminder.create` as a proposal requiring owner approval.
- Model unavailability and generation errors are reported only as generic
  states. Their descriptions, possibly containing prompt fragments, are not
  logged or returned.
- No app-level UI, App Intent, reminder storage or cross-app access has been
  added. This does not prove the model is available on a specific iPhone.

## Tests and evidence

`ios/Tests/AgentCoreTests/AppleOnDeviceProposalPreviewTests.swift` tests
preflight rejection and no-model outcomes with empty, too-long, recognized
sensitive and trusted private data. These tests do not contact the model.
Verify with `cd ios && swift test`. A separately signed physical-device
benchmark and live-generation acceptance remain required.

Official Apple references:
- <https://developer.apple.com/documentation/foundationmodels/languagemodelsession>
- <https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation>
