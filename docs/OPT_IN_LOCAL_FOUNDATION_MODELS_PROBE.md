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

## Opt-in typed reminder-draft probe

The reminder screen also uses `ReminderDraftProposalService`. This separate
probe exercises its structured action/title/Gregorian-date output through the
same local system model. It supplies one of three fixed synthetic German
fixtures; it accepts no arbitrary prompt. The supported fixture checks only
whether the expected object/action terms and tomorrow-at-18:00 Europe/Berlin
date matched. The other fixtures check abstention for an ambiguous reminder
time and an unsupported wallpaper request.

```bash
IGENTIC_RUN_LOCAL_REMINDER_DRAFT_PROBE=1 \
  swift run AppleOnDeviceProposalProbe

IGENTIC_RUN_LOCAL_REMINDER_DRAFT_PROBE=1 \
IGENTIC_LOCAL_REMINDER_PROBE_CASE=ambiguous \
  swift run AppleOnDeviceProposalProbe

IGENTIC_RUN_LOCAL_REMINDER_DRAFT_PROBE=1 \
IGENTIC_LOCAL_REMINDER_PROBE_CASE=unsupported \
  swift run AppleOnDeviceProposalProbe
```

The output contains only result codes and boolean fixture-match fields; no
generated title/date, prompt or error is printed. All cases remain preview
only, and the executable has no EventKit writer. A successful fixture match
is one observation, not a quality rate or guarantee. This route is distinct
from the public-data-only action preview: the fixed synthetic reminder is
classified as contextual private input to test the production privacy floor,
but no user records or shared content are read.
