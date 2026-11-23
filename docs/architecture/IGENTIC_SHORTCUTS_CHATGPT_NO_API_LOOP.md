# iGentic ↔ ChatGPT using Apple Shortcuts — no OpenAI API (iOS 27)

## What is actually supported

Apple Shortcuts on supported iPhones offers **Use Model → Extension Model →
ChatGPT**. Its output can be passed as the next Shortcut action's text input.
This uses Apple's ChatGPT integration, **not an OpenAI API key** and **not the
owner-private ChatGPT Sites plugin**. The person must enable Apple Intelligence
and ChatGPT integration (if available for this device, region, account and
language); a provider may show its own consent/usage controls. Normal Siri can
run a named Shortcut, but Siri's own conversational ChatGPT flow is distinct.

Official documentation:
- https://support.apple.com/en-mt/guide/shortcuts/tpg3vrvwmclv/10.0/ios/27
- https://support.apple.com/en-ie/guide/shortcuts/apd624386f42/10.0/ios/27
- https://help.openai.com/en/articles/10269382-setting-up-chatgpt-with-apple-intelligence

The iGentic app **never** calls an OpenAI API, scrapes the ChatGPT app, reads
account cookies or assumes the ChatGPT consumer app can return callbacks.
Shortcuts is the actual supported model-response bridge.

## Setup: one-time owner action on the real iPhone

Prerequisites: a **new signed iGentic build including this PR** is installed,
Apple Intelligence is available and enabled, and in Settings → Siri → ChatGPT
the owner enabled the extension. Then, in Shortcuts create a custom shortcut
named exactly:

**iGentic KI Loop**

Add these actions **in this order**:

1. **iGentic KI-Prompt lesen** — no input. Reads the current prepared request
   from the iGentic sandbox and returns a small JSON ticket with three fields:
   `schema` (1), `taskId` (local correlation UUID) and `prompt` (model input).
   No task text or UUID is included in the launcher URL.
2. **Wörterbuch aus Eingabe / Get Dictionary from Input** — parse the ticket.
   Save **prompt** and **taskId** in two separate Shortcuts variables. Never
   pass the whole JSON ticket to ChatGPT; the ID is only for local return matching.
3. **Modell verwenden / Use Model** — choose **Extension Model (ChatGPT)**.
   Set the model input to the saved **prompt** variable only. Disable interactive
   Follow Up for the first deterministic test. Select **Text** output where
   offered. First-run provider consent may still be required. **On-Device**
   can be used as a separate network-free fallback when available.
4. **iGentic KI-Antwort übernehmen** — supply both the **Model Response** as
   **Modellantwort** and the saved **taskId** as **Auftragskennung**. iGentic
   rejects a result intended for any older or different pending task. The
   model response remains untrusted text and is never executed as a command.
5. **App öffnen / Open App** — select **iGentic Diagnostics** and use
   **iGentic Agent → KI-Antwort prüfen** to review and delete the local text.

**Run from the iGentic app:** open iGentic Agent, type a task, tap
**KI-Auftrag lokal vorbereiten**, then **iGentic KI Loop in Kurzbefehle
starten**. iGentic launches only the **fixed shortcut name** through Apple's
documented shortcuts URL scheme. No user text, token, ID or private content
is embedded in that URL. The shortcut must already have been installed by the
owner; an unconfigured shortcut does not constitute a successful model call.

## Siri-first variant (without opening iGentic beforehand)

Create a second shortcut with a distinguishable name such as
**iGentic Frage**, consisting of:

1. **Eingabe abfragen / Ask for Input** (Text), or use dictated text.
2. **iGentic KI-Auftrag starten** — insert the entered text in **Frage**.
   It stores the pending exchange and returns the same JSON ticket format.
3. **Wörterbuch aus Eingabe** — store **prompt** and **taskId** separately.
4. **Modell verwenden → Extension Model (ChatGPT)**, using **prompt** only.
5. **iGentic KI-Antwort übernehmen** — send Model Response plus **taskId**.
6. **App öffnen → iGentic Diagnostics**; review result manually.

Say **"Siri, iGentic Frage"** to invoke the shortcut if iOS exposes the
chosen custom shortcut name. This is ordinary Siri → Shortcuts invocation,
not iGentic programmatically commanding Siri's dialogue system.

## Trust and lifecycle

- Owner must configure and run the Shortcut. The model provider is selected
  in Shortcuts, not by iGentic. An Apple Intelligence account/region setting
  may block ChatGPT; use the On-Device model when supported.
- One active local exchange at a time; entering a second task while an old one
  is stored fails until the owner deletes the first.
- One locally initiated task, up to 512 characters / 2 KiB; known IBAN/email/
  phone patterns are blocked from this automatic model-prompt route. This is
  a heuristic, **not a guarantee that all private content is detected**.
- One model answer, up to 8 KiB, must arrive within 30 minutes. Empty text,
  control characters, duplicate results, expired results and task-ID mismatches
  fail closed. The task UUID protects against stale cross-task callbacks, but
  is **not** a cryptographic provider authentication token.
- Stores one local JSON file with iOS file protection and restricted filesystem
  permissions. No server, analytics, background polling, chat history import
  or transparent sync. The user can clear task and response from the app.
