# ChatGPT iPhone plugin implementation evidence — 2026-11-22

## Delivered scope

Implemented `plugins/iphone-connect` on a dedicated worktree/branch from canonical
`main` at `0bb24b750d90da9f810af9648aae5fc2058a7069`. Existing dirty worktrees,
research PR #379, reminder PR #390 and the iOS 27 baseline PR #389 were preserved.
No predecessor was merged. The plugin is a local desktop developer package,
version 0.1.0, with ten MCP tools, a workflow skill, a bundled MCP Apps dashboard,
one physical MobileCLI adapter and a clearly separate fixture backend.

Added `iGenticPluginPolicy`, a small SwiftPM executable that imports the actual
`AgentCore.PolicyEngine` and `AuditLog`. Only four fixed public read/prepare
operations can pass. Unknown operations fail closed. It accepts no caller
classification/risk override or approval flag and issues no execution capability
for a persistent write. Swift core policy/approval implementations are unchanged.
The helper's audit is process-local; this is not a durable distributed audit trail.

The physical adapter can launch only our configured Diagnostics identity, verify
foreground identity, recognize a fixed set of public markers, and tap one freshly
resolved `Open local discovery` control. Raw device output/labels, user values,
subprocess errors, screenshots and private identifiers are never returned to the
MCP client. A cross-process lease, session deadline, cancellation, consumed
proposal and independent post-action observation bound the workflow. Driver
observation/input is not atomic; broader GUI authority is deliberately absent.

## Observed local validation

Host: authorized MacBook Neo, Xcode 27.2 and Node 26.10.0.

| Check | Observed result | Evidence class |
| --- | --- | --- |
| Swift helper build (`swift build --product iGenticPluginPolicy`, one job, external scratch path) | Passed | macOS compile |
| Existing Swift suite | **288 passed, zero failures** | Host package tests on this branch's main-based input |
| Plugin Node suite with actual compiled policy helper and installed Chrome | **17 passed, zero failures, zero skipped** | Deterministic, MCP protocol and browser acceptance |
| Official SDK MCP client against fixture server | Initialize, ten tools, strict-input refusal, navigation, verified receipt, replay rejection, UI resource and stop passed | Synthetic device only |
| Browser MCP Apps acceptance | Official AppBridge/App handshake, tool result display, Refresh and Stop, disabled stopped controls; zero page exceptions | Headless installed Chrome, synthetic host |
| Local plugin marketplace and installation | CLI reported `igentic-iphone-connect@igentic-local` 0.1.0 installed and enabled; cached server/dependencies/UI present | Local Codex plugin installation |
| Installed cached plugin workflow | Fixture workflow returned independently verified discovery receipt | Installed package + synthetic device |
| Clean extracted runtime archive | Fixture workflow passed outside the source tree with packaged dependencies | Clean package acceptance |

The tests include forged sessions/proposals, extra input keys and fabricated
approval, unsupported tool names/actions, expiration, cross-process exclusion,
changed screen state, concurrent requests, process timeout/output bound/abort,
uncertain dispatch, no replay, stop during dispatch, session-bound result lookup,
and private/injected label suppression. These are meaningful failure-path checks;
they are not a benchmark of natural-language planning.

The dashboard screenshot used for visual inspection contains a synthetic device
and public `Explore` marker only. No personal iPhone screenshot was captured or
committed by this implementation.

## Physical device gate

At initial inspection Apple listed the paired physical iPhone Air as connected,
but MobileCLI 1.0.24 device discovery returned an empty list. A subsequent Apple
inventory also reported the phone unavailable. Direct MobileCLI foreground
inspection failed. The new plugin's physical smoke test returned
`deviceUnavailable` before starting any session or app action. The owner was asked
to reconnect/unlock the phone while implementation continued.

