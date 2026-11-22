# Opt-in on-device Foundation Models acceptance probe

This executable is **not a normal app entry point** and is never invoked by
the iGentic App Intent. It uses the Apple Foundation Models adapter introduced
by PR #382, and is stacked on that PR until reviewed.

## Execute on a compatible local Mac

```bash
cd ios
swift run AppleOnDeviceProposalProbe
# LOCAL_MODEL_PROBE=skipped (explicit opt-in required)

IGENTIC_RUN_LOCAL_MODEL_PROBE=1 swift run AppleOnDeviceProposalProbe
```

The second command generates **one** model response from a fixed synthetic
prompt about watering a demo plant and checks that model-produced candidate
with `UntrustedActionProposalGate`. It intentionally prints **only** one
outcome and, on successful review, the gate disposition and reason code:

```text
LOCAL_MODEL_PROBE=reviewed
LOCAL_MODEL_DISPOSITION=approvalRequired
LOCAL_MODEL_REASON=policyRequiresApproval
```

This example shows one observed result, **not** a guaranteed generative
output. Other valid outcomes include `modelUnavailable`,
`generationFailed`, `inputRejected`, `blocked`, or
`previewOnly`. The executable has **no tool-registration callback** or
write path and cannot create a reminder or self-grant approval.

## Safety and scope

- Synthetic, hardcoded public prompt only. No command-line user prompt,
  contacts, notes, screen data or personal documents are accessed.
- No model-generated text or error description is printed, persisted or
  transmitted by this executable. It invokes a new, ephemeral
  `LanguageModelSession` with no tools.
- The adapter requires Apple's local `SystemLanguageModel` and returns
  `modelUnavailable` when unavailable. No cloud fallback.
- Users must explicitly set `IGENTIC_RUN_LOCAL_MODEL_PROBE=1` to incur
  a real local model inference. Ordinary builds/tests do **not** run it.
- This proves only local system-model availability, structured-generation
  invocation and gate review **on the machine where run**. It does not
  establish physical iPhone hardware behavior, Siri or Shortcuts routing.

The MacBook Neo with macOS 27.0.1/Xcode 27.2 reported
`SystemLanguageModel.default.availability = .available` on
2026-11-21. A live, synthetic probe returned `approvalRequired`
with `policyRequiresApproval` (no reminder was created). Device acceptance
on the owner's physical iPhone remains separate.


## iOS 27 locale eligibility check (2026-11-22)

The on-device system model's presence is **not** proof of its availability
for the user's preferred language. `AppleFoundationModelsRuntime` now checks
`SystemLanguageModel.default.supportsLocale` against the first preferred
language after the model reports available. An unsupported locale fails closed
with `unsupportedLocale`, rather than sending the request to a cloud endpoint
or silently choosing a different model. Existing authorization and data
classification boundaries are unchanged. A separately configured, user-approved
local open-weight model may be evaluated later; there is **no automatic
delegation**.

Apple documentation:
https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/supportslocale(_:)
https://developer.apple.com/documentation/updates/foundationmodels

This mapping has a deterministic Swift unit test, but **has not been measured
on the physical iPhone on iOS 27**. A signed physical-device trial must record
preferred locale, OS version, model availability, `supportsLocale` result and
a synthetic German-language structured preview. Do not publish private device
identifiers, prompts or raw generated text.
