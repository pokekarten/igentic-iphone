# ChatGPT → iGentic iPhone: tiny API-only plugin prototype

**Status:** draft source prototype; a signed test app is installed on the physical iPhone Air, but no ChatGPT account is connected.
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

## Physical-device acceptance and remaining gates

- [x] Build, sign and install PR #406 on the physical iPhone Air over Wi-Fi.
- [x] Dispatch the allowlisted diagnostics/discovery links via CoreDevice
      and independently verify fresh first-party sheet receipts on the phone.
      The reminder-draft physical route remains a separate acceptance task.
- [ ] Verify the local second-tap confirmation; no route auto-executes.
- [ ] Confirm an unknown route is ignored without navigating or approving.
- [ ] Verify a real ChatGPT tool invocation **only if account and remote MCP
      connection eligibility are confirmed**. Save a redacted receipt of the
      tool result, then separately verify that the phone handled the link.
- [ ] Repeat over cellular without a Mac **only after** a separate on-device
      or hosted transport design is implemented and authorized.

Node tests and simulator CI alone prove only code contracts and simulator UI.
Separate Apple CoreDevice WLAN tests have now independently verified the first-party
signed app and handoff sheet on the physical iPhone; an actual ChatGPT-account
invocation remains untested.

## Do not call this remote iPhone control

There is **no** hosted HTTPS service, OAuth provider, online account binding,
automated ChatGPT connection, remote App Intents execution, mobile-data test,
background daemon, generic tap/type, cross-app automation or generic iPhone control in this PR. The narrow first-party physical
own-app URL dispatch and sheet receipts have now passed; a real connected
ChatGPT account/tool invocation remains unverified. The server does not know if the phone
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
`network-coredevice`. It starts a local-only Streamable HTTP MCP server,
uses a **real MCP SDK client** to call the allowlisted
`iphone_chatgpt_handoff` tool for `diagnostics` and `discovery`, and
rejects any result that differs from the exact expected own-app URL or
the read-only, unexecuted handoff contract. The **Mac test harness** then
opens these two resulting links via Apple CoreDevice and independently
verifies a fresh app-owned handoff-preview receipt for each, including
a **different eventID** for the second receipt. Raw CoreDevice output,
receipt contents and UUIDs stay local; the test console exposes only
sanitized fixed fields. This is a complete **local MCP-test-client -> Mac
CoreDevice -> own iPhone app** hardware acceptance, *not* an invocation
from a connected ChatGPT account, a user tap, an owner approval, a reminder
write, an App Intent execution, cellular operation, or cross-app control.


## OAuth resource-server boundary (staged, NOT yet publicly deployable)

The portable MCP service now supports an **optional OAuth 2.1 resource-server
integration seam** in `startPortableGateway({ oauth })`, requiring an explicit
HTTPS resource identifier, HTTPS authorization-server origin(s), and a trusted
`verifyAccessToken` callback. When configured, it publishes
`/.well-known/oauth-protected-resource`, challenges unauthenticated MCP
requests with `WWW-Authenticate: Bearer resource_metadata=...`, and
independently checks the returned verified claims for issuer, resource
audience, expiration, not-before and fixed read-only scope
`igentic:handoff:read`. The existing default local gateway is unchanged:
it binds `127.0.0.1`, never a public interface, and does not assert an
iPhone connection.

**This is not a deployed OAuth provider or a signed-token verifier.**
Before exposing a private service through an approved Secure MCP Tunnel or a
trusted HTTPS ingress, choose a well-supported OAuth 2.1 identity provider
and implement `verifyAccessToken` with actual JWKS signature, issuer,
audience, expiry and scope validation. The provider must supply authorization
code + PKCE, resource indicator support and CIMD/DCR as required by ChatGPT.
The new Node tests deliberately use **synthetic fixture claims**, not valid
production credentials or a real ChatGPT account.

The local HTTP listener also refuses forged Host/Origin headers, untrusted
forwarded-host hints, oversized JSON posts and unbounded/chunked bodies.
Such transport hardening is defense-in-depth, not a substitute for a trusted
identity provider, secure tunnel, TLS, browser approval or device consent.
No public DNS, credentials, authorization issuer, secret token or hosted
endpoint is provisioned by this PR.

Run `npm test` and inspect `test/portable-gateway-security.test.mjs`
for the positive real MCP SDK client path and the negative auth/rebinding tests.
Relevant docs:
- https://developers.openai.com/plugins/build/auth
- https://developers.openai.com/plugins/build/mcp-server
- https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt


## Cryptographically verified JWKS access tokens (staging only)

The portable gateway now includes a **real JOSE JWT access-token verifier**,
not just a mockable OAuth callback. The default remains private
`127.0.0.1` and does not read or control the phone. In an explicitly
operator-configured staging shell, provide these *public* trusted metadata
settings (never a private signing key or personal token):

```sh
export IGENTIC_OAUTH_ISSUER=https://issuer.example.org
export IGENTIC_OAUTH_RESOURCE=https://mcp.example.org
export IGENTIC_OAUTH_JWKS_URI=https://issuer.example.org/.well-known/jwks.json
npm run serve:portable
```

This **does not deploy HTTPS**; the service intentionally still binds
`127.0.0.1`. All three fields must be present or startup fails closed.
The issuer and resource must be exact HTTPS origins; the JWKS URI must
be a fixed HTTPS URL **under the issuer origin**. Choose a trusted real
OAuth 2.1 identity provider and configure that provider to issue short-lived,
asymmetric JWT access tokens with `iss`, `aud`, `sub`, `iat`,
`exp` and space-delimited `scope`, including `igentic:handoff:read`.

The `jose` verifier pins allowed asymmetric algorithms (RS256, PS256,
ES256, EdDSA), rejects unsigned or HMAC-signed tokens, verifies the
signature against the trusted remote JWKS and validates issuer, audience,
subject, expiration, not-before, an issuance age at most one hour,
and the required read-only scope. The JWKS address is configured by the
operator; `jku` and `x5u` URLs inside token headers cannot redirect
key retrieval. Remote JWKS fetches have bounded timeout and caching.
The token and key are never emitted in MCP outputs.

Tests generate **temporary RSA keys** to cryptographically sign
disposable JWTs and verify both rejection cases and actual successful
read-only MCP calls; no real identity provider, live account, secret or
TLS server is used. These tests are not proof of a working OAuth
authorization-code/PKCE exchange from ChatGPT.

Before a real ChatGPT connection, separately complete: eligible
ChatGPT plugin/connector entitlement, real identity-provider discovery
and client registration (CIMD/DCR as supported), PKCE S256 code flow,
an approved Secure MCP Tunnel or stable HTTPS ingress, ownership and
user authorization, and safe physical iPhone invocation. Do **not**
publish the local listener or treat token verification as authorization
for other-app control or write operations.