Therefore **no successful physical-iPhone action through this new plugin has
been observed in this run**. The separate [MobileCLI physical acceptance PR #392](https://github.com/pokekarten/igentic-iphone/pull/392)
contains prior USB-attached evidence, not acceptance of this plugin. No wireless,
phone-detached, background, screen-lock or continuous-stream result is claimed.
No new reminder was created, and no permissions/signing slots/apps were changed.

## ChatGPT connection gate

The signed-in ChatGPT Plugins page was opened. Its **Add custom MCP server**
dialog offers a Server URL or Tunnel ID. The local stdio installation is not
automatically such a web connection. No existing tunnel ID was available in
that dialog. OpenAI Platform tunnel settings redirected to sign-in in this
browser session; no credentials were entered and no tunnel/account/billing
configuration was changed.

The package can serve an eligible private stdio tunnel. Completion of the web
connection requires the owner's Platform login/tunnel permissions and configured
runtime credential, followed by a real ChatGPT tool invocation. That account
step, public publishing eligibility, OAuth/hosted multi-user infrastructure and
store review remain open. Do not call the package a registered or publicly
published ChatGPT app, or the entire remote-control roadmap complete.

Official sources used: [plugin packaging](https://developers.openai.com/plugins/build/plugins),
[ChatGPT connection](https://developers.openai.com/plugins/deploy/connect-chatgpt),
[private tunnels](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels),
[desktop submission](https://developers.openai.com/plugins/deploy/desktop-only),
[MCP Apps bridge](https://developers.openai.com/plugins/build/chatgpt-ui).

## Packaging and license limits

Direct SDK/schema dependencies and development tools are version-locked with npm
integrity hashes. The platform-specific runtime archive contains the compiled
policy helper and production node dependencies; it excludes operator config,
device identifiers, pairing/signing material, screenshots and MobileCLI. An
extracted archive passed the fixture smoke check. macOS resource metadata is
disabled during archive creation. The SHA-256 sidecar identifies the exact
local archive; rebuilds may differ because archive metadata is not normalized.

An important source correction: Mobile MCP's Apache-2.0 license does not cover
its underlying MobileCLI binary. The observed installed MobileCLI 1.0.24 package
declares **FSL-1.1-ALv2**. This implementation wraps the user's separate installed
copy; no redistribution or commercial product clearance is asserted. Further
dependency/artifact review remains required for public distribution.

No model/provider API was invoked, no API key was read or created, and no paid
fallback or billing activation occurred. npm registry downloads and local tests
were used. `.github/workflows/iphone-plugin.yml` adds repeatable plugin validation;
new GitHub CI results must be checked on the published commit independently.


## 2026-11-23: ChatGPT handoff API follow-up

The separate draft [PR #406](https://github.com/pokekarten/igentic-iphone/pull/406)
extends the **read-only, loopback** portable Streamable HTTP MCP server with
`iphone_chatgpt_handoff`. Allowed values are exactly `diagnostics`,
`discovery`, and `reminder-draft`. The response contains a fixed
`igentic://handoff/v1/...` URL, `actionExecuted:false`,
`iPhoneConnected:"not-checked"`, and `requiresOwnerTap:true`.
No phone action is performed by the MCP server.

The iOS app declares the custom URL scheme, checks exact paths and presents
a **second local navigation choice**. This is not remote App Intents execution,
authentication, connection evidence, a reminder save, or a successful
ChatGPT mobile plugin installation.

To reduce protocol drift, PR #406 now contains a Node contract test comparing
the MCP action allowlist to the Swift route cases, the Xcode Info.plist URL
scheme and the SwiftUI URL entry point. The plugin CI must verify the exact
new head; earlier green runs do not prove later edits. The [ChatGPT handoff
runbook](../../plugins/iphone-connect/CHATGPT_HANDOFF.md) documents owner setup,
eligible ChatGPT account/workspace requirements, and separate physical-device
acceptance. A locally installed developer skill is not a connected mobile MCP
service.

**Not accepted yet:** verified ChatGPT account invocation, app signing and
installation at this exact revision, a real iPhone URL dispatch with independent
observation, direct mobile network access, cellular control, background
execution, and any cross-app actions. These must not be inferred from simulator
or API-only tests.

## 2026-11-23 Work continuation: Sites Worker and current acceptance

The remote PR #406 head was independently verified as
`06986bfbe21e0f37ac18b6ac6f85cf9c58a16414` on
`feat/chatgpt-handoff-api-prototype-20261123`. The PR is still a draft, based
on `feat/optional-capability-core-20261123`; no merge or base change was made.

### Current CI at the starting remote head

- [Phase 0 CI Validation](https://github.com/pokekarten/igentic-iphone/actions/runs/45166627845): completed, success.
- [iOS App Wrapper](https://github.com/pokekarten/igentic-iphone/actions/runs/45166627885): completed, success. Build, install/launch and both system-level simulator UI acceptance tests succeeded.
- iPhone Plugin, Repo Audit, Docs Consistency, PR Change Scope, Pull Request
  Quality and Commit Email Privacy were also successful. These results apply
  to the starting remote head, not to the new local Worker change.

### Implemented and tested locally

The existing pure handoff reference now has a stateless Sites JSON-RPC Fetch
handler and bundled Worker entry point. It serves the existing fixed HTML and
exactly one read-only tool using the canonical three-action contract.
Discovery, listing, calls, bounded streamed input and sanitized failures are
covered by tests. The deployed access boundary must be owner-private Sites
authentication; the handler does not implement standalone authentication.

The iPhone Plugin workflow now also triggers for changes under
`plugins/igentic-chatgpt-iphone/**`, which previously could bypass this suite
when no other matching paths changed.

- Focused Sites endpoint + bundled Worker tests: **5 passed**.
- Complete Node/MCP suite: **75 passed, 1 skipped, 0 failures**. The optional
  actual Swift-policy-helper test is skipped when its executable is not supplied.
- Repository structure and `git diff --check`: passed.
- Real isolated local Chrome WebMCP smoke: passed; one native read-only tool,
  all three links, unknown-action rejection, no automatic navigation and no
  external page requests/errors. This is browser WebMCP, not hosted Sites MCP.
- Physical iPhone via CoreDevice Wi-Fi: `smoke:handoff:wifi --reminder-preview`
  passed. A local SDK MCP client generated all three links, the Mac harness
  opened them in the installed first-party app, and independent app-owned
  receipts confirmed fresh previews compared with the pre-dispatch baseline.
  The invalid own-app route produced no new receipt. No reminder creation,
  personal content return, cross-app control or approval bypass occurred.
- The first attempt through the currently installed desktop `iphone_*`
  connector returned `backendFailed` on `iphone_open_diagnostics`. Its session
  was explicitly stopped. Subsequent read-only CoreDevice inspection confirmed
  the own app installed/running over Wi-Fi before the separate repository
  acceptance above. The native harness success does not repair or prove that
  failed installed-connector path; its failure cause remains unresolved.

### Publication and account limits

The Sites connector is available, but its complete owner-Site inventory had no
iGentic Site. No unrelated Site was changed. No Site was created or deployed,
and no generated plugin was installed. Creating a separate Sites source
repository would exceed this task's restriction to publishing commits only
on the existing PR branch. A future owner-private deployment needs its own
authorized source/publication step and an actual connected-plugin invocation.

GitHub independently reports this repository as **public** (`private:false`,
`visibility:public`), whereas the current task described it as private.
Publication was initially held for clarification. The owner subsequently
authorized continuation after the public visibility was disclosed, and commit
`58a43e51971875704b268a937c74a0e477a4b62a` was pushed only to the existing
PR #406 branch. Repository visibility was not changed.

The physical test proves app-owned preview appearance, not a human tap in
ChatGPT on iPhone, subsequent manual in-app navigation, or an active ChatGPT
plugin connection. No new iOS build/signing/install was needed for this
JavaScript-only slice. Existing GitHub CI and the preinstalled signed iPhone
app were used; no paid service, model API, account, credential or billing
configuration was activated. No additional CI run was requested.

### Published-head UI failure and focused follow-up

The push triggered the existing CI workflows. Phase 0 (all four jobs), iPhone
Plugin, Workflow Lint and the other queried repository checks passed on
`58a43e5`. The plugin job independently reported 75 passed, 1 skipped and
0 failures. The optional actual Swift-policy-helper test was then run locally
with the existing configured executable: 1 passed, 0 skipped, 0 failures.

The [iOS run](https://github.com/pokekarten/igentic-iphone/actions/runs/45177102469)
failed with **3 of 4 UI tests passing**. In the handoff test, the preview and
absence of automatic navigation were verified, but the broad label-predicate
lookup for the manual discovery link timed out while resolving accessibility
snapshots (DiagnosticsUITests.swift, original line 56). Cold-start handoff,
synthetic approval cancellation and the read-only App Intent passed.

The focused follow-up gives the existing discovery NavigationLink a stable
accessibility identifier and queries that identifier directly, retaining the
runtime-independent element type. A missing control stops the test before any
tap. No timeout increase, test skip, automatic navigation or approval is added.
The test still requires the explicit tap and then verifies the Explore view.

Read-only inspection also found that the installed desktop plugin cache uses
only the older MobileCLI backend, whereas this repository defaults to
CoreDevice. This explains why the two acceptance paths are not interchangeable;
the exact MobileCLI failure and an installed-plugin refresh remain unverified.

Focused local acceptance on Xcode 27.2 / a dedicated iPhone Air iOS 27.2
simulator: `testChatGPTHandoffOpensPreviewWithoutAutomaticNavigation` passed
(84.512 seconds), **1 test, 0 failures, TEST SUCCEEDED**, process exit 0.
The identifier resolved, the test explicitly tapped the control and then
observed Explore. The dedicated simulator was shut down after verification;
the pre-existing unrelated simulator and physical iPhone were not used.
This is local simulator evidence for the follow-up, not a replacement for
new-head GitHub CI or a physical-device/ChatGPT-client acceptance.
