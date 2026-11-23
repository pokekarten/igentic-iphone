# iGentic ↔ ChatGPT: Native Agent Loop (architecture decision, 2026-11-23)

## Product objective

The iGentic app remains an independent privacy-first iPhone agent. ChatGPT is
an *optional* remote conversation/planning client. Two directions are required:

- **ChatGPT → iGentic:** use a real authenticated MCP tool to request one
  allowlisted capability, receive a real observed status/approval/result, and
  never equate a prepared navigation URL with completed device execution.
- **iGentic → AI:** send *user-selected, reviewed* tasks to a chosen assistant or
  an explicitly configured model provider, and process the result locally as an
  untrusted proposal under iGentic's existing policy and approval gates.

Neither a ChatGPT plugin nor App Intents intrinsically gives generic iOS shell
access, unrestricted taps, other apps' private data, or control of Shortcuts
without the relevant iOS/user permissions.

## Three distinct integration paths

| Route | Runtime | Exists today | Main limitation |
|---|---|---|---|
| iPhone-local App Intents + Shortcuts | Own signed iGentic app; user invokes Siri/Shortcuts | Existing fixed diagnostics intent; this change adds local status and task-preview intents | Does not expose arbitrary phone control to ChatGPT |
| Private ChatGPT MCP → Mac → Apple CoreDevice → iGentic | Mac running paired CoreDevice and a locally authorized MCP service | Independent physical Wi-Fi tests already verify own-app launch and fresh preview receipts | Current owner-private hosted Sites handoff **does not connect to the Mac**; must separately connect the physical MCP server via approved auth/private tunnel |
| Private ChatGPT MCP → owner gateway ↔ iGentic iOS companion | Secure outbound iPhone HTTPS/poll/push delivery; own app processes bounded commands | Separate cellular *readiness* companion exists, not remote command execution | Requires first-party gateway, authenticated enrollment and explicit permission; iOS can suspend background activity |

