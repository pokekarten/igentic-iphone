# iGentic ChatGPT Sites — optional, owner-hosted reference

This directory holds a **locally tested read-only Worker**, NOT a running Site or a
registered ChatGPT plugin. It does not contain a credential, API key,
device pairing, user data, or an independent connection to an iPhone.

## Two independent user-facing options

1. **Skills-only plugin, no connected MCP:** The existing
   `igentic-chatgpt-iphone` skill may give three static, allowlisted
   `igentic://handoff/v1/...` URLs, explicitly labeling them as
   *manual navigation*, not evidence of a tool call. The owner opens the
   link from the iPhone and chooses the in-app destination.
2. **ChatGPT Sites (where available):** The owner creates a private
   ChatGPT Site with the read-only tools `iphone_chatgpt_handoff`,
   `igentic_get_capabilities` and `igentic_shortcuts_setup`. The sample
   `handoff-site.mjs` defines the desired input/output contract and
   imports the **same canonical** `prepareChatGPTHandoff` function used
   by the local plugin. `mcp-handler.mjs` implements the documented Sites
   JSON-RPC endpoint; `worker.mjs` serves it at `POST /mcp` and the fixed
   HTML page at `/`, without an external device API or arbitrary URL.
   `index.html` is an optional self-contained, accessible UI mockup for
   the three fixed navigation links. It makes **no network calls**.

Reference site-building prompt for the owner:

> Create a private iGentic handoff Site with the three allowlisted
> actions diagnostics, discovery and reminder-draft. Expose one read-only
> MCP tool named iphone_chatgpt_handoff that returns exactly the fields
> produced by prepareChatGPTHandoff in this repository. Do not add any
> generic phone control, other-app access, user text in URLs, private
> data, external API calls, secrets, or background actions. Show only
> these three fixed own-app links in the interface, with explicit
> owner-tap and second in-app confirmation warnings. Keep the Site
> private until the tools and permissions are reviewed. Publishing a
> Site to create a plugin requires a separate owner action.

## Status and acceptance

- The reference tool is tested for strict read-only schemas and exact
  parity with the Mac/portable MCP contract.
- The HTML is tested to contain exactly the three fixed first-party URLs
  and no script, form, analytics or external loading.
- There is **no deployed Site** or ChatGPT plugin connection proven by
  this repository. Installing the skill alone does not install iGentic
  on the iPhone and does not grant any iOS sandbox rights.
- Sites or plugin installation may not be available for every account
  or client surface; test the actual iPhone ChatGPT client.
- ChatGPT Plus may have the Sites/skills-only route even where direct
  custom MCP connection is unavailable. Avoid promising an installed
  mobile MCP tool.

Official sources (verified November 23, 2026):
- https://help.openai.com/en/articles/20001339-creating-and-using-chatgpt-sites
- https://help.openai.com/en/articles/20001547-hosting-a-plugin-with-chatgpt-sites
- https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt
- https://developers.openai.com/plugins/deploy/connect-chatgpt

## Local Sites Worker and deployment boundary

The Worker implements the stateless MCP `2026-07-28` contract:
`server/discover`, `tools/list`, and `tools/call`. Each request must carry
the version and client capabilities in `params._meta`, plus matching
`MCP-Protocol-Version` and `Mcp-Method` headers. Tool calls additionally
require an exact `Mcp-Name` header. Mismatched or missing headers return
HTTP 400 / JSON-RPC `-32020`; unsupported versions return HTTP 400 /
`-32022` with the supported version.

All successful MCP responses contain `resultType: "complete"` and fixed
`_meta["io.modelcontextprotocol/serverInfo"]` identity. Three read-only tools are advertised: the original handoff tool, a static
capability catalog and an owner-manual setup guide for the API-free iOS Shortcuts
ChatGPT loop. All return text content and `structuredContent.data`. The added
tools never claim device connectivity, shortcut creation or action execution.
This adapter does not implement a legacy MCP `initialize` handshake,
sessions, or SSE. Do not assume compatibility with legacy-only clients.

