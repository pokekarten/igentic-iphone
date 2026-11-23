# iGentic native two-turn read-only loop

Status: first-party offline prototype on top of the existing PR #409 Shortcuts/model proposal safety gate.
This does **not** prove Siri, ChatGPT, physical iPhone, remote transport or model integration.

## What is new
- `AgentLoopNativeReadOnlySession` reuses `AgentLoopModelHandoff.review` instead of inventing a second JSON schema/parser.
- Accepts exactly `{"action":"status.read"}` followed by `{"action":"finish"}`, with a fresh in-memory correlation UUID and a five-minute upper bound.
- The trusted native read step passes the existing `AgentCore.PolicyEngine` for local-only coarse status data.
- The only observable result is a bounded status summary held in memory; **no automatic export or disclosure to the model**.
- A final state, invalid order, malformed output, duplicate JSON key, unsupported action, spoofed approval, timeout or replay cannot invoke further status reads.
- The app exposes a visible, explicitly owner-tapped *synthetic test* with these two fixed proposals; it reads the local status. It never invokes ChatGPT, another model, an App Intent, MCP or another app.
- Every receipt states `remoteActionExecuted=false` and `ownerApprovalGranted=false`. Observing a local read is **not** physical device attestation.
- This is a safe reusable native harness, **not** a general-purpose executor. Do not add write tools without capability-specific approvals, durable replay and verified read-back.

## Validation and next acceptance
Run the focused Swift tests, the complete Swift package suite and an Xcode 27.2 simulator compile.
The button must be tested in an installed signed iOS 27 app before it is considered physically usable.
Eventually connect one available on-device model after the existing structured-proposal gate,
without automatically handing private observations to external model providers.

Research: [loopl](https://github.com/cagataycali/loopl), [Apple Foundation Models tool calling](https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling).
No third-party source code was copied.