- Model output is **untrusted text**, including model-suggested Shortcuts
  names or instructions. It is displayed for review only; neither this
  module nor the receive App Intent has any action execution API.
- The local pending exchange proves sequential state, **not cryptographic
  provenance of the provider**. Any owner-authorized Shortcut that knows
  these first-party actions can supply a reply while one task is pending.
  Write/other-app actions require separate native policies and owner approval.
- Protected file may be inaccessible while iPhone is locked. If Shortcuts
  cannot complete after lock or app suspension, rerun after unlocking; do not
  assert guaranteed background delivery.

## Acceptance plan and evidence boundaries

1. **Mac Swift package tests:** start → saved prompt → reply → app inbox;
   reject sensitive, invalid, stale and replayed text.
2. **Xcode simulator:** new iOS App Intents compile, App Home and inbox render.
   System AppIntentsTesting might be blocked by the observed Apple Customer
   build restriction (Code 803). Neither simulation nor a test fixture is
   physical ChatGPT provider evidence.
3. **Physical iPhone:** install a new owner-signed build; configure the
   Shortcut in Shortcuts, enable the ChatGPT extension and run a real question.
   Verify the exact text appears back in iGentic and no write occurred.
4. **Siri:** invoke the Siri-first named Shortcut on the real phone and repeat.
5. **Model fallback:** test On-Device separately, including offline operation.
   Note that On-Device and ChatGPT responses are independent providers.
6. Keep the existing owner-private Sites handoff plugin unchanged. The
   **ChatGPT → iPhone via direct plugin tool** remains a distinct future
   authenticated MCP project; this release implements the **iPhone/Siri →
   Shortcuts → ChatGPT → iGentic** loop only.

## Actual acceptance on physical iPhone — 2026-11-23

On the owner's paired physical iPhone Air, over CoreDevice **Wi-Fi**:

- Owner's existing local development signing profile matched the device and
  the exact installed iGentic app bundle. A new iOS 27 build was signed,
  installed in-place, and the app launched successfully (exit status 0).
- A gated **DEBUG-only** first-party device smoke ran with a fixed synthetic
  plant request and fixed synthetic response, directly inside the signed app.
  The app created its local pending exchange, accepted a local answer,
  independently read the same answer from its protected store, and cleared
  the fixture afterward.
- A strict fixed-schema, app-owned receipt was retrieved independently through
  Apple's CoreDevice app-container file-copy. It reported
  syntheticLocalRoundTripVerified, cleanedUp=true,
  chatGPTCalled=false, iOSActionExecuted=false and
  personalDataReturned=false. No unique device IDs or user task contents
  were exported.
- The simulator build passed App Intents metadata extraction after correcting
  Siri phrase interpolation. A separate simulator UI test passed for opening
  the native iGentic AI inbox. Earlier attempts to test in-screen start
  via XCUITest were not reliable because accessibility/scrolling queries
  failed; the hardware smoke above instead tests the real store layer.
- Local Swift package tests passed, including six tests for this exchange's
  replay, expiry, validation, protected storage lifecycle and untrusted-output
  behavior.

This is **not** evidence of a real Shortcuts Use Model provider call,
ChatGPT mobile-app invocation, Siri voice recognition, ChatGPT Site plugin
return connection, phone screen automation or external device write. A
user-configured iGentic KI Loop Shortcut with ChatGPT Extension Model
must still be created and independently tested on the phone.


## Native on-iPhone setup guide (added 2026-11-23)

The latest iGentic Agent screen links to **ChatGPT-Loop einrichten**, an
on-device setup guide. It uses Apple's documented
shortcuts://create-shortcut URL to open a **blank** Shortcuts editor, and
a fixed, single-query-item shortcuts://run-shortcut?name=... URL to start
the installed workflow. Neither URL contains the user's prompt, answer,
credentials or a callback. The app displays the four action names and
the state of its local pending exchange, and links to its review inbox.

The separate older experimental **iGentic ChatGPT Loop Test** is explicitly
labelled an optional developer workflow in the guide; it must not be confused
with the primary user-facing **iGentic KI Loop**.

**Honest readiness scope:** iGentic can read its own pending/answered/expired
task state but cannot discover or authenticate the user's private Shortcuts
library, confirm ChatGPT-extension enrollment, install a multi-app Shortcut
silently, or prove a model call from a Shortcuts launch URL. The person must
finish the actions in the Shortcuts editor and approve relevant prompts.

Official Apple guides:
- https://support.apple.com/de-de/guide/shortcuts/apda283236d7/ios
- https://support.apple.com/guide/shortcuts/use-apple-intelligence-in-shortcuts-tpg3vrvwmclv/ios

## Task-correlated callback hardening (2026-11-23 evening)

The current branch now returns a structured JSON ticket from both native
Shortcuts start/read actions. The callback requires that original ticket's
`taskId` in addition to the model answer. This blocks a delayed response
from an older Shortcut being stored under a newer task. It is still a local,
owner-configured, one-task-at-a-time workflow; UUID correlation does not prove
who wrote the answer or permit remote execution. The previously documented
physical smoke was conducted before this ticket change and does not verify
physical system-dispatch of the revised App Intents.
