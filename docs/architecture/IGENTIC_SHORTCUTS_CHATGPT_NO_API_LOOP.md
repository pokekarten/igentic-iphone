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

1. **iGentic KI-Auftrags-ID lesen** — save the output in a Shortcuts variable
   named **Auftrags-ID**. This is a local correlation UUID, **not** a credential;
   keep it in Shortcuts and do not include it in the AI prompt.
2. **iGentic KI-Prompt lesen** — no input. Reads the current prepared request
   only from the iGentic sandbox and returns the complete plain-text prompt.
   The task and correlation ID do not appear in the launcher URL.
3. **Modell verwenden / Use Model** — choose **Extension Model (ChatGPT)**.
   Set the prompt input to the previous **KI-Prompt** result.
   Disable interactive Follow Up for this deterministic test. Set the
   output to **Text** where offered. The model action is the only external
   step; Shortcuts/Apple may show a first-time provider consent prompt.
   Alternatively select **On-Device** where available.
4. **iGentic KI-Antwort übernehmen** — feed the **Model Response** from step
   3 into **Modellantwort**, and the saved **Auftrags-ID** from step 1 into
   the separate **Auftrags-ID** parameter. If the ID is missing, belongs to
   a canceled/older task, is malformed, or the task expired, the app refuses
   the result. The response remains untrusted review-only text.
5. **App öffnen / Open App** — select **iGentic Diagnostics**. In the app,
   choose **iGentic Agent → KI-Antwort prüfen** to read or delete it.

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
2. **iGentic KI-Auftrag starten** — insert the entered text in **Frage**;
   the action stores the pending exchange and returns a structured JSON
   ticket with fields taskId and prompt. For the beginner workflow, ignore
   this JSON output; use steps 3 and 4 to retrieve the fields separately.
3. **iGentic KI-Auftrags-ID lesen** — save the correlation UUID to a Shortcuts
   variable named **Auftrags-ID**.
4. **iGentic KI-Prompt lesen** — save the plain prompt in a Shortcuts
   variable for the model step (do not feed the JSON ticket or UUID to ChatGPT).
5. **Modell verwenden → Extension Model (ChatGPT)**, with the **KI-Prompt**
   from step 4 as input.
6. **iGentic KI-Antwort übernehmen**, with both **Model Response** and the
   saved **Auftrags-ID** from step 3 as separate parameters.
7. **App öffnen → iGentic Diagnostics**; review result manually.

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
  control characters, duplicate results, stale or mismatched correlation UUIDs,
  and expired results fail closed. Shortcuts must pass the UUID as a separate
  variable; the UUID is not authentication and is never sent to the model.
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
credentials or a callback. The app displays the five required steps and
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


## Stale-answer defense (2026-11-23)

The first implementation accepted any answer while a pending exchange existed.
This could assign a delayed response from a canceled Shortcut to a newer task.
Now the read-only iGentic KI-Auftrags-ID lesen App Intent provides the actual
pending exchange UUID. iGentic KI-Antwort übernehmen requires that same UUID
in a separate Shortcuts parameter, and compares it against the protected local
record before storing any text. Tests cover canceled-then-restarted tasks,
malformed UUIDs, expiration and replay. This is correlation and replay
prevention, **not** a cryptographic proof that ChatGPT created the response.

Any previously configured Shortcut using the old three-step return sequence
must be updated to supply the new separate ID parameter.


## Advanced optional structured ticket

For advanced Shortcuts users the separate **iGentic KI-Auftragspaket lesen**
App Intent provides a JSON dictionary containing exactly schema=1, taskId
and prompt. **iGentic KI-Auftrag starten** also returns this JSON ticket.
Use Apple Shortcuts' dictionary parsing to pass only the prompt text into
Use Model, and retain taskId locally for the receive intent. Never send the
whole JSON package to the model: the ID is correlation rather than a cloud
credential, but sending it serves no purpose. The normal guided five-step
workflow continues to offer simpler separate Prompt and ID actions.


## Auto-registered native shortcuts vs owner-installed workflow (2026-11-23)

The native `iGenticDiagnosticsShortcuts: AppShortcutsProvider` now **features four**
first-party shortcuts: fixed diagnostics, local device status, agent task
preview, and local AI task preparation. iOS registers those with the installed
signed app, exposing them via Siri, Spotlight and Shortcuts; they do not depend
on creating a personal shortcut or an OpenAI API subscription.

