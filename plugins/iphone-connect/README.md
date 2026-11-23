# iGentic iPhone Connect

Version 0.1.0 is a **local desktop developer plugin** for ChatGPT/Codex-compatible
MCP hosts. It includes fifteen typed tools, one skill, an MCP Apps dashboard with live route checks, a
physical-iPhone adapter, a separate fixture backend, and a Swift bridge to the
existing iGentic `PolicyEngine` and `AuditLog`.

The first-party read-only iphone_native_app_status tool inspects only the
configured iGentic app identity and exact running executable, using Apple
CoreDevice. It reports fixed booleans and no app paths, process IDs or
device identifiers. Process running does not mean foreground UI.

The implemented workflow is: discover the configured device, acquire a short
exclusive session, open our Diagnostics app, observe fixed public markers,
prepare and perform one safe discovery-navigation action, independently check
the result, and stop. Arbitrary cross-app control, screenshots, personal data,
reminder writes, general tap/type commands and public hosting are not exposed.
This is an executable initial capability boundary, not the entire product
roadmap in the [research atlas on Draft PR #379](https://github.com/pokekarten/igentic-iphone/blob/docs/iphone-agent-ecosystem-2026-11-21/docs/research/IPHONE_AGENT_PROJECT_ATLAS.md).

## Experimental ChatGPT-specific API handoff (new, read-only)

See [CHATGPT_HANDOFF.md](CHATGPT_HANDOFF.md). ChatGPT can connect to the
client-neutral, loopback-only Streamable HTTP MCP prototype using an approved
private MCP tunnel and call `iphone_chatgpt_handoff`. It returns only a
fixed `igentic://handoff/v1/...` link that the owner may open on their iPhone.
The signed iGentic app then displays a second in-app navigation choice.
This does not trigger App Intents, write reminders, reach the phone remotely,
connect a ChatGPT account automatically, or claim mobile-client support.
The existing read-only diagnostics App Intent remains separate.

A further offline-only security prototype is described in
[AUTHENTICATED_TASK_ENVELOPE.md](AUTHENTICATED_TASK_ENVELOPE.md): a strictly
read-only HMAC-authenticated owner-relay task proposal with expiry and
in-memory replay protection. It does **not** connect this plugin to an iPhone,
install a Site tool, start a server or execute any request. Real transport,
enrolment, persistent replay checks and device receipts remain separate gates.

## Requirements and setup

- macOS with Node.js 22+, Xcode and an already paired, unlocked physical iPhone.
- The already signed iGentic Diagnostics app installed on that phone. This setup
  does not install, remove, sign or grant permissions to any iPhone application.
- **First-party Apple CoreDevice + iGentic native view-receipt adapter** is
  the default. It needs no external mobile automation binary. It can only
  launch two fixed view routes in our own signed Diagnostics app and verify
  its per-launch UUID receipt.
- The separate MobileCLI implementation is a legacy **optional** driver; its
  own license applies only when explicitly selected.

### Connection paths: all retained, readiness never transferred

USB-C and Wi-Fi remain long-term supported development routes through the **same**
physical CoreDevice adapter, but an active paired physical Xcode tunnel is a
required gate. `iphone_list_devices` reports only a coarse, fixed
`connectionPath` (`usb-coredevice`, `network-coredevice`,
`coredevice-transport-unclassified` or `none`) and never exposes
the device's raw transport metadata. An unclassified but active tunnel can
remain CoreDevice-available; that does not establish whether it is USB or Wi-Fi.

| Path | Current boundary | Independent proof required |
| --- | --- | --- |
| USB-C | First-party Apple CoreDevice adapter | Fresh tunnel and own-app UUID receipt |
| Wi-Fi | First-party CoreDevice adapter, no MobileCLI dependency | Fresh network tunnel and own-app UUID receipt on real iPhone |
| Cellular | Optional native HTTPS readiness-only companion, code not deployed or hardware-verified | New signed iPhone app, owner-hosted HTTPS server and genuine mobile-data test |
| On-device | Native App Intents and Shortcuts, outside this Mac plugin | iPhone-local execution and owner permission |
| Simulator | Explicit fixture/native simulator tests, **not physical-device evidence** | Simulator-specific acceptance only |

Xcode 27 may report Wi-Fi as `localNetwork`; it maps to the fixed `network-coredevice` code **only while the paired physical tunnel is active**. A transient tunnel or Bonjour discovery alone is not evidence that MobileCLI can see the device.

The first-party driver uses Apple's devicectl plus a nonce-matched fixed receipt from our own SwiftUI view. This is **not** arbitrary iOS UI control. Read the [first-party implementation](FIRST_PARTY_COREDEVICE.md) and its physical-device test limits.

No route silently falls back to another. Disconnection cannot turn a remembered
USB, Wi-Fi, VPN or simulator path into an available physical iPhone.

### Cellular and VPN are not device-control transports

Tailscale can create a private IP path between enrolled devices over mobile data,
but installing it does **not** make an iPhone reachable through Xcode CoreDevice,
MobileCLI or this local MCP plugin. The existing physical backend requires a
currently usable, paired **physical** CoreDevice tunnel on the Mac. Its read-only
discovery rejects simulators, remembered-only pairings and stale USB transport
metadata whenever the reported tunnel is unavailable or disconnected.

Do not claim a 5G remote-control test from Tailscale login, an IP address or VPN
connectivity alone. The first-party cellular **readiness-only** companion has now been
implemented as a separate opt-in HTTPS client/server, but is not a remote
device-control transport. Its signed ping has no action execution. It
requires manual owner configuration of an HTTPS host and newly signed app;
no physical 4G/5G acceptance has happened. Any future device actions require
separate approval, scope and physical evidence. No public listener, generic iOS shell, cross-app automation or
unattended system-setting control is provided by this release.

From this directory:

```sh
npm ci --ignore-scripts
node scripts/setup.mjs
npm run doctor
npm run smoke

# Optional legacy driver only, when separately installed:
IGENTIC_IPHONE_DRIVER=mobilecli npm run doctor

# Real first-party own-app acceptance, USB-C and WLAN tested independently:
npm run smoke:usb
npm run smoke:wifi
```

Setup builds only the small Swift policy executable from this repository with
one compiler job, or uses the prebuilt helper in an architecture-specific
package. It discovers a single paired physical phone; if several exist, pass
`--device` in the **local** terminal. It writes private device configuration
under `~/Library/Application Support/iGentic/iphone-connect/config.json` with
0600 permissions. There are no provider credentials or model downloads.
The current fixed app identity is `de.bos.neoagent.igenticdiagnostics`; a second
supported development identity is `org.example.iGenticDiagnostics`. Changing
the identity in private config does not sign/install the app.

If the physical phone is unavailable, the server returns that state. When a
configured physical device is found, `iphone_list_devices` also reports one of
four **fixed, privacy-safe CoreDevice status codes**:
`xcode-tunnel-available`, `no-active-tunnel`, `pairing-required` or
`unsupported-device`. A missing device has no observed entry. An active Xcode
tunnel is **not** proof that MobileCLI or our app has been verified. No device
names, UDIDs, transport metadata or private screen content enter tool results.
For `no-active-tunnel`, reconnect USB-C, unlock the phone, confirm Trust and
check Xcode's Devices window; a VPN alone does not create the required tunnel.
The backend never substitutes the synthetic backend. Fixture mode is explicit:

```sh
IGENTIC_IPHONE_BACKEND=fixture npm run smoke
```

## Optional first-party mobile data (4G/5G)

Use [CELLULAR_COMPANION.md](CELLULAR_COMPANION.md) to set up an **owner-hosted**
authenticated HTTPS readiness gateway with no third-party mobile automation
software. It is a **separate route**, not an automatic CoreDevice fallback.
Use npm run serve:cellular only after explicit private-key/TLS configuration.
A manual tap in the newly installed iPhone app sends a fixed signed readiness
ping with no remote-control commands. Afterward, Apple URLSession
transaction metrics distinguish observed cellular transport from
non-cellular or unverified connections; they do not identify a 4G/5G
generation. The client never asserts a route from a Wi-Fi setting alone. The host code and simulator build are
not proof that the physical iPhone used cellular data.

## Portable iGentic plugin (ChatGPT is optional)

The primary goal is an independent native iPhone agent, with App Intents, Shortcuts and a client-neutral MCP interface. An additional read-only Streamable HTTP protocol preview is available with npm run serve:portable. It binds to loopback only and **does not** connect to the iPhone. The physical desktop stdio backend remains separate. See [portable architecture](PORTABLE_MCP.md).

The signed iOS app also contains a first-party **Offline-Werkzeuge** view with a local text editor, speech through Apple AVFoundation, user-selected photo OCR through Vision, and the existing separate approved reminder workflow. None requires ChatGPT, the Mac, MobileCLI or an external model. These changes require installing the **updated** signed app to use on a physical phone. See [optional tools and true fallback limits](OPTIONAL_TOOLS.md).

## Install the desktop plugin

From the repository root, after dependency setup:

```sh
codex plugin marketplace add .
codex plugin add igentic-iphone-connect@igentic-local
```

The repository marketplace is `.agents/plugins/marketplace.json`. The CLI copies
the plugin into its local cache; refresh/reinstall after changing source. Open a
new local chat with the plugin enabled. The portable `mcp.json` starts the local
server with Node; it opens no TCP listener. The same server can be configured
directly in another MCP client with an absolute path to `src/server.mjs`.

Example request:

> Use iGentic iPhone Connect to open our Diagnostics app, open its bundled
> discovery page, verify the result and stop the session.

Installation in a local Codex cache is not proof of registration or a successful
tool invocation in ChatGPT web. The latter needs an account-authorized custom
MCP connection. Official [connection instructions](https://developers.openai.com/plugins/deploy/connect-chatgpt)
support an HTTPS endpoint or [Secure MCP Tunnel](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels).
The stdio server can be placed behind an eligible private tunnel. This package
does not create a tunnel, collect an API key, configure OAuth, publish a service
or register itself in a ChatGPT account. Public local-MCP submission is currently
limited to approved partners; see [desktop-only plugins](https://developers.openai.com/plugins/deploy/desktop-only).

## Tools

| Tool | Behavior |
| --- | --- |
| `iphone_list_devices` | Return only configured alias, backend and observed connection availability |
| `iphone_connection_report` | Read-only live physical-tunnel status and independent USB-C, Wi-Fi, cellular, on-device and test route states; never claims an unverified app action |
| `iphone_get_capabilities` | Explain current capability boundary without claiming readiness |
| `iphone_tool_catalog` | List built-in offline functions and independent optional providers without assuming they are installed |
| `iphone_prepare_local_task` | Prepare non-executing native handoff instructions even with no Mac, network or iPhone connection |
| `iphone_start_session` | Acquire a five-minute exclusive device lease |
| `iphone_open_diagnostics` | Launch the fixed app, check foreground identity and return recognized markers |
| `iphone_observe` | Refresh fixed marker/count observation; suppress raw content |
| `iphone_prepare_action` | Bind `open-discovery` to the current observation |
| `iphone_execute_action` | Reobserve, consume proposal once, dispatch and independently verify |
| `iphone_get_action_result` | Read this session's action receipt |
| `iphone_stop_session` | Abort pending work and release lease after in-flight work stops |
| `iphone_show_dashboard` | Render the MCP Apps card with refresh and stop controls |

Strict schemas reject extra fields, including caller-supplied `approved`.
Commands use `spawn` without a shell, bounded output and deadlines. Only
fixed read/prepare operations can pass the Swift policy bridge. This bridge
does not fabricate `ApprovalReceipt`s; persistent mutations remain unavailable.
Readiness is reported separately from configuration. Device output and UI text
never become instructions or permissions.

An interrupted dispatched action is `unknownOutcome`; it cannot be reused or
silently rerouted. Stop does not undo an effect already dispatched.
Stopped-session receipts remain temporarily readable, but the in-memory cache is
bounded to 128 recent sessions and 128 action receipts; oldest closed-session
history and older receipts are evicted. Expired or evicted receipts cannot
reauthorize an action. The client can start new sessions after 128 stop cycles
without restarting or clearing the cross-process lease. A lease left
after a crash is not automatically stolen: run doctor, inspect the phone, stop
any owning process, and only then remove that one stale `device.lease` file.

The private state directory is single-user local authority. Do not expose this
stdio process as an unauthenticated network service or reuse it as a multi-user
gateway. The driver has a residual observation-to-input race; v0.1 only permits
opening bundled content, where that limited authority is acceptable. Broader
UI actions need stronger native/driver atomicity and action-level approval.

## Validate and package

```sh
npm run build:ui
npm test
IGENTIC_IPHONE_BACKEND=fixture npm run smoke
npm run smoke
```

`npm test` runs service, input, privacy, cross-process lease, replay, interruption,
MCP protocol and browser UI checks. The browser test uses an existing Chrome
installation (`CHROME_BIN` overrides discovery); when absent it is explicitly
skipped. Set `IGENTIC_POLICY_TEST_PATH` to a built helper to exercise the actual
Swift bridge in the Node suite; otherwise that test is explicitly skipped.
`npm run smoke` without fixture mode uses the actual configured phone and
requires independent observation of the discovery page to pass.

To build a platform-specific archive with runtime dependencies and the compiled
helper (but no MobileCLI, personal configuration, screenshots or credentials):

```sh
IGENTIC_POLICY_TEST_PATH=/absolute/path/to/iGenticPluginPolicy npm run package
```

The archive and SHA-256 are written to ignored `dist/`. A source checkout can
compile the helper; an extracted archive must include the helper for its target
architecture or receive one through setup's `--policy` option. The generated
HTML is self-contained and uses the official MCP Apps bridge. No external
resource or connection domains are allowed by the resource CSP.

See [privacy](PRIVACY.md), [third-party notices](THIRD_PARTY_NOTICES.md) and the
[implementation evidence](../../docs/reports/chatgpt-iphone-plugin-2026-11-22.md).


### Reproduce a published ChatGPT Site plugin response on the physical iPhone

The optional `smoke:published:wifi` command accepts **three actual tool-result
objects supplied by the operator**, in order: `diagnostics`, `discovery`,
`reminder-draft`. Each must contain `structuredContent.data` with the exact
canonical handoff contract. Supply only these public, fixed fields: no account
identifiers, tokens, phone records or other user data.

```sh
# On the owner’s Mac, with the paired physical iPhone reachable over Wi-Fi:
npm run smoke:published:wifi < /path/to/three-site-tool-results.json
```

The test rejects altered URLs, changed authorization/status fields and
non-Wi-Fi devices. It dispatches only the three fixed **own-app preview** URLs
using Apple CoreDevice, and requires a fresh, nonce-like, app-owned receipt
after each dispatch. It never creates a reminder, invokes a generic iOS shell,
reads private phone data or bypasses the in-app confirmation.

**Scope:** The operator must obtain the responses from the *real installed
ChatGPT Site plugin* and hand them to this program. The program cannot
independently authenticate their origin. Success proves the submitted fixed
links can open app-owned previews over the Mac-to-iPhone route, **not**
autonomous Site-to-Mac communication, a human owner tap, approval of writes,
cellular reachability, or direct live phone control by the hosted Site.
A future remote connection requires a separately authenticated gateway or
a private Secure MCP Tunnel and a newly connected plugin; do not expose the
loopback MCP endpoint publicly.
