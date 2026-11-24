# iGentic Diagnostics App Wrapper

**Target device:** iOS **27.0+** only. Build and unsigned simulator tests require **Xcode 27**; the simulator smoke script refuses iOS 26 and older runtimes. A source/Snapshot test on Linux is not evidence of a signed installation on physical iPhone hardware.

This directory contains the smallest installable iOS application wrapper for the existing `iGenticApp` Swift package product.

## What it does

- Defines the `iGenticDiagnostics` iOS application target.
- Imports the local package product from `../../ios`.
- Presents `DiagnosticView` as the root SwiftUI view.
- Builds for the iOS Simulator without code signing in GitHub Actions.
- Installs the built app into an available iPhone simulator.
- Launches the app, captures a simulator screenshot, terminates it, and verifies a clean relaunch.

## What it does not do

- The app accepts exactly two optional first-party diagnostic launch actions
  (open-diagnostics and open-discovery) plus a UUID nonce. The corresponding
  SwiftUI view writes a fixed receipt only after appearing. There is no
  arbitrary device command, external listener or user-data disclosure.
- A separate, **optional**, manual cellular readiness screen can send exactly one
  fixed HMAC-signed HTTPS request to the owner's configured server after
  explicit local Keychain pairing and button tap. It does not receive remote
  commands, write user data, guarantee background execution or control iOS
  settings. No endpoint/secret ships in the app; there is no network request
  during ordinary app launch.
- No third-party mobile runtime or model provider.
- No personal-data persistence. A fixed, nonpersonal iGentic bridge receipt is atomically replaced.
- One **read-only, fixed-output App Intent** and discoverable App Shortcuts are included; no live diagnostic data, user data, model-driven calls, or privileged tool execution.
- No model calls or model weights.
- No Apple account, team identifier, certificate, provisioning profile or device identifier is stored in the repository.
- No physical-device validation is claimed.

## Local owner steps

The committed bundle identifier `org.example.iGenticDiagnostics` is a non-production placeholder. Before a physical-device run, replace it locally with an identifier controlled by the owner and select the Apple Developer Team under Signing & Capabilities.

Do not commit account identifiers, signing certificates or provisioning-profile contents.

## Repository validation

Package validation remains:

```bash
python3 scripts/validate_repo_structure.py
cd ios && swift test
cd ios && swift build
```

The wrapper has an additional unsigned simulator build:

```bash
xcodebuild \
  -project app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj \
  -scheme iGenticDiagnostics \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/iGenticDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The reusable launch smoke test then runs with:

```bash
APP_PATH=/tmp/iGenticDerivedData/Build/Products/Debug-iphonesimulator/iGenticDiagnostics.app \
BUNDLE_IDENTIFIER=org.example.iGenticDiagnostics \
bash scripts/smoke-ios-simulator.sh
```

A successful simulator smoke test proves that the built app can be installed, launched, screenshotted, terminated, and relaunched in an iOS Simulator. It does not prove physical-device signing, installation, device-specific behavior, accessibility quality, or performance.

## Follow-up

After repository validation succeeds, the remaining steps are local owner actions: choose the production bundle identifier, select the Apple Developer Team, configure signing and execute the committed physical-device checklist.

## iOS 27 system App Intent integration test

The separate `iGenticDiagnosticsUITests` target uses Apple's `AppIntentsTesting`
from an **out-of-process UI test**. It runs
`iGenticReadOnlyDiagnosticsIntent` through the same App Intents system path
used by Shortcuts/Siri and asserts that the exact privacy-safe static response
is returned on **three consecutive system-dispatched invocations**. This is stronger than inspecting `Metadata.appintents` or launching
the app, but it does **not** demonstrate a spoken Siri trigger or physical-device
behavior.

**Important:** Unlike the unsigned build/launch smoke test above, this
system-level test **requires code signing to be enabled** for both the app and
the UI test runner. Do not copy `CODE_SIGNING_ALLOWED=NO` into its command:
doing so yielded `AppIntentsServicesSecurityErrorDomain Code=803` ("Unable
to run internal tests on a Customer build") on the iOS 27.2 simulator.
With default local signing, the same test passes. Per Apple's App Intents
Testing documentation, the app and runner must have the same signing team
when team signing applies.

```bash
xcodebuild \
  -project app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj \
  -scheme iGenticDiagnostics \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone Air,OS=27.2' \
  -derivedDataPath /tmp/igentic-appintents-testing \
  -only-testing:iGenticDiagnosticsUITests/iGenticAppIntentsTests \
  test
