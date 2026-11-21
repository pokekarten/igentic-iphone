# ARTEMIS iOS host integration (experimental)

This integration brings **all upstream ARTEMIS iOS host capabilities** into reach of the iGentic research workflow **without vendoring or silently running** the unmerged upstream PR. The integration is optional and does not change the Swift `AgentKernel`, `PolicyEngine`, or production app permissions.

- Upstream: https://github.com/google/artemis/pull/175 (open at integration time).
- Contributor branch: `banggaoo/artemis:feat/ios-support`.
- **Pinned SHA:** `31df538d3e8a0ff11e735a4e2c04e6e0936fc68f`.
- License: ARTEMIS is Apache-2.0; the external source retains upstream copyright and license.
- Prerequisites: macOS, **Xcode 27+**, Python/uv, iOS simulator or consented physical iPhone.
- iGentic target: `app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj`.

## Setup (review first; no automatic model/provider access)

From the iGentic repository root:

```bash
python3 scripts/igentic_artemis_ios.py doctor
python3 scripts/igentic_artemis_ios.py fetch
python3 scripts/igentic_artemis_ios.py doctor
```

`fetch` creates an isolated checkout in `~/.cache/igentic/artemis-ios-pr175` and verifies the exact head SHA. It does **not** execute or install unreviewed ARTEMIS code. Inspect that checkout before running any setup. The script refuses to reuse a checkout if its commit differs.

To install dependencies **after reviewing the upstream source**:

```bash
cd ~/.cache/igentic/artemis-ios-pr175
uv sync --dev
bash scripts/setup_ios_env.sh
```

The opt-in `run` command uses `uv run --frozen --no-sync --offline` to prevent
**implicit** dependency downloads, environment synchronization, or lockfile
updates when starting a device test. The host runner also sets a 10-minute
maximum for a synthetic test. Timeout, Ctrl+C, SystemExit or an unexpected
host-runner error triggers SIGTERM for the agent's subprocess group, escalating
to SIGKILL after 5 seconds if it does not exit. This is a bounded host-side
process lifetime, **not** an iOS app sandbox, model token budget, or guarantee
that an externally launched service cannot outlive the runner. Prepare/review the local Python environment
explicitly with `uv sync --dev` beforehand. These flags govern only **uv package
management**, not ARTEMIS model-provider traffic: a configured external model
may still receive screenshots/UI information after the explicit acknowledgment.

Configure the model provider before running a device test. The pinned upstream
`config/artemis.jsonc` is **tracked source**, so editing it in-place makes the
checkout fail `require_pinned`. For a custom model configuration, keep a
separate, privately stored copy outside the Git checkout and point the pinned
ARTEMIS configuration resolver to it:

```bash
mkdir -p ~/.config/igentic
cp config/artemis.jsonc ~/.config/igentic/artemis.jsonc
# Review/edit only this external copy, then set for the test session:
export ARTEMIS_ARTEMIS_JSONC="$HOME/.config/igentic/artemis.jsonc"
```

The `ARTEMIS_ARTEMIS_JSONC` override is supported by the pinned upstream
`get_config_path("artemis.jsonc")` resolver. Keep credentials in a private
`.env` file (ignored by upstream Git) or protected environment variables, not
in the external config or the public iGentic repo. Never commit credentials,
screenshots, phone identifiers, project signing data, or private content.
A remote provider can receive screenshots/UI information. Prefer a trusted local
model endpoint and keep its listener limited to loopback; the wrapper does
**not** verify a provider is local.

