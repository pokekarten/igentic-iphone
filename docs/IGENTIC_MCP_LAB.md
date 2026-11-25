# iGentic iPhone: synthetic MCP lab v0

Status: **working local protocol prototype, not a connected ChatGPT plugin or iPhone controller** (2026-11-22).

## Purpose and boundary

This is a deliberately narrow plugin to prove that a local MCP host can discover and call iGentic-shaped tools without contacting any real iPhone. It is an independent first implementation slice following research PR #379. It does **not** modify the iOS app or claim remote-device transport.

Source: plugins/igentic-iphone-lab/server.py
Packaging: plugins/igentic-iphone-lab/plugin.json and mcp.json

The server is Python standard-library only, stdio-only, **mock-only**. There is no network socket, SSH, MobileCLI, WebDriverAgent, iCTRL, filesystem inventory, Apple account access, app control, screenshot or contact with a physical phone. Device identity is the fixed fictional alias demo-iphone; the only UI content is the synthetic IGENTIC_DEMO_READY marker. It has no selectable real-device backend.

## Exposed tools (all read-only, fictional only)

| Name | Schema / effect |
| --- | --- |
| iphone_list_devices | No arguments; returns one MOCK device, not actual discovery |
| iphone_get_capabilities | Exact device_alias=demo-iphone; returns connected=false, ui_control=false |
| iphone_observe | Exact alias and app=igentic-demo; returns a fixed marker, never captures a screen |

Any input attempting to select another device, app, install action, tap, approve, shell, URL or additional argument is rejected. No iphone_execute_action is exposed. MCP annotations are descriptive; future production permissions must be enforced by the authoritative Swift PolicyEngine/ApprovalManager and a verified gateway.

## Protocol compatibility and local validation

- Modern MCP 2026-07-28: per-request metadata, stateless server/discover, tools/list, tools/call with resultType=complete and structured content.
- Legacy MCP 2025-11-25: initialize + notifications/initialized, tools/list and tools/call.
- Stdio input is bounded to 32 KiB per request; errors do not echo invalid input, and stdout contains only protocol JSON.
- This is a minimal supported subset, not a complete general-purpose MCP SDK.

Run without external dependencies:

    python3 -m unittest discover -s tests -p test_igentic_lab_mcp.py -v
    python3 scripts/validate_repo_structure.py
    python3 plugins/igentic-iphone-lab/server.py

The last command listens on stdin only until EOF; it is not an HTTP service. A local desktop MCP host may launch it using plugins/igentic-iphone-lab/mcp.json and PLUGIN_ROOT expansion. A successful test does not install or register a ChatGPT plugin.

On MacBook Neo, the synthetic contract passed the Python unit suite and an independent real-client integration check using the locally cached @modelcontextprotocol/sdk 1.32.2 over stdio. The SDK completed its legacy handshake, listed exactly three tools and called iphone_observe; the result was explicitly mock. No device was connected or controlled.

## Next engineering gates

1. Establish an actual authorized physical-device identity. Verify which signed MobileCLI/WDA/iCTRL runner is available; do not assume the replaced WDA is usable.
2. Define a narrowly scoped read-only gateway backed by the Swift policy and approval path, with account/device scoping, explicit session lifetime, sanitized observations and a fail-closed disconnect outcome.
3. Demonstrate a ChatGPT-initiated synthetic iGentic app operation over an active, user-authorized Mac/USB session. A mock protocol pass alone cannot substitute for this.
4. Separately test WLAN without USB-C, then optionally a foreground native companion over cellular. Background operation and public distribution eligibility need their own review.

References:
- https://modelcontextprotocol.io/specification/2026-07-28/server/discover
- https://modelcontextprotocol.io/specification/2026-07-28/server/tools
- https://modelcontextprotocol.io/specification/2025-11-25/basic/transports
- https://developers.openai.com/plugins/build/plugins
- https://developers.openai.com/plugins/deploy/desktop-only

OpenAI currently restricts public desktop-only local MCP plugin submission to approved partners. This is a local research artifact and has **not** been installed, reviewed or submitted for publication.