The underlying task ID, prompt, ticket, reply-receive, loop-token, and
model-reply-review `AppIntent` types remain available as *individual actions*
when the owner edits a Shortcut. They are deliberately **not** all featured
as standalone App Shortcuts. Apple recommends focusing on a few common tasks.

The in-app guide provides a first-party `ShortcutsLink` that opens iGentic's
App Shortcuts page. This is discovery, not proof of a successful invocation.

The **multi-app** workflow `iGentic KI Loop` still needs one explicit owner
setup in the Shortcuts editor, including selecting the ChatGPT extension model
(or a suitable on-device model) and confirming permissions. The
`shortcuts://create-shortcut` link creates only a *blank* editor, and
`shortcuts://run-shortcut?name=...` can launch only a previously installed
owner shortcut. Neither link can install, configure or attest a model step.
No credentials, task text or private data are embedded in either link.

Offline verification: Swift package tests, Xcode simulator build and
App Intents metadata extraction. Physical iPhone Siri/Shortcuts discovery,
provider selection, model call and return remain separate acceptance gates.

Apple:
- https://developer.apple.com/documentation/appintents/app-shortcuts
- https://developer.apple.com/documentation/appintents/shortcutslink
- https://developer.apple.com/documentation/appintents/acceleratingappinteractionswithappintents


## Project-specific ChatGPT launch via native Shortcuts (2026-11-23)

The installed ChatGPT iOS app also exposes a **Start chat in project**
Shortcuts action. This is a **third, independent entry route**: it can start
an interactive ChatGPT conversation in a project selected by the owner in
the Shortcuts editor, preserving that project's instructions and context.
It is not Apple's **Use Model → ChatGPT Extension Model** action, and it is
not the owner-private MCP/Sites plugin. Do not conflate these interfaces.

Owner setup (requires ChatGPT app, account and accessible project):

1. Create or choose the intended project inside ChatGPT; configure project
   instructions and sources there, with sensitive content handled privately.
2. In Apple Shortcuts, create a shortcut and search under ChatGPT for
   **Start chat in project** (the visible label may be localized).
3. Select the **iGentic** ChatGPT project in the native action. Name the
   owner-configured shortcut **iGentic Projekt-Chat** (the fixed name linked
   by the iGentic setup screen); optionally add it to the Home Screen or
   invoke it by name through Siri.
4. Run it, then confirm in the ChatGPT UI that the new chat belongs to the
   **iGentic** project, not a general ChatGPT conversation.

This is a dedicated iGentic launcher, not a multi-project router. Its
configured ChatGPT project is selected by the owner, not by the iGentic app.
Do not infer a general dynamic project-routing API or project CRUD API from
this action; each action must use the destination actually exposed by the
installed ChatGPT app. Never fabricate a project ID or a chat URL.

**Boundary:** This action opens an interactive project chat; it does **not**
prove that Shortcuts can inject an arbitrary first message, automatically
receive the model response, change project instructions/files, or remotely
execute an iPhone action. The current iGentic Shortcuts response loop still
uses the separate **Use Model** route and correlation-checked receive Intent.
For project chat → iGentic return, only a reviewed share/export or a separately
verified native callback/transport may be used. Do not pretend the existing
private Site/MCP handoff provides that callback.

Independent physical-iPhone acceptance when available:
- verify action presence and project list under the installed ChatGPT version;
- verify launch into the exact chosen project, not a generic/new default chat;
- verify correct project-context behavior without exporting private project
  data into logs or the public repository;
- verify user-facing Siri and Home Screen launch separately;
- verify absence of automatic iGentic receipt or device execution, and fail
  closed if a project is missing or account/workspace differs.

Public references and evidence (not physical acceptance):
- https://chaocode.co/en/articles/ (Aug 19, 2026: practical setup of
  ChatGPT's **Start chat in project** Shortcuts action)
- https://appleintelligence.substack.com/p/shortcuts-is-s-tier-the-definitive
  (Oct 19, 2026: project-specific action discovery)
- https://help.openai.com/en/articles/10169521-projects-in-chatgpt
  (project contexts, instructions and sources)


## Project-chat one-time setup refinement (2026-11-23, offline)

iGentic Agent Home now offers a separate **Neuen iGentic-Projektchat starten**
launcher, in addition to the non-project `iGentic KI Loop` model-reply
pipeline. The guided in-app setup has its own create-shortcut link and three
steps: pick the ChatGPT app's `Start chat in project` action, choose the actual
project inside the Shortcuts editor, optionally append `Voice Mode`, then
name the shortcut exactly `iGentic Projekt-Chat`. Siri can run the *owner-created*
named shortcut. No automatic library modification, iPhone access, account token,
unverified ChatGPT URL scheme, or project ID is involved.

