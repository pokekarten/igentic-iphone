# Reproducible combined iGentic acceptance

The independent draft PRs are stacked: PR #380 supplies the system-facing
App Intent, while PR #384 includes PR #382 (Apple Foundation Models preview)
and PR #381 (untrusted proposal gate). The integration runner combines both
**in a disposable clone**, without checking out or merging either source PR
on the user's working tree.

```bash
# Requires Git, Swift 6 and network access to the repository.
bash scripts/test-integrated-iphone-acceptance.sh

# On compatible macOS, explicitly opt in to one real local model inference.
IGENTIC_RUN_LOCAL_MODEL_PROBE=1 bash scripts/test-integrated-iphone-acceptance.sh

# On Xcode 27.2 with the iPhone Air iOS 27.2 simulator installed:
IGENTIC_RUN_SIGNED_SIMULATOR_TEST=1 bash scripts/test-integrated-iphone-acceptance.sh

# Full integration, including a real local model inference (Mac only):
IGENTIC_RUN_LOCAL_MODEL_PROBE=1 IGENTIC_RUN_SIGNED_SIMULATOR_TEST=1 bash scripts/test-integrated-iphone-acceptance.sh
```

By default the script performs a merge and all Swift unit tests, then
verifies that the model probe **does not run inference without explicit
opt-in**. Live model generation and signed iOS system-level tests are
separately opt-in.

The script clones from the repository's configured `origin`, merges
`feat/read-only-diagnostics-app-intent-20261121` into
`test/opt-in-local-foundation-model-probe-20261121` within its temporary
workspace, runs tests and removes that temporary workspace upon exit. This
is intended only as a development acceptance tool while the PRs are open,
not a permanent release script with frozen branches.

The signed AppIntentsTesting path must **not** set
`CODE_SIGNING_ALLOWED=NO`: the iOS system will reject internal testing on
unsigned builds. A passing macOS system-model probe does not establish
iPhone model eligibility, and a passing simulator App Intent does not
establish a physical-device test.

Every model input in these tests is committed synthetic public text.
No model-output content, personal data, reminder write or cloud AI provider
is needed. A result of `approvalRequired` is **not** a grant of approval.


## iPhone Air simulator UI smoke (independent, no real actions)

The Xcode project now includes `iGenticDiagnosticsUITests` and its test in
`app/iGenticDiagnostics/iGenticDiagnosticsUITests/DiagnosticsUITests.swift`.
The test launches the diagnostic app, handles optional first-run approval policy
confirmation, opens **Explore**, returns to the diagnostic screen, opens the
**synthetic** reminder review, presses **Cancel**, and verifies the sheet closes.
It does **not** issue a real reminder write or authorize a remote agent.

On an authorized Mac with Xcode 27.2 and an available iPhone Air iOS 27.2
simulator, run the test independently of the external model and ARTEMIS:

```sh
xcodebuild -project app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj \
  -scheme iGenticDiagnostics -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone Air,OS=27.2' \
  -derivedDataPath /tmp/igentic-ui-acceptance \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

**2026-11-21 measured evidence:** `TEST SUCCEEDED`, 1/1 UI test, zero
failures in 30.258 seconds on iPhone Air iOS 27.2 / Xcode 27.2 using
a clean isolated checkout of PR #386. The first test attempt exposed
SwiftUI accessibility text-combination differences; assertions now check
stable navigation bars and buttons. This proves this limited UI flow,
not physical iPhone readiness or agent execution.

### Physical acceptance and open PRs — 2026-11-27

The signed iPhoneOS Debug build from `fbba704` was installed as an
update over CoreDevice Wi-Fi on iPhone Air, iOS 27.2.1. Its locally signed
executable SHA-256 was
`ec010c51d16b109dfc1df7e57901778ed86e70f489f1158ec2c16b9dba3ec3c8`.

| Check | Result |
| --- | --- |
| App launch and allowlisted navigation | PASS via CoreDevice process check and fresh app navigation receipt |
| Extended native model diagnostic | PASS via app console receipt, four distinct steps and local report prepared |
| Synthetic OCR and selection | PASS via app receipt, four lines, two excerpts and both fixture facts matched |
| Local task ID and reply exchange | PASS via fresh debug receipt copied from the app container after the launch; cleanup confirmed and normal launch restored |
| Diagnostic journal correlation | UNKNOWN for the debug invocation. A completed checkpoint was read independently, but the invocation does not write that journal |
| Apple Shortcuts, Siri and ChatGPT result return | Physical system invocation and chat return still require verification |

The local reply exchange used fixed synthetic input through the app's
debug entry. It made no external model call and dispatched no system intent.
The previous uncertain physical inputs were not repeated.

The four dependent PRs were refreshed on `fbba704`. At `9a96356`,
#433 passed 14 local dictation policy and workspace tests. At `972c35c`,
#394 passed five Fieldglass plugin tests. At `cd17889`, #379 reproduced
the 107-source appendix byte for byte and its refreshed GitHub
commit-email privacy check passed. At `b6ac831`, #378 passed 34 ARTEMIS
contract tests. These results do not include a combined device build.

On the Mac, GitHub checks cover Swift, CodeQL and the simulator UI.
On the iPhone, the remaining system checks require opening the native
Status Loop in Apple Shortcuts and observing a fresh completed result,
then trying the Siri entry and the separate ChatGPT handoff. For #433,
verify audio interruption and recovery in a signed build containing
that PR, using only synthetic input and authorized test writes.
