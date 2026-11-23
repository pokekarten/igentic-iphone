# iGentic ChatGPT Sites — optional, owner-hosted reference

This directory holds a **read-only reference**, NOT a running Site or a
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
   by the local plugin. In the ChatGPT Sites builder, adapt this pure
   function to the Site's supported MCP-tool registration API, without
   adding any external device API, app installation, or arbitrary URL.
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
