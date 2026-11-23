# API-free iGentic Agent Loop — combined offline acceptance

This is a **synthetic control-plane acceptance**, not evidence of connected
iPhone hardware, Siri, real App Intents, a running ChatGPT model, or a deployed
ChatGPT Site.

## One coherent, real-code fixture

The executable file test/agent-loop-offline-integration.test.mjs combines:

1. The actual stateless Site MCP handler for a fixed, owner-tapped
   iphone_chatgpt_handoff link. This Site never originates or executes tasks.
2. A separately generated signed read-only owner proposal, validated by the
   pre-provisioned single-host SQLite replay ledger.
3. The transport-neutral state machine and its unpredictable receipt nonce.
   A private, fsynced write-ahead marker is stored before any possible future
   transport adapter can receive a delivery descriptor.
4. A **synthetic** HMAC key-holder receipt, checked for the exact owner task
   ID and delivery nonce, without claiming physical device attestation.

Three separate random ephemeral test keys are used for owner admission,
delivery marker and simulated receipt. No socket, remote network, model
provider, device driver, Apple permission or persistence of personal text
is involved.

## Negative acceptance and limitations

- Arbitrary MCP execution and model-injected write capabilities fail.
- Owner proposal reuse is rejected by persistent replay admission.
- A prepared marker reconstructs **outcome-unknown** after local state loss,
  never proof of send, success or authorization to retry automatically.
- Wrong-key or wrong-nonce receipts fail; an expired reply cannot revive the
  task. A valid fixture receipt remains key-authenticated-only, not proof of
  an actual iPhone action.
- If the marker directory becomes insecure, no delivery descriptor is
  returned. Admission stays consumed, requiring explicit reconciliation.

Run from the repository root:

    node --test plugins/iphone-connect/test/agent-loop-offline-integration.test.mjs
    cd plugins/iphone-connect && npm test

This integration fixture is added to existing Draft PR #417, not a new
overlapping protocol branch. It exercises the existing #410–#415 dependency
lineage but does **not** include sibling PR #414 row-integrity hardening or
Swift receiver implementation from PR #416 unless deliberately composed in
an additional isolated test checkout. No claim of working mobile transport
or a complete live bidirectional agent loop is made.

## Remaining product gates

- Review all exact PR head SHAs and consolidate the branch dependency order.
- Enroll owner and device identities; implement native secure key storage,
  scope, explicit approval, rotation and revocation.
- Authenticate a narrow optional Site-to-owner-relay transport and a native
  iGentic foreground receiver, without a generic remote iPhone API.
- Return an independent receipt tied to actual permitted on-device policy,
  request ID, capability and nonce. A key-only test signer is insufficient.
- Test the real Siri/Shortcuts/ChatGPT client workflow and the available
  physical device paths independently.

The phone was unavailable via both Wi-Fi and USB-C while this fixture was
created. This does not modify the live private Site, ChatGPT permissions,
main, or any actual iPhone.
