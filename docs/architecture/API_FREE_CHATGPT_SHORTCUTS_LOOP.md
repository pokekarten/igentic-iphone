# iGentic: API-free ChatGPT / Siri / Shortcuts loop (prototype contract)

Status: proposed on-device acceptance; Swift validation adapter included in PR #409.
No OpenAI API credential, no API billing path, no cookie/session extraction.
Do not interpret this document as evidence of a running physical-iPhone loop.

## Guiding rule

iGentic owns safety and task progress. Siri is an optional human voice entry.
Shortcuts is the user-configured orchestration surface for ChatGPT model calls.
The private ChatGPT Site/MCP plugin is a separate *inbound* path and is not
automatically available inside Apple's ChatGPT Shortcuts action.

Two independent ChatGPT entry points:
A. Apple Shortcuts "Use Model" with ChatGPT extension, when available on-device.
B. An explicitly exposed action from the installed ChatGPT app, if offered by
the installed app and verified on the target iOS build.

Never assume that the ChatGPT App, Apple's Siri extension and this conversation
share a context, a plugin inventory or live execution privileges.

## What is now implemented on the PR branch

- Read iGentic iPhone Status: locally read coarse battery and OS state.
- Prepare iGentic Agent Task: local, no-execution task preview.
- Create iGentic Loop Token: generates a fresh anonymous correlation UUID
  locally; not a login/session credential and not persisted.
- Review iGentic Model Reply: accepts correlation UUID and untrusted JSON model
  output; only three exact action proposals are allowed (status.read,
  reminder.draft and finish).
- Review returns strictly serialized JSON with schema=1, taskId, decision,
  nextAction, reason, approved=false, executed=false.
- No reply can turn into an app action without a *separate* Shortcuts action
  and the relevant iGentic policy/permission checks.
- The correlation UUID is not authentication and is not currently persisted.
  This prototype has no durable task queue, verified delivery or replay lock.

## First physical-iPhone manual acceptance (one model turn)

Preflight: owner's signed PR build installed; iGentic actions discoverable in
Shortcuts; Apple Intelligence ChatGPT extension and any required consent enabled.
Availability is determined on device, not inferred from iOS version or account.

1. Create a Shortcuts workflow named "iGentic ChatGPT Loop Test".
2. Run the iGentic action "Create iGentic Loop Token" and store its result
   in a Shortcuts variable. This is correlation only, not authorization.
3. Use Model (select ChatGPT extension). Request *only* a single JSON object:
      {"action":"status.read"}
   Ensure follow-up/interactivity settings do not create an unexpected pause.
4. Pass the unchanged model output and UUID to the iGentic action
   "Review iGentic Model Reply".
5. Parse the returned JSON as a dictionary. Continue only if decision is
   exactly "previewOnly" and nextAction is exactly "status.read".
6. Run the separate native "Read iGentic iPhone Status" action and show its
   actual result. Never equate status.read *proposal* to status execution.
7. Assert the review receipt has approved=false and executed=false. A real
   status action has its own output; nothing here writes to Reminders.

## Second model turn / finite loop

8. Ask ChatGPT via a second Use Model action to classify the previous status
   result as a finished task, again returning *only* {"action":"finish"}.
9. Pass that output and the same UUID to Review iGentic Model Reply.
10. Stop only if decision is "stopped"; otherwise show an error and stop.
11. The first prototype performs exactly two turns. Do NOT run an unbounded
    Repeat loop. No automation should silently retry a possibly executed write.

## Siri and iGentic-originated entry

- Siri -> predefined iGentic Shortcut -> Use Model -> iGentic review -> separate
  explicit iGentic action -> Siri/show result.
- iGentic -> explicit tap on "iGentic ChatGPT Loop in Kurzbefehle starten"
  in Agent Home -> fixed shortcuts://run-shortcut?name=... link -> Use Model ->
  own Review Intent. The URL carries ONLY the fixed Shortcut name; no private
  task text or token. User must first create the named Shortcut on this phone.
  Foreground transitions and callbacks require actual iPhone testing; no
  arbitrary programmatic Siri wake.
- User-selected iOS Share Sheet -> ChatGPT app is manual export only and carries
  no guaranteed return callback.
- x-callback-url is a *separate optional* route. An x-success result may
  return textual Shortcuts output, but must be size-bounded and treated as
  untrusted; no URL receipt proves an iPhone action was performed.

## ChatGPT Site/MCP direction (separate transport)

Current private iGentic Übergabetest Site exposes manual links for diagnostics,
discovery and reminder-draft. Tool calls have returned actionExecuted=false,
iPhoneConnected=not-checked and requiresOwnerTap=true. Do not convert those
links or callbacks into "device executed" receipts.

Later, extend the SAME owner-authorized Site with a real task create/status/
cancel endpoint only if a confirmed authenticated iPhone transport exists.
Before adding private data or action execution, prove access control, device
enrollment, replay protection, expiring request IDs, owner-local approvals,
and independent execution evidence. If Sites cannot provide secure iPhone
ingress/egress, use a minimal separate broker carrying *no model calls*.
OpenAI API is neither necessary nor part of this architecture.

## Fail-closed security checks

- Model response over 1024 bytes, invalid JSON, extra keys, fake approval,
  unsupported tool name, invalid UUID -> reject without echoing user text.
- Only exact allowlisted, non-executing action proposals; raw model text is
  never executed as commands, Shortcut names, URLs or arbitrary shell.
- iOS permission is not per-action owner approval. A reminder requires its
  separately reviewed EventKit and one-shot approval capability.
- Private response text may leave the device only after user-reviewed
  disclosure. Do not include it in logs, GitHub, plugin results or URL queries.
- UI/Shortcuts may be suspended or interrupted. No always-on background claim.
- A disconnected/locked phone must yield unavailable/pending, not success.

## Required independent proof before claiming an end-to-end loop

- Exact GitHub head and Swift/Xcode test results recorded.
- Actual Shortcuts model output and iGentic review output on signed physical
  iPhone, with sensitive content redacted.
- Siri initiation separately verified (not implied by App Intents compilation).
- App callback or x-callback tested separately if chosen.
- ChatGPT MCP->iPhone->MCP verified with a genuinely observed, nonce-bound
  result. This is not established by the current manual-link Site.
- All user data and auth secrets stay out of the public repo.

## Official references

- Apple Shortcuts Use Model:
  https://support.apple.com/guide/shortcuts/use-apple-intelligence-in-shortcuts-tpg3vrvwmclv/ios
- Apple x-callback:
  https://support.apple.com/en-ie/guide/shortcuts/apdcd7f20a6f/ios
- Apple App Intents:
  https://developer.apple.com/documentation/appintents
- OpenAI Apple Intelligence integration:
  https://help.openai.com/en/articles/10269382-setting-up-chatgpt-with-apple-intelligence
- OpenAI custom MCP in ChatGPT:
  https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt
