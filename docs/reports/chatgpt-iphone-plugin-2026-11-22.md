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
