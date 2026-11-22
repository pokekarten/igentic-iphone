---
name: iphone-connect
description: Inspect a connected physical iPhone and navigate the iGentic Diagnostics demo app using bounded MCP sessions. Use for iPhone diagnostic checks and synthetic discovery navigation, not general personal-app automation.
---

Choose tools for the question being explored. Availability and capabilities can
each be queried without opening an app. Start a session when a device operation
is needed. For example:

- Compare two observations in Diagnostics and report how their markers differ.
- Preview a supported action from the latest observation and stop there.
- If navigation is requested, execute the exact prepared proposal once and
  inspect its receipt. Each refresh requires preparing a new proposal.

Stop the session when the experiment ends.

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
