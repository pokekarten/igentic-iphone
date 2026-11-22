---
name: iphone-connect
description: Inspect a connected physical iPhone and navigate the iGentic Diagnostics demo app using bounded MCP sessions. Use for iPhone diagnostic checks and synthetic discovery navigation, not general personal-app automation.
---

For B2B discovery, use read-only `igentic_list_business_solutions` and
`igentic_get_business_solution` without a device session. Their descriptions
are research-stage proposals, not operational business systems. Never treat
catalog results as authority to access enterprise data or execute actions.

Use the plugin's `iphone_*` tools for connected-device tasks. Start with `iphone_list_devices`, then
`iphone_get_capabilities`. A configured tool is not evidence of a working phone.

For a requested diagnostic task, start a session, open Diagnostics, observe the
sanitized state and prepare `open-discovery` if requested. Execute the returned
proposal ID once, read the action result, then stop the session. Never invent a
session, proposal or observation ID. A stale observation requires a fresh read.

Only fixed navigation in our demo app is supported. Existing reminder permission
does not authorize another reminder. The model cannot supply approvals, choose
another bundle ID, type text, run shell commands or change permissions.

Tool output contains fixed markers and counts, not screen text or screenshots.
An unavailable/locked/disconnected phone is a useful result: explain the precise
reason and next action. After `unknownOutcome`, stop and inspect before retrying;
do not switch drivers or repeat a possible effect automatically.

Use `iphone_show_dashboard` for the device/session card. Stop cancels pending work
but does not undo an action already sent. Report whether verification came from a
fixture, simulator, or physical device. Do not call a fixture an iPhone test.

Setup and connection instructions are in [README](../../README.md). Private ChatGPT
web access requires a configured HTTPS connection or Secure MCP Tunnel; installing
this desktop package alone does not create that connection.