Requests are limited to 4 KiB (including streamed bodies without a declared
length). Unsupported HTTP methods, malformed JSON-RPC, batches, notifications,
additional tool arguments, write tools and arbitrary links are rejected. Error
responses do not echo arguments or caller identity. JSON-RPC IDs are echoed
as required by the protocol and must not contain personal information.
The Worker does not read authentication headers, store state, make outbound
requests, or import any device driver or credential-handling module.

**Hosting security prerequisite:** Sites authenticates callers and checks Site
access before forwarding `/mcp`. This adapter relies on that trusted boundary;
it is not a standalone authenticated server. Keep an eventual Site owner-only.
Do not expose this Worker through another host without equivalent access control.
No Site identity, production credential, connection, or deployment is included.

From the repository root, after the existing plugin dependencies are installed:

```sh
node --test plugins/iphone-connect/test/sites-mcp.test.mjs
plugins/iphone-connect/node_modules/.bin/esbuild \
  plugins/igentic-chatgpt-iphone/sites-reference/worker.mjs \
  --bundle --format=esm --platform=browser --loader:.html=text --loader:.txt=text \
  --outfile=plugins/iphone-connect/dist/sites-handoff/server/index.js
```

The test builds the actual Worker in memory, invokes its Fetch handler, and
checks the HTML and all three MCP routes. It also checks negative inputs and
stream cancellation. This is local runtime evidence, **not hosted ChatGPT E2E**.

For an authorized future Site, use the returned real `project_id` in
`.openai/hosting.json`, declare `capabilities: ["mcp"]`, omit `static`, and put
the bundle at `dist/server/index.js` in that Site's source checkout. The current
task permits publishing commits only to PR #406's existing branch, so no second
Sites source repository has been created or pushed. Site publication and plugin
installation remain separate from these repository tests. After approved private
publication, verify the generated plugin with an actual tool call, then verify
the link and manual confirmation in the actual ChatGPT iPhone client.


## Optional WebMCP browser-site tools (experimental, not Site-hosted MCP)

Separately from ChatGPT Sites' **server-hosted** MCP plugin, WebMCP
provides **browser-tab** tools through the draft
`document.modelContext.registerTool()` API. These are not equivalent:
registering WebMCP on a page does not install a ChatGPT plugin, publish
a Site, give ChatGPT mobile a tool, or create a remote MCP endpoint.

The independent `webmcp.html` example (only when hosted over trusted
HTTPS on a browser that supports the draft) uses same-origin
`webmcp-init.mjs` and `webmcp-site.mjs` to expose exactly one
read-only `iphone_chatgpt_handoff` tool with the same three fixed
actions and payload as the server-side portable API. There is **no
remote fetch, storage, arbitrary navigation or iOS action** in the
tool callback. The HTML also displays the same three manual links
without requiring WebMCP.

The adapter declines insecure contexts, embedded frames and browsers
without the API. It uses an AbortSignal to unregister on `pagehide`.
Only the single local JavaScript module is allowed by the page's
Content Security Policy (`script-src 'self'`, `connect-src 'none'`).
No external scripts, telemetry, cookies or authentication data are used.

As of November 23, 2026 the W3C community draft is experimental and
Chromium support depends on its version, flag/trial and document security.
The code is covered by a synthetic `document.modelContext` test
and a **separate real-browser opt-in acceptance**. The real-browser
test uses a temporary loopback HTTP server and a clean, isolated headless
Google Chrome 157 context with the experimental WebMCP flags enabled:

```sh
# From the repository root, with Node and the plugin's dev dependencies:
cd plugins/iphone-connect && npm ci --ignore-scripts && cd ../..
node scripts/smoke-chatgpt-webmcp-chrome.mjs
```

The acceptance invokes `document.modelContext.getTools()` and
`executeTool()` in **actual Chrome**, checks each of the three
read-only URLs, verifies an invalid action is rejected and confirms no
automatic navigation or external browser request. The test is
deterministic, prints only sanitized booleans, closes Chrome and its
temporary local server, and creates no app account or iPhone action.
The first run passed on Mac with Chrome 157 on November 23, 2026.
The experiment has **not** been verified in the user's ChatGPT mobile
app, in a hosted ChatGPT Site, or on mobile Safari. Native WebMCP
browser success is not equivalent to a connected ChatGPT plugin.

