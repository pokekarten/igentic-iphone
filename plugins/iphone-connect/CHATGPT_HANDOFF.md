# ChatGPT → iGentic iPhone: tiny API-only plugin prototype

**Status:** draft source prototype; not installed in a ChatGPT account or on a physical iPhone.
**Scope:** one read-only MCP tool and three fixed user-tapped routes to **our own app**.

## Availability gates: web, mobile, and account

As of 2026-11-23, the official OpenAI Help Center describes direct custom
MCP-server connection and full MCP support on **ChatGPT web** for eligible
**Business and Enterprise/Edu organizations**. Do not promise that an
individual account has the **Add custom MCP server** control. Mobile cannot
*set up* a custom MCP server connection, and a locally saved plugin with
local-only apps does not automatically make those tools available on web
or mobile. The actual target ChatGPT client must be tested separately.

Alternative deployment paths described by OpenAI include hosting an MCP app
with **ChatGPT Sites** where available, or preparing a stable authenticated
public HTTPS MCP endpoint for plugin submission. Neither path unlocks iOS
sandbox permissions, installs a signed iGentic app, or proves mobile client
tool execution. The current service binds only to `127.0.0.1`; keep it
there until a separately reviewed HTTPS/authentication architecture exists.

Platform references:
- https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt
- https://help.openai.com/en/articles/20001256-plugins-in-chatgpt
- https://help.openai.com/en/articles/20001547-hosting-a-plugin-with-chatgpt-sites
- https://developers.openai.com/plugins/deploy/connect-chatgpt

## The real ChatGPT plugin connection

ChatGPT is the intended client. A generic MCP client is useful only for protocol
testing. The existing portable MCP server implements **Streamable HTTP** at
`/mcp`, and the new `iphone_chatgpt_handoff` tool is registered there.

```text
ChatGPT (MCP tool call)
  -> own HTTPS MCP host or approved Secure MCP Tunnel
  -> iphone_chatgpt_handoff({ action: "discovery" })
  -> igentic://handoff/v1/discovery (a navigation link, no phone action)
  -> user opens link on iPhone with a signed iGentic app installed
  -> iGentic displays the destination and waits for a second manual tap
  -> local native UI; existing App Intents / reminder approvals stay separate
```

Supported actions: `diagnostics`, `discovery`, `reminder-draft`. No user
text is encoded in links. No external app, system setting, shortcut name,
reminder content, token, device identifier, or generic URL is accepted.

The iOS Xcode target registers the `igentic` URL scheme, and SwiftUI uses
`onOpenURL` to parse exactly these three paths. URL schemes may be claimed
by other apps and are **not authentication**. Treat links as untrusted
navigation requests, never action authority. In particular, `reminder-draft`
only opens the existing editor after a user tap; no reminder is created by MCP.

## Local protocol test

```sh
cd plugins/iphone-connect
npm ci --ignore-scripts
npm test
npm run serve:portable
# MCP URL: http://127.0.0.1:37865/mcp (localhost ONLY)
```

Connect any SDK-compatible test client or MCP Inspector to the local URL,
list `iphone_chatgpt_handoff`, then call it with
`{"action":"discovery"}`. Check that it returns the fixed route, both
`actionExecuted:false` and `requiresOwnerTap:true`, and that unknown actions
are rejected. Existing `iphone_get_capabilities`, `iphone_tool_catalog`,
`iphone_connection_report`, and `iphone_prepare_local_task` remain available.

## Connect through ChatGPT (manual owner step)

1. Start the MCP service on a trusted host. For a personal private test use an
   approved **Secure MCP Tunnel**; do not expose the unauthenticated loopback
   preview directly to the Internet.
2. **Only if the account/workspace supports custom MCP connections**, on
   **ChatGPT web** open **Plugins** → **+** → **Add custom MCP server**.
   Configure the trusted HTTPS/tunnel connection, acknowledge the risk, and
   create the plugin. If the control is absent, stop here and check eligibility
   or a supported ChatGPT Sites hosting path; do not treat local installation
   as a working mobile connection. This test server is read-only.
