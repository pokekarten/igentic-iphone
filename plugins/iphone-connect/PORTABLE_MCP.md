# iGentic portable iPhone plugin: independent clients and native app

ChatGPT is one optional client. The long-term host is a native iPhone agent, not ChatGPT, the Mac, or an MCP server.

## Long-term integration lanes

- Native iPhone app: app-owned features, on-device AI and explicit authorization.
- App Intents, Siri and Shortcuts: local approved actions and automation.
- MCP interface: generic protocol for ChatGPT and other compatible AI clients.
- USB-C and Wi-Fi: existing physical-device development via Xcode/CoreDevice and MobileCLI.
- Mobile data (4G/5G): future authenticated outbound companion-to-service connection.
- Simulator: isolated acceptance tests, not physical-device evidence.

## Implemented today (not an iPhone installation)

From the plugin folder, run these commands:

    npm ci --ignore-scripts
    npm run serve:portable

The portable protocol preview is a Streamable HTTP MCP service at http://127.0.0.1:37865/mcp and has exactly two read-only tools: iphone_connection_report and iphone_get_capabilities.

It is loopback-only, client-neutral and stateless. It DOES NOT read an iPhone, access Mac CoreDevice, operate apps, make writes, or collect credentials. Any device report says no actual device was observed. The original desktop stdio plugin continues separately; no backend is automatically substituted for another.

An external ChatGPT iPhone app, another mobile AI client or an MCP service cannot reach a loopback-only Mac server without an explicitly approved and configured connection. Do NOT expose this unauthenticated preview directly to the Internet. A future hosted gateway must enforce user authentication (e.g. OAuth), access scoping, rate limits, signed proposals, replay prevention and verified outcomes.

## Separate, future iPhone installation

The iOS companion itself must be signed and installed on the phone. It will expose only user-approved, app-owned operations through App Intents/Shortcuts. An MCP client or VPN alone cannot run a general iOS shell or change unrestricted device settings.

Until mobile setup, app installation, app permissions and physical cellular tests have succeeded, report the iPhone runtime as NOT VERIFIED. Background execution may be suspended by iOS; measure the real lifecycle before claiming continuous connectivity.

For ChatGPT-specific account/plugin installation, follow current ChatGPT app and custom MCP connection instructions if the user's plan permits; do not assume installation or produce a fake service URL. ChatGPT is not mandatory for iGentic.

## Acceptance evidence to collect separately

1. Generic Streamable HTTP MCP client loads exactly two safe read-only tools.
2. Desktop stdio diagnostics, policy and synthetic tests continue passing.
3. Native App Intent runs on a physical phone with user approval.
4. Cellular auth and delivery work when USB and Wi-Fi are disconnected.
5. Each AI client (ChatGPT or other) has its own actually verified installation and invocation.
