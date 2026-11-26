# Standalone iGentic — native device tool slice

2026-11-26. iGentic itself is the local control plane. Siri, Shortcuts,
ChatGPT, MCP, a Mac and other providers are optional interfaces, not
requirements for the foreground local UI or for native device tools.
An iOS app cannot grant itself access to another app's sandbox, arbitrary
system settings, or unrestricted system-wide UI automation.

## Implemented in this slice

- Agent Home provides a direct local device-control screen, before the
  external AI sections. Read-only status, estimated available storage
  and torch state use public native APIs.
- The typed registry classifies reads and the torch pulse separately.
  The existing PolicyEngine requires approval for execute risk. The
  sole UI caller presents an explicit fixed-action confirmation and
  calls the internal controller only while the app is active. There
  is no model-callable, URL, App Intent or MCP exposure of this write.
- Torch pulse starts only from off, under the AVFoundation device
  configuration lock, at low intensity, with an intended three-second
  foreground duration. Cancellation attempts cleanup, including on
  navigation or scene changes. The device reports active/off; this is
  API observation, not an optical sensor measurement. If cleanup is
  uncertain, the screen disables another pulse until the user leaves
  the screen; the user must inspect Control Center. Never retry
  automatically. A crash or iOS suspension can prevent cleanup; this is
  not a guaranteed hardware timer. No camera recording or permission
  request. Existing torch activity is not taken over at admission.
- Local values remain in the view, no external delegation, model
  invocation, raw telemetry export or persistent task text.
- Six focused macOS Swift tests using a fake backend pass; generic
  iPhoneOS build succeeds (unsigned). Physical torch execution and
  UI acceptance are not yet performed; primary app unchanged.

## Next slices

1. Unify existing native diagnostic planner, document OCR, and reminder
   draft/approval into a typed local task controller. Model suggestions
   never directly execute writes. Preserve native receipts and journal.
2. Keep deterministic owner-selected tools available even with no local
   language model. Add a task-specific local model adapter, model
   qualification and explicit provider selection. No silent cloud
   fallback, no replay after uncertain execution.
3. Model Center: app-owned, user-initiated resumable HTTPS downloads
   of exact reviewed revisions; size/digest checks, bounded disk and
   process memory, private staging and atomic admission; release the
   active runtime before loading another. Do not equate development
   Mac copying with a standalone distribution path.
4. Add local document and knowledge search, speech and vision with
   explicit scope. Prefer public iOS APIs and app-local data. Calendar,
   reminders and contacts require the applicable native permission
   and task-specific authorization. Do not make private data available
   to model or plugin tools by default.
5. Native notifications and system-provided background task scheduling
   where available, with foreground/expiration constraints; no
   always-on arbitrary background agent claims. App Intents, Siri,
   Shortcuts and authenticated remote providers share the same narrow
   policy boundary; they are optional adapters, not the core.
6. Merge the reviewed integration stack only after independent review,
   exact-head CI and device acceptance. Keep the primary app and the
   model research lab distinct until the local product integration is
   tested.
