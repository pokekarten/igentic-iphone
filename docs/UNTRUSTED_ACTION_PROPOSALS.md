# Untrusted local-model action proposals (prototype boundary)

This document records the first **non-executing** model-action proposal gate,
implemented in `ios/Sources/AgentCore/UntrustedActionProposalGate.swift`.

A future local language model is allowed to propose only a **name** and **text**.
The proposal itself is not a tool call, a trusted classification or an approval.

The gate accepts exactly two action names:

- `diagnostics.read`: empty payload only, local read, returns **previewOnly**
  when the shared `PolicyEngine` permits an unapproved read.
- `reminder.create`: nonblank text up to 512 UTF-8 bytes, returns
  **approvalRequired** when policy permits the proposed action. **No reminder
  is created**, and a model cannot manufacture a user approval.

Every other action is blocked. Text with recognized sensitive patterns,
oversized payloads, or text supplied with a static diagnostics read is blocked.
The caller must provide its independent trusted classification; the model
cannot lower it. A sensitive classification can require approval even for
a read-only proposal. Output contains only a reason code, never proposed text.

### Non-goals

This is not a real Apple Foundation Models inference session, a system App
Intent, a tool dispatcher, an approval receipt issuer, or an authorization to
execute. An eventual live operation must separately flow through
`AgentKernel.handle` and user-bound approval logic. No network access, user
device modification or local-model downloads are introduced.

### Acceptance

```sh
cd ios
swift test --filter UntrustedActionProposalGateTests
swift test
```

Tests pin the safe read preview, write approval, fail-closed exact allowlist,
rejection of sensitive/invalid payloads, high trusted classification and
deterministic review. This changes no signing or app entitlements.