References:
- https://webmachinelearning.github.io/webmcp/
- https://developer.chrome.com/docs/modern-web-guidance/guides/webmcp/webmcp
- https://help.openai.com/en/articles/20001547-hosting-a-plugin-with-chatgpt-sites


## Operator console at /console (still read-only)

The original static / page remains usable without JavaScript and keeps the three
fixed first-party app links. The optional /console page uses a fixed same-origin
script at /console.js to call only the existing three Site MCP tools: capability
discovery, manual Shortcuts setup instructions, and a manual first-party handoff.
The script never posts arbitrary tasks, secrets or device identifiers, never
navigates automatically, and never renders untrusted HTML. Only exact known
app links can be shown after a validated tool response. All failures remain
non-executing; the iPhone is still not checked. The hosted Site must provide
its own owner authentication; this demo does not grant it.

The /console page permits only script-src self and connect-src self. The original
/ page keeps connect-src none. Static /console.js is served with no-store and
nosniff headers. The test bundle requires the additional --loader:.txt=text
flag, as above. This is not deployed to the private ChatGPT Site by GitHub.

To test the **actual Chrome browser interaction** in a temporary local-only
session after installing the existing plugin dev dependencies:

    node scripts/smoke-chatgpt-sites-console-chrome.mjs

This test serves the bundled Worker over 127.0.0.1 with an isolated
headless browser, clicks all three read-only controls, confirms three real
same-origin MCP calls, validates the owner-tapped link without following it,
and fails on external requests or page errors. It does not connect to
ChatGPT or any real iPhone, and does not publish the private Site.

The console bounds each operator-initiated browser request to 12 seconds, has an
explicit Cancel button, disables competing actions while a request is pending,
rejects late responses after cancellation, and removes stale handoff links on
destination changes. Cancelling a browser read never claims remote device
cancellation. Plugin unavailability is not interpreted as iPhone offline
verification.


### ChatGPT project context versus Shortcuts model replies

The read-only `igentic_shortcuts_setup` response distinguishes a
ChatGPT **Use Model** reply in Apple Shortcuts from a verified conversation in
a specific ChatGPT Project. Neither this Site nor a successful Shortcuts reply
proves project selection, conversation reuse, or context continuity. The
`projectChat` field and visible console warning are deliberately
`not-verified`, until signed native acceptance demonstrates it. No project
identifier, conversation URL, account token or arbitrary text is sent to Site
MCP tools.


### Site MCP registry self-check (owner-clicked)

The `/console` button **Site-MCP-Werkzeuge prüfen** performs two
same-origin, manually triggered read-only MCP calls, `server/discover`
and `tools/list`, using the exact mirrored method/version headers.
It checks the supported protocol, server identity, **exactly three**
allowlisted read-only tools, their non-destructive annotations and their
**exact, closed argument schemas** (empty arguments for discovery/setup; the
three fixed handoff actions for the navigation tool). Extra capabilities or
parameter names fail closed rather than being misreported as compatible.
Missing/stale registration, unexpected write authority, a failed request
or a forged response is reported as **not confirmed**, never as an
available iPhone connection. This is a deployed-Site compatibility check,
not proof of device access or actual task execution. Its code is still
reference source until owner-authorized publication of the existing
private Site.


### Copying a safe Site compatibility summary into ChatGPT (manual)

After the owner triggers successful `server/discover` and `tools/list` inspection,
a separate button can copy a **fixed, sanitized textual summary**. It contains
only the known protocol/server/tool names and explicitly *unverified* device,
execution and ChatGPT Project statuses. Neither raw server payloads nor the
browser URL, account identifiers, task bodies, secrets or device identifiers
are transferred. Clipboard writes need an explicit owner click and a capable
browser; permission rejection is non-executing. A failed recheck invalidates
the previous report, and leaving the page disables the copy action. This is a
manual ChatGPT context handoff, not automatic ChatGPT Project selection or a
signed device receipt.
