# First-party iGentic CoreDevice adapter

This is an independent iGentic-owned transport and view-receipt protocol. It uses Apple Xcode CoreDevice only for Mac-to-physical-iPhone transport; it does not call MobileCLI, iph or a third-party iPhone agent.

## Implemented functions

- Discover the configured, paired *physical* iPhone through CoreDevice and report whether the current path is USB-C or local-network Wi-Fi.
- Query only the allowed iGentic app's installation and running process through a first-party read-only MCP tool. Exact bundle and executable path are checked locally; only coarse booleans leave the Mac.
- Request CoreDevice device details to reopen an on-demand, paired tunnel. A tunnel alone is not a successful app action.
- Launch exactly the installed iGentic Diagnostics bundle with one allowlisted action: open-diagnostics or open-discovery.
- Accept a fresh UUID nonce per launch and require an app-owned view-appearance receipt with that same nonce.
- Copy only the fixed receipt from the iGentic app container. Expose only predetermined public markers, never a raw file, arbitrary UI text or personal data.
- Retain the existing bounded session/lease, one-time proposal, policy helper, receipts and audit semantics, without depending on an external mobile automation binary.
- Permit an explicitly opted-in legacy MobileCLI driver as a separate option, not a default or dependency.
- Keep App Intents/Shortcuts, offline local models and future authenticated cellular companions separate.

## Important boundaries

Only two views in our *own* app are supported. This adapter cannot type, tap arbitrary coordinates, inspect other apps, unlock the phone or alter iOS settings. Its fixed receipt proves that an iGentic view appeared during the current launch; it is not a continuous independent screen-state monitor. A changed view outside the bridge is not detected by the receipt protocol. Execution must remain non-sensitive and limited to own-app navigation.

Wi-Fi requires the real iPhone, Xcode pairing and an active CoreDevice localNetwork tunnel; a remembered pairing is insufficient. USB-C remains independent. There is no external network listener, token or cloud account.

The app writes one overwritten file, Documents/igentic-plugin-receipt.json, with exactly: schema 1, action, nonce, view and status observed. No personal information. The Mac reads precisely that file through Apple's appDataContainer domain, rejecting malformed, replayed and extra fields.

## Run

Install and provision an iOS app version containing the native bridge through the owner's Apple signing configuration. Xcode and physical-device provisioning are Apple prerequisites; iGentic does not bypass them.

From plugins/iphone-connect run:

    node scripts/setup.mjs
    npm run doctor
    npm run smoke

The default physical driver is coredevice-native. To invoke the independently retained legacy driver *only when explicitly installed*:

    IGENTIC_IPHONE_DRIVER=mobilecli npm run smoke

Fixture mode remains synthetic and never counts as hardware proof:

    IGENTIC_IPHONE_BACKEND=fixture npm run smoke

## Validation and outstanding acceptance

42/42 Mac Node tests passed including first-party session/proposal/receipt and exact own-app launch/process checks. The unsigned iOS simulator build succeeded. A real iOS 27.2 simulator independently observed both view-appearance receipts, for diagnostics and discovery, with the correct fresh nonce and fixed action. The Xcode-signed physical-device build for the owner's bundle was blocked by a missing local provisioning profile. No Apple account, certificate or provisioning settings were changed.

CoreDevice's app-container copy operation also failed when attempted against that simulator; simulator tests verified the app's file through Apple's simctl app-container path instead. The first-party read-only own-app status tool was separately tested on the
real paired physical iPhone over WLAN: it returned installed=true,
processRunning=true and connectionPath=network-coredevice using Apple
CoreDevice only. This does not prove native UI navigation.

The physical iPhone receipt retrieval and full WLAN-only MCP smoke therefore still require an owner-provisioned app version plus a fresh physical acceptance test. The previously validated MobileCLI USB-C end-to-end test remains separate evidence.

Do not describe the new first-party path as physical WLAN-only E2E until a real device reads the app-owned receipt and verifies the action.

## Physical transport-specific own-app acceptance

Run the local first-party MCP acceptance script from the plugin directory:

    npm run smoke:usb      # requires physical USB-C and CoreDevice tunnel
    npm run smoke:wifi     # requires physical local-network tunnel, no USB-C

The test requires an actual paired physical route, the allowlisted iGentic
app installed, an exclusive policy-controlled session, a safe own-app
launch, and an independent CoreDevice app-process confirmation. It returns
only sanitized transport and fixed booleans. This is useful with the older
signed app that does not yet support nonce receipts.

On 2026-11-23, the physical iPhone Air was actually present in macOS's
IOUSB tree and CoreDevice reported a currently active usb-coredevice tunnel.
Running npm run smoke:usb on that device returned installed=true,
launchStatus=own-app-process-observed and
independentProcessVerification=true with privateContentReturned=false,
exit code 0, and no residual iGentic device lease. The corresponding
npm run smoke:wifi correctly failed with the USB cable still attached.
An explicit synthetic fixture cannot pass physical USB acceptance.

A successful result is **not** evidence of foreground or arbitrary UI
navigation. The stronger receipt-based full app navigation still requires a
provisioned and installed new app build and additional hardware acceptance.

### Return a completed Shortcuts task to the MCP client

Retain the taskId from the iGentic status-loop start intent. After the
advance intent completes the task, call `iphone_shortcut_result` with that
taskId through the local CoreDevice MCP server. The server reads one fixed
journal in the paired app container and returns the matching ID and finished
stage. The output omits the status observation. The journal contains only
the latest task, so a subsequent task may replace the prior result.
This read reports historical local completion, without initiating another read
of phone status. The hosted handoff Site has no access to this Mac transport.

Hardware acceptance on 24 November 2026 verified the discovery action and its
receipt through the 16-tool local MCP server. A freshly generated unissued ID
returned a backend error. Successful retrieval of a completed personal
Shortcut ticket on hardware remains open.
