# First-party iGentic CoreDevice adapter

This is an independent iGentic-owned transport and view-receipt protocol. It uses Apple Xcode CoreDevice only for Mac-to-physical-iPhone transport; it does not call MobileCLI, iph or a third-party iPhone agent.

## Implemented functions

- Discover the configured, paired *physical* iPhone through CoreDevice and report whether the current path is USB-C or local-network Wi-Fi.
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

38/38 Mac Node tests passed including the first-party session/proposal/receipt flow. The unsigned iOS simulator build succeeded. A real iOS 27.2 simulator independently observed both view-appearance receipts, for diagnostics and discovery, with the correct fresh nonce and fixed action. The Xcode-signed physical-device build for the owner's bundle was blocked by a missing local provisioning profile. No Apple account, certificate or provisioning settings were changed.

CoreDevice's app-container copy operation also failed when attempted against that simulator; simulator tests verified the app's file through Apple's simctl app-container path instead. The physical iPhone receipt retrieval and full WLAN-only MCP smoke therefore still require an owner-provisioned app version plus a fresh physical acceptance test. The previously validated MobileCLI USB-C end-to-end test remains separate evidence.

Do not describe the new first-party path as physical WLAN-only E2E until a real device reads the app-owned receipt and verifies the action.