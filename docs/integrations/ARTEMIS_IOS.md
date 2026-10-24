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

Set a model provider in the upstream configuration as documented by ARTEMIS. Never commit credentials, screenshots, phone identifiers, project signing data, or private content. A remote provider can receive screenshots/UI information. Prefer a trusted local model endpoint and keep its listener limited to loopback; the wrapper does **not** verify a provider is local.

For the complete ARTEMIS CLI, daemon, console, Python SDK, and video/replay capabilities, follow the pinned upstream `docs/ios.md`. Those capabilities remain on the Mac host, not embedded into the iGentic iPhone app.

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

`--profile pro` selects ARTEMIS's more thorough agent workflow. To use an explicitly selected simulator, pass its UDID. ARTEMIS supports `--platform ios`; omitting it silently selects Android. The iGentic wrapper always passes it.

For a physical iPhone, use an explicit UDID and `--physical`; ensure the device is yours and you have approved it. The upstream flow requires a signed iOS app, trust pairing, Developer Mode, Xcode consent, and a signed WebDriverAgent runner. Follow pinned `docs/ios.md` for setup and verify the WDA endpoint belongs to the intended device. Never use another person's phone without authorization.

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
