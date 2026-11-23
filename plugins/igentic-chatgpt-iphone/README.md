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
