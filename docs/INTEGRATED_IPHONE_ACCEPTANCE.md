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
