---
name: igentic-chatgpt-iphone
description: Prepare privacy-safe handoffs from ChatGPT into the signed iGentic iPhone app. Use when the user asks ChatGPT to check iGentic diagnostics, open local discovery, or prepare a reminder draft on their iPhone. Never treat a generated link as proof of device control.
---

# ChatGPT-first iPhone skill

ChatGPT is the intended conversational interface. The **optional** companion
MCP service offers `iphone_chatgpt_handoff` on the portable read-only endpoint;
this skill also works as accurate guidance when that service is not connected.

- For "open iGentic diagnostics" choose `action="diagnostics"`.
- For "open local discovery" choose `action="discovery"`.
- For "prepare a reminder" choose `action="reminder-draft"`. Do **not**
  include personal reminder text, recipients, due dates or identifiers in URLs.

Only when the read-only `iphone_chatgpt_handoff` MCP tool is actually
available, invoke it with exactly one of the above enumerated actions and
show its `launchUrl`, `actionExecuted:false` and `requiresOwnerTap:true`.
Never invent a tool result or imply a ChatGPT account/device connection.
If it is unavailable, explain that installing the skill alone does not
connect the MCP API; provide setup guidance from CHATGPT_HANDOFF.md in
the sibling `plugins/iphone-connect` source directory, not a fake URL.

The user must intentionally open the returned URL on the iPhone. The
separately signed iGentic app then presents a **second local choice** to
navigate. The `igentic://` URL scheme is *not* authentication, authorization
or a device-pairing token. The current link transports no user data.
The existing reminder workflow handles review, iOS permission and approval
independently, and a preview never counts as a created reminder.

Never call `iphone_execute_action`, `iphone_native_launch_app`, an arbitrary
Shortcut, a browser navigation macro or any other write action as a fallback
for this ChatGPT handoff. Those are different interfaces with different
security scopes. Even the local desktop CoreDevice interface cannot prove
that a ChatGPT mobile user has a live connection. A remote iPhone API must
later be authenticated, paired, foreground-authorized and receipt-verified.

Unsupported tasks (changing iOS settings, arbitrary taps, contacts access,
sending messages, installing apps, running shell commands or controlling
other apps) remain **unsupported**. State this and offer safe manual iOS
steps when useful. Never claim an action succeeded without a trusted receipt.

A local ChatGPT plugin/skill may be available without a remotely connected
MCP server. Local desktop MCP tools cannot automatically run in ChatGPT
on the web or mobile. Do not equate plugin installation with app installation,
MCP server connectivity, an iPhone unlock, or permission approval.
