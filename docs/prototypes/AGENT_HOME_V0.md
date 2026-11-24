# iGentic Agent Home V0 — native-first, chat-shaped prototype

Status: review-only prototype on top of PR #403; not a physical-device claim.

## Product shape

An iPhone-native **agent surface**, not an OpenAI/ChatGPT dependency:
1. **Chat** — typed or dictated requests, clear provenance and action preview.
2. **Tools** — native offline actions (text, TTS, selected-photo OCR, reminder creation) plus dynamically reported optional adapters.
3. **Tasks** — explicit draft → policy → approval → execute → verify receipts, with pending/failed/uncertain states.
4. **Devices** — truthful diagnostics for USB-C, Wi-Fi and owner-hosted cellular readiness; never infer action capability from pairing or HTTP reachability.

The target UI may eventually render conversational responses. V0 deliberately does **not** pretend that a chat completion, model generation or remote iPhone action has happened.

## What this PR wires

- `DiagnosticView` opens `AgentHomePrototypeView` in the existing navigation stack.
- A local, bounded 512-character preview entry uses `AgentHomeCommandRouter` (deterministic, no model).
- An allowlist recognizes four destinations: offline tools, manual reminder draft, discovery and diagnostics.
- Unsupported commands, messaging, system settings, deletion or cross-app control return a non-executing message.
- User must explicitly navigate and separately approve actual actions in existing flows.
- No data persistence, collection, network transmission, new iOS entitlements or external runtime is added.
- Focused route tests distinguish harmless navigation from unsupported execution.

## Recommended next vertical slices

### A. Proper typed capabilities (native-first)

`AgentCapability` includes stable action ID, JSON schema, risk tier, data classification and supported execution pathway. `AgentCore.ToolRegistry` remains authority, not the model or client.

Example initial IDs:
- `diagnostics.read`: local read-only, system model not required.
- `offline.text.prepare`: in-app draft, user-visible content, no send.
- `offline.photo.ocr`: selected image, ephemeral, only in foreground.
- `reminder.create.draft`: native EventKit flow, exact human-bound approval before write.
- `device.connection.read`: truthful availability/status projection without claiming control.
- `own_app.discovery.open`: limited own-app navigation with a view receipt when available.

Do **not** advertise a generic `iphone.tap`, `iphone.shell`, `settings.modify` or `cross_app.read` capability. Those are not App Intents entitlements.

### B. App Intents bridge

Expose a small, typed App Intents layer from the installed iPhone application to Siri, Spotlight, Shortcuts and the Action button. **App Intents expose this app's supported actions**, not arbitrary third-party control. Reuse `AgentCore` policy for every read/write; only an owner-visible, non-bypassable approval flow can authorize an actual write.

Start with status and draft intents already represented by PRs #380, #390 and #399; avoid duplicating AppShortcut registration. Route an App Intent to the *same* native tool handler as the chat UI; test invocation from Shortcuts on a signed physical iPhone.

### C. Model-agnostic planner

```text
native chat / App Intent / Siri / optional MCP client
    -> sanitized typed request
    -> on-device planner (Apple model or pinned open-weight; rule fallback)
    -> untrusted proposal validator + capability allowlist
    -> PolicyEngine / ApprovalManager
    -> on-device executor or approved delegate
    -> actual observation / receipt / AuditLog
    -> chat/task timeline
```

The model may propose; it may **never** approve its own action, forge a receipt or lower privacy classification. The no-model deterministic route remains usable offline. The user explicitly opts in to external models and Mac/cellular delegation; they are never prerequisites for text, speech, OCR or manual reminder tasks.

### D. Optional connections

- **Mac USB-C/Wi-Fi**: first-party CoreDevice own-app actions (PR #401); optional MobileCLI/MCP only as extra drivers.
- **Cellular**: owner-server HTTPS with enrollment, authentication, replay protection and bounded task handoff; PR #402 proves readiness only, not remote execution.
- **ChatGPT**: external UI/client through a scoped authenticated MCP gateway; not a system iOS plugin or a way to bypass iOS sandbox. Portable loopback-only MCP is not a remote iPhone bridge.
- **Other clients**: same typed capabilities and server protocols, no ChatGPT-specific core assumptions.

## Concrete first end-to-end scenario

Owner types: "Erinnere mich morgen um 18 Uhr an die Pflanze."
1. UI displays the user text and a **draft** proposal. No write occurs.
2. Native `reminder.create.draft` opens the existing editor and (in a later slice) pre-fills only validated fields.
3. Owner checks title/date/destination and approves.
4. EventKit write runs using granted permissions and a one-use bound capability.
5. Success is shown **only after read-back verification**. An uncertain result explicitly asks the owner to inspect the target before retrying.

The current V0 stops at step 2's **manual editor navigation**. It does **not** transfer request text, call an LLM, request an EventKit write or claim a completed action.

## Physical acceptance (not yet performed for this PR)

- Build signed iOS 27 app on the real iPhone Air; first run shows policy setup.
- Verify agent home opens and is fully usable offline with Mac off.
- Verify "delete reminders" and "send SMS" never execute.
- Verify navigation to manual reminder and optional photo OCR; validate permission prompts.
- Test existing `Check Local AI` App Intent from Shortcuts separately.
- Test VoiceOver, Dynamic Type, interruption/termination, network denial and battery.
- Optional routes get their **own** independent physical proof; no proof is inherited from simulator, PR #392 historical USB-C tests or MCP fixtures.

## Links

- [Apple App Intents](https://developer.apple.com/documentation/appintents)
- [Apple Foundation Models](https://developer.apple.com/documentation/foundationmodels)
- [ChatGPT Apps SDK](https://help.openai.com/en/articles/12515353-building-with-the-apps-sdk)