A Site serving the three \`igentic://handoff/v1/*\` links is a navigation-only
handoff. ChatGPT itself does **not** open those links on the phone: the owner or
an explicitly authorized local Mac test harness does. A Site must not be
expanded into an unprotected personal-device proxy.

## Canonical interaction / security invariants

1. **Discover:** \`igentic_get_capabilities\` returns an allowed-action
   registry including scope, data classification, hardware connection,
   permission requirement, and verified vs proposed availability. Unknown
   commands and device identifiers are rejected.
2. **Prepare:** a client submits a typed action, never free-form executable
   shell, Shortcut name or JavaScript. iGentic creates \`requestId\`,
   \`idempotencyKey\`, short expiry and nonce; the policy engine decides whether
   it is blocked, read-only, or needs review. Any model output is untrusted.
3. **Approve:** local owner review binds the exact action, parameters and
   destination. Privileged actions require a new owner confirmation and OS
   permissions. Reading private content needs separately scoped access and
   explicit disclosure approval.
4. **Execute:** a native, first-party capability adapter calls an app-owned
   function, applicable App Intent, or a *specific* authorized Shortcuts
   workflow. Broad \`run any shortcut\`, arbitrary taps, device shell, and
   bypasses of other-app iOS entitlements are not accepted.
5. **Verify:** receipt includes request ID, capability, outcome
   \`proposed | awaitingApproval | executed | failed | unknownOutcome\`,
   timestamp and **independent verification evidence**. A process launch,
   received URL or open network tunnel is not \`executed\`. Timeout after
   dispatch is \`unknownOutcome\`, never a blindly retried write.
6. **Return:** poll or respond through the authenticated MCP channel.
   Responses never automatically inject themselves into an existing consumer
   ChatGPT chat unless the platform explicitly supports that flow. Never return
   raw IDs, photos, notes, messages, credentials or log files by default.

Use short-lived signed request envelopes, authenticated owner/device binding,
rate limiting, replay defense, size limits, encrypted persistence,
least-privilege tool scopes, audit trails and an emergency disconnect/revoke
control. The MCP transport is separate from iOS authorization. A trusted tunnel
is not consent to a reminder write.

## App-owned capabilities to grow in order

| Capability | Proposed read/write boundary | Required evidence |
|---|---|---|
| \`igentic.device.status\` | Owner-requested battery %, low-power mode, iOS version only; **no unique identifiers** | Actual iOS App Intent/Shortcuts result; physical device additionally confirmed before claiming hardware proof |
| \`igentic.task.preview\` | On-device bounded text classification to own screens only, no execution | App Intent result, malicious-input tests |
| \`igentic.open.own_view\` | Diagnostics / discovery / manual preview only | Fresh nonce-matched view appearance receipt |
| \`igentic.offline.text\` | Local editor / speech; explicit user share | User-selected visible content, no silent upload |
| \`igentic.image.ocr\` | User-selected photo with Vision; no gallery-wide reads | Picker permission and owned-result approval |
| \`igentic.reminder.draft\` | Generate and display draft | No persistence without the existing EventKit/PolicyEngine approval flow |
| \`igentic.reminder.create\` | Explicitly authorized single reminder with idempotency | EventKit grant, owner approval, verified write |
| Calendar, contacts, files, location | Later, per-purpose Apple permissions and data minimization | Each independently implemented and audited; no generic extraction |
| Third-party app actions | Only supported published App Intents/Shortcuts under iOS rules | Explicitly available capabilities and approval; no assumption of general cross-app control |

## iGentic → ChatGPT / another model

1. **Implemented in this change, without credentials:** in Agent Home the owner
   types a bounded task, previews the safe local route, and explicitly invokes
   the iOS Share Sheet with the visible request. The owner may select ChatGPT
   *if that app supports the offered share action*, another compatible app,
   or cancel. This is not an automatic API call and has no automatic result
   callback. The on-device App Intent \`iGenticPrepareAgentTaskIntent\`
   exposes the same read-only planning result to Shortcuts.
2. **Optional next:** a separate model adapter using the OpenAI Responses API
   or an on-device model, explicitly configured by the owner. ChatGPT
   subscription access is **not** an API credential; never extract a ChatGPT
   session token from the consumer app. Remote API use needs separate billing,
   consent, credential storage and egress filtering.
3. **Return channel:** model/Shortcuts output is treated as an untrusted
   proposal and reviewed via \`UntrustedActionProposalGate\`,
   \`PolicyEngine\`, \`ApprovalManager\`, and \`AuditLog\`; never interpret raw
   assistant output as a device command.

## What this PR actually implements

- A real *local read-only* iOS battery/low-power/iOS-version provider for
  \`iGenticDeviceStatusIntent\`, available to the system Shortcuts registry.
- A separate \`iGenticPrepareAgentTaskIntent\` for bounded local intent
  classification. It returns only the proposed own-app route, not the private
  task text, and it executes nothing.
- A **manual**, user-selected native Share Sheet in Agent Home for
  sending the text to ChatGPT or another supported app, plus a local
  status button. No automatic network, write or provider dependency.
- Tests for unsupported actions, input bounds, missing battery measurements,
  private payload minimization and truthful connection labels.

No production plugin, Site, account, signing team, provisioning, Cloud API,
remote server, user reminders or device permissions are altered.

## Milestones with explicit acceptance

- **P0 – Native Shortcuts/Share:** Xcode iOS 27 build, Swift package tests;
  run iOS App Intents system tests; install newly signed build on the real
  iPhone and verify the status is genuinely returned by Shortcuts.
- **P1 – Mac optional runtime:** add a *read-only, nonce-bound* live status
  receipt API through native CoreDevice and independently test it via MCP
  on physical Wi-Fi; do not confuse it with the current fixed demo.
- **P2 – Private ChatGPT MCP:** reuse the existing physical MCP adapter behind
  an owner-authorized Secure MCP Tunnel / authenticated MCP endpoint; register
  a **separate** custom ChatGPT plugin and call
  \`igentic_get_capabilities\` / \`igentic_device_status\` from a real chat.
  Keep the current private handoff Site unchanged unless explicitly migrated.
- **P3 – Mac-free iPhone:** build an opt-in signed iOS companion, typed
  command queue, secure enrollment, review UI and trusted receipt return.
  Test with Wi-Fi disabled and mobile data, foreground and suspended. Publish
  bounded availability, not a false promise of an always-on iOS background agent.
- **P4 – Useful approved writes:** one reminder end-to-end, with approval,
  idempotency and independent verification; then add permissions incrementally.

## Source contracts

- Apple App Intents and Shortcuts:
  https://developer.apple.com/documentation/appintents
- Apple App Intents execution modes:
  https://developer.apple.com/documentation/appintents/getting-started-with-the-app-intents-framework
- OpenAI custom MCP server and private Secure MCP Tunnel:
  https://developers.openai.com/api/docs/guides/custom-mcp-server
  https://developers.openai.com/api/docs/guides/secure-mcp-tunnels

These documents define supported platform mechanisms, not proof of user account
access, remote enrollment, or actual phone functionality.