```

The Intent itself now checks the shared `AgentCore.PolicyEngine` with a
fixed `localOnly` / `publicDefault` / `read` / `localDevice`
policy request. It fails closed if policy denies the request or asks for
approval; it does not create a second, Shortcut-specific authorization
path. `ShortcutPolicyBoundaryTests` verifies read-only allow, external
provider denial, and mandatory approval for local writes. The signed
out-of-process system test checks three identical responses after
this guard, rather than bypassing the guard in a direct function call.

The production iGentic app retains its existing iOS 17 deployment target.
The separate `AppIntentsTesting` test bundle requires iOS 27+. Use an
installed matching simulator runtime; do not enable actual reminder writes.
Official guide: <https://developer.apple.com/documentation/appintentstesting/testing-your-app-intents-code>.

## iGentic agent loop: native Shortcuts and manual AI handoff (draft)

The iOS 27 app target now registers these **app-owned** App Intents:

- **Read iGentic iPhone Status:** reads battery percentage (if available),
  Low Power Mode and the system's iOS version locally, after a policy check.
  The returned string expressly says that ChatGPT connectivity is not tested.
  It does not enumerate other apps, contacts, files, unique device identifiers,
  or external accounts.
- **Prepare iGentic Agent Task:** takes a bounded text parameter from the
  Shortcuts system and returns a *read-only, local* classification of which
  iGentic-owned view can handle the task. It never executes the task, creates
  a reminder, invokes an arbitrary Shortcut or returns the original input.
- **Check iGentic Diagnostics:** existing fixed synthetic diagnostic reply,
  unchanged.

Example *manual* on-device workflow:

1. Install the newly signed build with owner-approved development signing.
   In Apple's **Shortcuts** app, locate the iGentic actions by their titles.
2. Add **Read iGentic iPhone Status** to a Shortcut. Feed its output into
   another user-selected action or show it locally.
3. If a compatible assistant is installed and supports an appropriate
   Shortcuts action, pass the result to it **only with the owner's consent**.
   That assistant may return a suggested task. Feed that task into
   **Prepare iGentic Agent Task**, which returns only a proposal.
4. Open the iGentic Agent screen to review the task and use an explicit
   Share Sheet if the owner wants to hand the text to ChatGPT or another
   supported app. The selected app must support that share type.
5. For any reminder creation, use the existing dedicated iGentic approval UI
   and EventKit permission checks. A returned model suggestion is not approval.

There is **no guaranteed ChatGPT Shortcuts action, automatic callback,
ChatGPT consumer-app API, remote iPhone plugin link, or always-on background
execution** implied by these local App Intents. The private hosted Sites
plugin remains an independent, manual-link-only workflow. Full architecture
and the verified vs proposed capability boundaries are documented in
[the native agent-loop design](../../docs/architecture/IGENTIC_CHATGPT_IPHONE_AGENT_LOOP.md).

## iGentic → Apple Shortcuts → ChatGPT → iGentic (no API)

A bounded, native, owner-controlled round trip is implemented using
**iGentic KI-Auftrag starten**, **iGentic KI-Auftrags-ID lesen**,
**iGentic KI-Prompt lesen**, and **iGentic KI-Antwort übernehmen**.
The receive action requires the matching local task ID from a separate
Shortcuts variable, preventing stale responses from being assigned to
newly started tasks. The app may launch the fixed custom
shortcut **iGentic KI Loop** via Apple's supported URL scheme, with *no task
text in the URL*. The owner configures **Use Model → Extension Model (ChatGPT)**
as the middle step. The returned model response is saved and displayed in
**iGentic Agent → KI-Antwort prüfen** and can be deleted locally. It is never
executed as an iOS action.

This does not grant remote-device control, create a hosted ChatGPT plugin,
require an OpenAI API key or silently configure the user's Shortcuts. The
new signed iGentic build and the user-created Shortcut are both needed on the
phone; simulator tests do not prove the ChatGPT extension is available.
Follow the [five-step Shortcuts setup and Siri variant](../../docs/architecture/IGENTIC_SHORTCUTS_CHATGPT_NO_API_LOOP.md).

On 2026-11-23, the owner-signed build was installed on the real paired iPhone
Air via Wi-Fi, and an app-owned, DEBUG-only synthetic Start → Receive →
Store → Clear acceptance returned a fresh verified CoreDevice receipt. This
proves the local app storage path, **not** a real ChatGPT/Apple Shortcuts model
invocation. No OpenAI API, credential or user-data write was used.


### In-app setup guide

Under **iGentic Agent → ChatGPT-Loop einrichten**, the installed app now
shows the canonical five-step Shortcuts setup, the exact local workflow name,
a link opening the blank Apple Shortcuts editor, a fixed run link and the
current *local task* state. It does **not** claim the user's Shortcut is
installed or the ChatGPT extension is enabled. The old developer two-turn
loop is labelled separately to avoid competing launch buttons.


Advanced workflow: **iGentic KI-Auftragspaket lesen** returns a structured
JSON ticket (schema, taskId, prompt), while **iGentic KI-Auftrag starten**
creates a task and returns such a ticket. For a beginner setup, use the
separate iGentic KI-Auftrags-ID lesen and iGentic KI-Prompt lesen actions.
Only the plain prompt may be forwarded to an external model.
