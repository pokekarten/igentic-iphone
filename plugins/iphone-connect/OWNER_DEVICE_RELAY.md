# Owner/device relay seam — local development only

This is a single-task control-plane adapter for the existing Agent Loop. It is
not a network service, device enrollment system, ChatGPT identity verifier,
persistent task queue, or physical-device receipt implementation.

- An authenticated-in-process owner role submits a fresh UUID for the one
  fixed read-only status capability, checks status, cancels before a claim,
  or inspects an existing durable delivery marker.
- A separately provisioned device role may claim once and submit the existing
  nonce-bound receipt proof. Claim returns the canonical signed task wire
  accepted by the Swift verifier and the receipt challenge. The relay records
  uncertain delivery before returning it. Losing that response never allows
  another claim or a second submission using a marked UUID.
- Five distinct random 32-byte keys are required: owner access, device access,
  proposal signing, receipt authentication and marker seal. Keys are injected
  by the trusted local host, not generated or exposed by model tools.
- The existing sealed SQLite admission and write-ahead marker must be used.
  A restart does not reconstruct the live task or authenticate an old receipt:
  a durable marker can only recover outcome-unknown. No automatic retry.
- The receipt proves key possession, not physical execution, consent or
  identity. No battery/OS observation, raw prompts, or other private content
  is returned. No operation opens a listener or invokes iOS or a model.

The next production seam is an owner-approved authenticated TLS transport with
actual owner/device enrollment, key rotation/revocation, durable task status,
bounded request handling and a native receipt generated only after verified
owner-app action. Do not expose the local access keys as plugin arguments,
URL parameters or model prompts. Do not reuse the cellular readiness key.
The existing private Site remains manual and unchanged.

Run: node --test plugins/iphone-connect/test/owner-device-relay.test.mjs