This distinction is essential: `Start chat in project` starts a **new**
conversation under the selected project's instructions, files and applicable
project memory. It does **not** resume the very same transcript. For an exact
ongoing thread, open that existing ChatGPT project chat directly. An existing
chat outside the intended project does not automatically become project context;
move any relevant chat into the project in ChatGPT when that option is available,
or add approved project instructions/files. Project-only memory excludes
non-project chat context. Project context relevance is not proof that the full
contents of all earlier chats were inserted into the active model window.

The project-launch Shortcut intentionally does not include iGentic's typed
prompt in its launch URL or automatically pass any user text to ChatGPT. The
app cannot verify which ChatGPT project the owner selected, that the chat opened,
that voice mode started, or that the AI ran. The separate local model-reply path
remains available where an iGentic-owned response is needed.

On-device acceptance after the iPhone becomes available: (1) choose the right
ChatGPT project in the real Shortcuts editor; (2) run the named Shortcut from
iGentic; (3) confirm the project header in the ChatGPT app and no unintended
new default chat; (4) optionally confirm Voice Mode; (5) confirm no task text
was transferred by the URL and no fake execution receipt was generated.

References:
- https://help.openai.com/en/articles/10169521-projects-in-chatgpt
- https://community.openai.com/t/feature-request-end-chatgpt-voice-mode-without-touching-screen/1401642
- https://developer.apple.com/documentation/appintents/app-shortcuts

## Shortcuts exchange cross-process consistency (2026-11-23)

The local `AgentLoopShortcutExchangeStore` is shared between the iGentic
SwiftUI owner screen and independent iOS App Intents/Shortcuts invocations.
An in-memory `@MainActor` alone does **not** serialize two different app
processes. Begin, receive, and owner-clear now use a single advisory
nonblocking `flock` around each read-check-write transaction, backed by a
persistent 0600 `shortcut-ai-exchange-v1.json.lock` file in the app's
Application Support directory. The lock file is deliberately **not deleted**
after use; deleting/recreating a locked inode would make two locks that do
not coordinate. An OS process crash releases the lock automatically.

If another process owns the lock, the operation returns `exchangeBusy`
and does not read a stale snapshot and overwrite another task. The main-actor
in-process guard also rejects synchronous callbacks that try to re-enter a
mutation while already holding the lock. On-disk writes remain atomic; task
IDs and expiration still gate replies; only the user can clear a stored task.
A beginTicket response is generated from the exact record just created, not
by reloading a potentially replaced record. A pendingTicket likewise
generates its prompt and task ID from the **same** validated snapshot.

This is app-local transaction safety, not cryptographic authorization, a
remote transport, physical-device attestation, or proof that Shortcuts is
installed. The lock file has no task content or device identifiers. Offline
tests cover both same-process reentrancy and a second OS-level lock handle.
Keychain enrollment, independently verified device receipts, and signed
iPhone acceptance are separate pending gates.

### Bundled Siri shortcut for a ChatGPT follow-up

The app now features **ChatGPT-Beispielaufgabe**. Its Siri phrase is
“Starte eine ChatGPT Beispielaufgabe mit” followed by the application name.
The App Intent opens chatgpt.com with a fixed German example asking for a
follow-up about an empty test list. It supplies no personal input or device
status. The model response appears in ChatGPT. This action requires no
personal Shortcut import. Voice recognition, account selection and return
of the resulting answer to iGentic require separate device verification.

Physical test: the signed build installed and launched over Wi-Fi. Invoking
this featured action via the personal run-shortcut URL by display name opened
Shortcuts, which reported that the shortcut could not be found. Use the native
App Shortcuts picker for the featured action. Siri invocation remains unverified.

### Bundled local Status Loop

The `iGentic Status-Loop` App Shortcut ships with the iOS app. It uses
the existing local journal and policy, supplies the fixed status-read
proposal and finishes after one observation. A pending or uncertain task
prevents a new start. For Siri, the configured phrase is „Starte den
Status-Loop mit“ followed by the app name. Physical availability and
Siri recognition require verification after installing the build.

The Mac Shortcuts CLI can list, view, run and sign exports. The current
iGentic Diagnostics target supports iPhoneOS and iOS Simulator. The Mac
library check found no personal iGentic shortcuts. No export, import or
cross-device sync has been verified for the project and AI shortcuts.