For the complete ARTEMIS CLI, daemon, console, Python SDK, and video/replay capabilities, follow the pinned upstream [the pinned ARTEMIS iOS guide](https://github.com/banggaoo/artemis/blob/31df538d3e8a0ff11e735a4e2c04e6e0936fc68f/docs/ios.md). Those capabilities remain on the Mac host, not embedded into the iGentic iPhone app.

## Run a synthetic iGentic UI test

Build the unsigned `iGenticDiagnostics` app for a simulator following `app/iGenticDiagnostics/README.md`. Preview the fixed diagnostic test first:

```bash
python3 scripts/igentic_artemis_ios.py plan
```

When macOS/Xcode permissions, model configuration, and ARTEMIS source have been reviewed, explicitly execute:

```bash
python3 scripts/igentic_artemis_ios.py run \
  --execute --acknowledge-model-io \
  --device booted \
  --app-path /absolute/path/iGenticDiagnostics.app
```

For simulator runs, `--app-path` is optional only when the diagnostic app is already
installed. When supplied, the host wrapper validates the app's `Info.plist`
bundle identifier `org.example.iGenticDiagnostics` before invoking ARTEMIS.
For physical runs, both a signed diagnostic `.app` and its locally configured
bundle identifier are mandatory. An unrelated app or mismatching identifier
is rejected. This is an **identity preflight only**: it does not verify code
signing, prove app ownership, prevent later app switches, or keep screenshots private.

`--profile pro` selects ARTEMIS's more thorough agent workflow. To use an explicitly selected simulator, pass its UDID. ARTEMIS supports `--platform ios`; omitting it silently selects Android. The iGentic wrapper always passes it.

For a physical iPhone, use an explicit UDID and `--physical`; ensure the device
is yours and you have approved it. The simulator app's committed bundle ID is a
placeholder, but the [Diagnostics wrapper](../../app/iGenticDiagnostics/README.md)
requires changing that identifier locally before physical-device signing.
The adapter supports this owner-controlled identifier without storing it in Git:

```bash
# Set these three values locally; never commit or publish your device ID.
export IGENTIC_TEST_DEVICE="<authorized-physical-device-udid>"
export IGENTIC_TEST_APP="<absolute-path-to-signed-iGenticDiagnostics.app>"
export IGENTIC_TEST_BUNDLE="<owner-configured-signed-bundle-identifier>"

python3 scripts/igentic_artemis_ios.py plan \
  --physical --device "$IGENTIC_TEST_DEVICE" \
  --app-path "$IGENTIC_TEST_APP" --expected-bundle-id "$IGENTIC_TEST_BUNDLE"

# Only after explicit permission and on a disposable/synthetic test device:
python3 scripts/igentic_artemis_ios.py run \
  --execute --acknowledge-model-io --physical \
  --device "$IGENTIC_TEST_DEVICE" \
  --app-path "$IGENTIC_TEST_APP" --expected-bundle-id "$IGENTIC_TEST_BUNDLE"
```

The physical runner rejects missing `--app-path` and the public simulator
placeholder as `--expected-bundle-id`. It only checks the matching `Info.plist`
identifier, **not** Apple signing, ownership, or runtime app confinement.
The upstream flow additionally requires trust pairing, Developer Mode, Xcode
consent, and a signed WebDriverAgent runner. Follow
[the pinned ARTEMIS iOS guide](https://github.com/banggaoo/artemis/blob/31df538d3e8a0ff11e735a4e2c04e6e0936fc68f/docs/ios.md)
for setup; verify the WDA endpoint belongs to the intended device.

This is **test automation**, not a way around the iOS sandbox or permission prompts. The prompt is advisory; ARTEMIS's UI tool may be capable of opening other apps. Use a dedicated simulator with synthetic data only. Do not use a production iPhone containing private content until we have reviewed and implemented a stricter host-to-iGentic action-policy binding.

## Codex MCP (optional; host-side only)

```bash
python3 scripts/igentic_artemis_ios.py mcp-config
```

This prints a candidate `~/.codex/config.toml` configuration and **does not install it**. Verify that the checkout contains the Python environment and user-approved provider configuration before manually applying it. Connecting an external MCP server grants it the permissions of its host process.

## Architecture and trust boundaries

```text
iGentic Swift AgentKernel / PolicyEngine (unchanged, authoritative in iGentic)
         |
         | planned typed, separately reviewed approval bridge; NOT live yet
         v
Mac operator/test runner (this opt-in script)
         |
         | exact pinned upstream ARTEMIS PR #175
         v
ARTEMIS Python agents + iOS driver
         |                         |
         v                         v
Xcode MCP + simctl (simulator)     devicectl + WDA (owned physical device)
         |
         v
Synthetic iGentic Diagnostics UI + test evidence
```

**The Swift PolicyEngine is not yet wired to ARTEMIS.** Do not interpret command-line flags as cryptographic authorization or claim the test runner enforces per-app confinement. This host adapter is an incremental integration and must not be enabled as an autonomous production execution tool until a typed request contract, approval receipts, redaction, and end-to-end verification are implemented.

## Validation

Host-independent tests:

```bash
python3 -m unittest discover -s tests -p 'test_igentic_artemis_ios.py' -v
python3 scripts/igentic_artemis_ios.py plan
python3 scripts/validate_repo_structure.py
```

macOS-specific acceptance: confirm `doctor`, reviewed upstream checkout, `uv sync`, Xcode consent, a signed/provisioned device when applicable, iGentic app build, simulator navigation, screenshots, and clean termination. Log only synthetic observations. GitHub Linux CI is not evidence that these device steps passed.

## GitHub admission prerequisites

At integration time: [#286](https://github.com/pokekarten/igentic-iphone/issues/286) requires owner-side main-branch status-check enforcement and [#287](https://github.com/pokekarten/igentic-iphone/issues/287) is the follow-on public-content admission gate. This feature belongs in **one Draft PR** until independent security review and platform acceptance; do not merge or enable real reminder saves as a side effect.

## Updating the upstream pin

Treat upstream PR changes as a new code review: inspect the diff, verify its license and tests, change the SHA intentionally, adjust regression tests and documentation, validate against a new simulator environment, and record the new exact commit identity. Never fetch `main` or run an unpinned branch implicitly.
