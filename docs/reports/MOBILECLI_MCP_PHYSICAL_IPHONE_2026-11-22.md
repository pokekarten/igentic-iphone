# Physical iPhone Air: MobileCLI and Mobile-MCP smoke test (2026-11-22)

**Status: physical USB smoke PASS for the bounded actions below; untethered WLAN NOT TESTED.**

This is an engineering test record, not certification of unrestricted iOS access. No personal-device identifier, provisioning UUID, signing identity, screenshot or raw private UI tree is stored here.

## Environment and provenance

- Device: physical iPhone Air, iOS 27.2.1; Developer Mode enabled.
- Host: MacBook Neo, Xcode 27.2 and Node.js 26.10.0; USB-C connection.
- Tools: `mobilecli@1.0.24`, `@mobilenext/mobile-mcp@1.0.18`, device agent `0.0.38`.
- The Mobile-MCP process was exercised via JSON-RPC 2.0 over **stdio**, not by assuming that a registered MCP server was functional.
- An iOS 27.2 iPhone Air **simulator** had already passed launch, screenshot, accessibility tree, Home and tap→Safari tests. The physical results below are independent.

## Free-development-account slot decision

The physical device reached Apple's three-app free-development-profile limit with these signed development apps:
1. iGentic diagnostic app.
2. iCTRL UITests runner.
3. WebDriverAgent runner.

A signed MobileCLI agent could initially **not** be installed; iOS returned `ApplicationVerificationFailed` and enumerated the three existing developer apps.

The existing **iCTRL runner was retained deliberately**: its upstream project describes an authenticated, paired device-local control service, potentially useful for future Mac-independent operation. That capability has **not** been verified on this device.

To preserve reversibility, a replacement WebDriverAgent runner was compiled from upstream `appium/WebDriverAgent` tag `v16.15.3` (source commit prefix `02cb92f`). Xcode `build-for-testing` passed; the generated application bundle ID matched the installed WDA runner, and `codesign --verify --strict --deep` passed. The signed runner, `.xctestrun` and local recovery instructions were copied to `~/Developer/iphone-runner-recovery-20261122/` (approximately 1.9 MB). **Restoring that archive onto the device has not been re-tested.** Free-account profiles expire and may require rebuilding and signing after renewal.

The existing WDA runner was then uninstalled to free the slot; this also removed its on-device app container. The user-facing iGentic app and iCTRL runner were left installed. `mobilecli agent install --provisioning-profile ...` subsequently returned `Agent installed successfully`; the device now reports agent version `0.0.38`.

This temporarily trades away the PhoneUse/WDA pathway; do not claim WDA remains available until it is reinstalled and launched.

## Verified physical-device results

| Check | Result | Evidence |
|---|---|---|
| Xcode/CoreDevice detection | PASS | Physical device connected and Developer Mode enabled |
| MobileCLI device listing | PASS | Physical iOS device online |
| Mobile-MCP `mobile_list_available_devices` | PASS | Physical device listed |
| Agent installed, signed | PASS | `mobilecli agent status` shows 0.0.38 |
| First MobileCLI screenshot attempt | **TIMEOUT** | Timed out waiting for DeviceKit agent to become ready |
| Subsequent MobileCLI screenshot | PASS | 1260 × 2736 PNG; temporary local output removed |
| MobileCLI `snapshot` | PASS | 30 iGentic diagnostic accessibility element lines |
| MobileCLI `io button HOME` | PASS | SpringBoard independently confirmed as foreground |
| MobileCLI `io tap` | PASS | Tapped synthetic `Open local discovery` control; next UI tree showed `Explore`, `Local discovery` and a local search field |
| Mobile-MCP JSON-RPC initialize | PASS | Server identified itself as `mobile-mcp` |
| Mobile-MCP `mobile_list_elements_on_screen` | PASS | 40 element references returned |
| Mobile-MCP `mobile_take_screenshot` | PASS | JPEG image returned to local test process; raw image not published |
| Mobile-MCP `mobile_press_button HOME` | PASS | MCP reported successful hardware-navigation command |
| Mac-disconnected / Wi-Fi MobileCLI and MCP operation | **NOT TESTED** | Device remained physically attached during the physical smoke tests |

For the UI tap, the target was the iGentic diagnostics app's **local generated-index browser**. It uses bundled sample content; no contacts, messages, real reminders, provider calls or purchasing actions were used. User-visible test content and screenshots were **not** committed. The test did not require permission to write personal data.

## Reproduction and safety

Use explicit device selection in a private terminal session; never hardcode a UDID or expose a signing profile in Git:

```bash
npm exec --yes --package=mobilecli@1.0.24 -- mobilecli devices
npm exec --yes --package=mobilecli@1.0.24 -- mobilecli agent status --device "$DEVICE_ID"
npm exec --yes --package=mobilecli@1.0.24 -- mobilecli apps foreground --device "$DEVICE_ID"
```

For read-only UI validation, launch a known synthetic lab app first and capture screenshots or accessibility snapshots only locally. Avoid logging their content. For touch input, require an explicit safe target and verify the changed foreground/UI state; do not automatically tap unrelated personal apps. The first cold start may return a DeviceKit readiness timeout: allow a **bounded** retry after checking that the runner process is alive, rather than an unbounded retry loop.

## Open acceptance criteria

1. Physically unplug USB-C; verify `xcdevice` and **both** MobileCLI/MCP discover the real device via network (do not extrapolate from Xcode network support).
2. Over WLAN, repeat an opt-in screenshot, sanitized accessibility tree, Home command and one synthetic-app tap.
3. Verify reliability across a device lock/wake, reconnection and reboot. Test developer disk image re-mounting, tunnel lifetime and certificate renewal.
4. Review agent authorization, per-action approval, restricted network binding and revocation. Pairing alone must not authorize consequential actions.
5. If MobileCLI is removed later, restore and test WebDriverAgent from the local recovery archive, **after** making space under the free developer-app limit.

Upstream: [MobileCLI](https://github.com/mobile-next/mobilecli), [Mobile-MCP](https://github.com/mobile-next/mobile-mcp), [iCTRL](https://github.com/OpenMinis/iCTRL), [WebDriverAgent](https://github.com/appium/WebDriverAgent).