3. Discover the five read-only tools, and invoke
   `iphone_chatgpt_handoff` with `action:"discovery"`.
4. Transfer/open the returned URL on the iPhone **manually**. A signed iGentic
   build with its URL scheme must already be installed. Verify that the app
   first displays the handoff prompt and does **not** auto-execute a task.
5. Run the same exercise for Diagnostics and Reminder Draft. Confirm that
   a reminder write still requires the existing separate local approval.
6. For a direct full mobile ChatGPT-to-phone journey, measure actual client
   support rather than assuming that tool-result URLs are tappable. Custom
   MCP **connection setup** is currently web-only.

Apple App Intents already supply a **separate read-only diagnostics Shortcut**
in the app. This prototype intentionally does **not** call an App Intent
remotely: an MCP tool result cannot directly bypass iOS app sandbox or execute
another app's Shortcut. The next experiment may add an authenticated,
foreground-only on-device request inbox with owner-bound receipts.

## Physical-device acceptance still outstanding

- [ ] Build, sign and install the exact PR app on the owner's iPhone.
- [ ] Open each fixed `igentic://handoff/v1/...` route from the actual iPhone.
- [ ] Verify the local second-tap confirmation; no route auto-executes.
- [ ] Confirm an unknown route is ignored without navigating or approving.
- [ ] Verify a real ChatGPT tool invocation **only if account and remote MCP
      connection eligibility are confirmed**. Save a redacted receipt of the
      tool result, then separately verify that the phone handled the link.
- [ ] Repeat over cellular without a Mac **only after** a separate on-device
      or hosted transport design is implemented and authorized.

The Node tests and simulator CI prove code contracts and simulator UI only;
they are not evidence that the ChatGPT account or physical phone is connected.

## Do not call this remote iPhone control

There is **no** hosted HTTPS service, OAuth provider, online account binding,
automated ChatGPT connection, remote App Intents execution, mobile-data test,
background daemon, generic tap/type, cross-app automation or physical-device
acceptance in this PR. This is an API contract plus a locally initiated,
platform-supported app-navigation test. The server does not know if the phone
is installed, connected, opened, or which screen is displayed.

A later true phone-control plugin would require an authenticated per-user
gateway, device pairing, scopes, nonce/expiry and replay protection, a
foreground or explicitly permitted lifecycle on the phone, local approvals,
and independently observed receipts. Require OAuth 2.1 before any customer
data or write action crosses the public MCP boundary.

## Primary references (verified 2026-11-23)

- https://developers.openai.com/plugins/build/mcp-server
- https://developers.openai.com/plugins/deploy/connect-chatgpt
- https://developers.openai.com/plugins/build/auth
- https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt
- https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app
- https://developer.apple.com/documentation/swiftui/view/onopenurl(perform:)
- https://developer.apple.com/documentation/appintents


## Physical preview-receipt acceptance (iOS 27 / first-party WLAN)

The signed iGentic app emits a five-field `igentic-chatgpt-preview-receipt.json`
only when its native **handoff preview sheet** appears. It contains
`schema`, fresh random `eventID`, allowlisted `route`, fixed `view`
and fixed `status`; no text from the request, account info, authorization
or phone identity is stored. This is observational **not** an action receipt.

On the owner-paired physical iPhone with a live Wi-Fi CoreDevice tunnel and
installed signed current app, run:

```sh
cd plugins/iphone-connect
npm run smoke:handoff:wifi
```

The script requires the existing private iGentic pairing/policy configuration,
rejects fixture and MobileCLI modes and fails if the active tunnel is not
`network-coredevice`. It opens two fixed own-app URLs for `diagnostics`
and `discovery` and verifies that the second app-owned preview receipt has
a **different eventID** from the first. All raw CoreDevice output and receipt
contents remain local; the console prints only sanitized fixed booleans.
Do not treat the test as a ChatGPT-account invocation, a screen capture,
an owner approval, a reminder write, an App Intent execution or general
cross-app UI control.
