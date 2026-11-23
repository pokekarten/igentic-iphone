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
   ChatGPT Site with a tool named `iphone_chatgpt_handoff`. The sample
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
`_meta["io.modelcontextprotocol/serverInfo"]` identity. Exactly one
read-only tool is advertised, returning both text content and
`structuredContent.data` with the original handoff contract.
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
  --bundle --format=esm --platform=browser --loader:.html=text \
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
