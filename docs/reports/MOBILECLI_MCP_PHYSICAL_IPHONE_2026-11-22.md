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

## 2026-11-22 follow-up: privacy-safe network discovery gate

The Mac was online for this separate live check, but CoreDevice reported the
registered physical iPhone as paired and **unavailable**; MobileCLI returned an
empty device list. The current cable state could not be independently confirmed,
so these observations are **not** a verified unplugged WLAN test, and they do
not prove or disprove successful later wireless operation.

The repository now has a read-only, identifier-free probe:

    python3 scripts/iphone_wireless_readiness.py

For a fail-closed operator gate:

    python3 scripts/iphone_wireless_readiness.py --require-wireless-candidate

The second command returns exit code 2 unless Xcode sees **one paired physical
iOS device** on localNetwork with an available tunnel **and** MobileCLI discovers
a real iOS device. Independent flags from different phones cannot be combined
into a false positive. Even when it succeeds, this is merely a *discovery candidate*; it is
not a screen-control or same-device identity proof. The command performs no
installs, pairing, relaunch, screenshot, touch, profile edits or network writes.
It uses a preinstalled MobileCLI or a local/offline npm cache, with no package
download. Neither output nor unit fixtures contain real device identifiers.

Validation on MacBook Neo: seven deterministic Python unit tests passed (including mixed-device and unpaired-device false-positive guards);
python3 scripts/validate_repo_structure.py passed. Live probe:
physical_registered=true, physical_paired=true,
physical_network_transport=false, physical_tunnel_available=false,
mobilecli_real_discovered=false, wireless_discovery_candidate=false;
the strict gate returned 2 as designed.

**Next manual device step:** ensure Mac and iPhone can reach each other on a
compatible local network. Use Xcode 27 Device Hub's wireless pairing capability
for iOS 27, unlock the phone, explicitly remove USB-C, and rerun the strict
discovery gate. Then separately authorize a bounded local-only synthetic-app
accessibility/UI test without the cable, including independent post-action
verification. Only after that can we claim WLAN screen control.

Sources:
- Apple Device Hub: https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub
- Mobile MCP WLAN transport caveat: https://github.com/mobile-next/mobile-mcp/issues/483
- MobileCLI device-agent WLAN tunnel caveat: https://github.com/mobile-next/mobilecli/issues/487

## ChatGPT -> Remote Desktop Commander -> Mobile MCP transport smoke

A separate ChatGPT-invoked Mac process started the locally cached Mobile MCP
v1.0.18 server using JSON-RPC over stdio with telemetry disabled. The MCP
initialize handshake succeeded; tools/list exposed 35 tools, including
mobile_list_available_devices; a call to that device-discovery tool returned
successfully at the protocol level. The physical iPhone was **not** connected
at the time. This establishes MCP transport from the ChatGPT-driven Mac
session, **not** control of the device itself. Nothing was installed, tapped,
read from personal apps, or exposed as a public network server.

Next gate remains real physical iPhone discovery over WLAN followed by
permissioned synthetic-app interaction. No local MCP command should be
mistaken for a ChatGPT-hosted iPhone connector or a Mac-free solution.


## 2026-11-22 follow-up: no-WLAN USB-C readiness gate

The owner confirmed that the physical iPhone is **not on Wi-Fi**. This does not
prevent a local, directly cabled USB-C session. It does rule out describing
previous wireless checks as active connectivity, and a cloud/VPN link is not
automatically equivalent to MobileCLI's Xcode/CoreDevice USB device tunnel.

A new read-only preflight complements the separate *wireless* candidate check:

    python3 scripts/iphone_usb_readiness.py

For a strict exit status suitable for an operator's next test:

    python3 scripts/iphone_usb_readiness.py --require-usb-candidate

Exit 2 means **not ready**. All of the following must independently pass:
(i) USB enumeration sees an iPhone or Apple Mobile Device,
(ii) Xcode/CoreDevice sees a **single paired, physical iOS iPhone** on a
wired/USB transport with a live device tunnel, and
(iii) MobileCLI discovers a real iOS device. No identifiers, serials,
private UI, screenshots or signing profiles are printed or committed.
Even when these discovery conditions are met, the script does **not**
claim same-device identity, a functioning screen agent, ChatGPT control,
persistent authorization or permission to perform any UI action.

**Observed disconnected state on the authorized Mac:** USB present=false,
physical iPhone registered=true, paired=true, wired tunnel available=false,
MobileCLI real discovery=false, USB read-only candidate=false. The strict gate
exited 2, as expected. Seven deterministic USB preflight tests and seven
wireless readiness tests passed on the Mac, without a device or network write.

**Physical next step without WLAN:** connect the iPhone with a known
data-capable USB-C cable, unlock it, confirm “Trust This Computer” if
requested, and rerun the strict USB preflight. A read-only status first,
then a separately authorized synthetic-app observation and independent
verification. The script never retries device actions or performs pairing,
installation, tunnel creation, taps, app changes, or background monitoring.


## 2026-11-23: ambiguous phone rejection and actionable offline USB blockers

`python3 scripts/iphone_usb_readiness.py` now includes anonymous, stable
`blockers` codes in its JSON result. For example, when the owner’s iPhone is
not attached and not on Wi-Fi, the observed read-only result includes:

```json
{
  "usb_readonly_candidate": false,
  "physical_ui_control_verified": false,
  "blockers": [
    "iphone_usb_not_detected",
    "wired_coredevice_tunnel_unavailable",
    "mobilecli_physical_iphone_not_discovered"
  ]
}
```

A candidate now additionally requires **exactly one paired, wired, live-tunnel
physical iOS iPhone** in Xcode CoreDevice and **exactly one** real iOS device
from MobileCLI. Two or more matches fail closed with
`multiple_wired_iphones_ambiguous` or `multiple_mobilecli_devices_ambiguous`;
missing counts and malformed device payloads cannot authorize a session.
Only integer *counts* are retained, never device names or identifiers. Errors
from a disconnected USB port, CoreDevice or MobileCLI produce distinct anonymous
codes; strict mode continues to exit **2** until all discovery criteria pass.

This cannot cryptographically prove that the CoreDevice and MobileCLI sightings
refer to the **same physical phone**. It is an intentionally conservative,
**read-only** readiness signal, not screen-control permission or user consent.
A separate operator-confirmed device match and scoped acceptance check remain
mandatory. No persistent session, tap, app installation, screenshot or phone
settings mutation occurs during this check.
