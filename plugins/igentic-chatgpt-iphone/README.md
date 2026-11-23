# iGentic iPhone for ChatGPT — experimental personal plugin

This is a **ChatGPT-first skill plugin** in the iGentic monorepo. Its goal
is to make the iPhone workflow understandable in ChatGPT **without needing a
Mac, a local device driver, or a live API connection just to provide guidance**.

It is deliberately **separate** from `plugins/iphone-connect`, which
provides the native CoreDevice desktop driver and the experimental read-only
HTTP MCP API. This package contains **only instructions**; it has no code
execution rights and no physical iPhone connection.

## Where the API lives

The actual first-party API tool is `iphone_chatgpt_handoff` in
[`plugins/iphone-connect/src/portable-gateway.mjs`](../iphone-connect/src/portable-gateway.mjs).

To use that tool *from* ChatGPT, the user must separately connect an allowed
custom MCP server (through a verified HTTPS endpoint or an approved Secure
MCP Tunnel). See [ChatGPT API setup](../iphone-connect/CHATGPT_HANDOFF.md).
Without that connection, **no tool invocation happens**.

## Local plugin authoring and testing

The repo marketplace is `.agents/plugins/marketplace.json`. It lists both:

- `igentic-iphone-connect`: Mac/desktop execution and diagnostics (may
  require a paired physical iPhone).
- `igentic-chatgpt-iphone`: this ChatGPT-first **read-only skill**, usable
  for safe task handoff instructions without any external app.

In supported ChatGPT desktop / Work / Codex plugin authoring workflows,
register the repo marketplace, refresh it, and install
`igentic-chatgpt-iphone`. Merely committing the marketplace manifest does
**not** install it into anyone's ChatGPT account or phone. A plugin skill
is not automatically linked to the portable MCP server: connection and
authorization remain separate.

The public plugin builder can also package the `plugin.json` and
`skills/igentic-chatgpt-iphone/SKILL.md` files via Plugin Creator.
For mobile use, test the user's actual ChatGPT client and its entitlement
rather than assuming that a desktop-local app works on mobile.

## Expected prompts

- "Öffne die iGentic-Diagnose auf meinem iPhone."
- "Zeige mir die lokalen Entdeckungen in iGentic."
- "Bereite auf meinem iPhone einen Erinnerungsentwurf vor."

The result must indicate whether the MCP tool actually ran, whether the
iPhone app is installed (currently **not checked**), and that opening the
resulting `igentic://handoff/v1/...` navigation URL and choosing the
in-app destination are **manual user actions**.

For requests such as "change iPhone system settings", "send a message" or
"tap across other apps", return an unsupported capability; never claim
ChatGPT can cross the iOS sandbox.

## Acceptance / non-goals

- A plugin skill can be installed without proving any iPhone operation.
- The API's current 3 fixed routes are navigation-only and transfer no text.
- No device enrollment, Apple signing, App Store install, ChatGPT account
  installation, hosted API, OAuth identity, 5G delivery or true App Intents
  remote execution is supplied here.
- Future authenticated per-device task delivery, user approval, and a
  signed independently verified result belong in a **separate scoped PR**.

Official docs:
https://developers.openai.com/plugins/build/plugins
https://developers.openai.com/plugins/deploy/connect-chatgpt
https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt


## ChatGPT Sites and skills-only fallback

The owner can use a **skills-only plugin** for three exact manual app
links without a connected MCP server. See
`sites-reference/README.md` for the optional owner-hosted ChatGPT Sites
reference contract and static link page.

ChatGPT Plus supports Sites (subject to access), while directly adding
a custom MCP server is currently restricted to eligible Business and
Enterprise/Edu workspaces on ChatGPT web. Setting up custom MCP servers
on iPhone is not supported. A published Site and its associated plugin
require separate owner actions; these source files do not create them.
The Site reference makes no personal-data or device-connection claims.

A separate draft source update adds two read-only Site MCP tools:
- igentic_get_capabilities: truthful static capability discovery.
- igentic_shortcuts_setup: owner-manual five-step Shortcuts guide for the
  API-free ChatGPT reply loop with an unchanged task correlation ID.
These are not part of the skills-only plugin and are not available from the
currently deployed private Site until separately published by its owner.
They never check or operate the phone; iphone_chatgpt_handoff remains unchanged.


## WebMCP browser experiment

The extra `sites-reference/webmcp.html` page offers an optional
browser-native `document.modelContext` tool when available in a secure,
top-level browser tab. Unlike a Site-hosted MCP server, WebMCP is local
to that browser document and is **not** automatically available as a
ChatGPT plugin. See `sites-reference/README.md` for the distinction
and explicit approval requirements. The original static no-JavaScript
`sites-reference/index.html` remains the safest fallback.
