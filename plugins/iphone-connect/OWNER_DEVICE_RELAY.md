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
  is returned. The core relay does not open a listener or invoke iOS or a model.

The next production seam is an owner-approved authenticated TLS transport with
actual owner/device enrollment, key rotation/revocation, durable task status,
bounded request handling and a native receipt generated only after verified
owner-app action. Do not expose the local access keys as plugin arguments,
URL parameters or model prompts. Do not reuse the cellular readiness key.
The existing private Site remains manual and unchanged.

Run: node --test plugins/iphone-connect/test/owner-device-relay.test.mjs


## Loopback HTTPS test transport

The optional `createLoopbackOwnerDeviceHTTPS` factory adds a real TLS
listener, exclusively bound to 127.0.0.1. It never starts automatically,
has no command-line entry point, rejects non-loopback hosts, browser
origins and proxy forwarding headers, and accepts bounded, canonical
JSON via fixed POST routes only. Separate owner and device role credentials
are passed as hex-encoded bearer keys in headers, never in URLs or prompts.
The test creates a throwaway localhost certificate and explicitly trusts
that certificate without disabling certificate verification.

| Owner routes | Device routes |
| --- | --- |
| /v1/owner/submit | /v1/device/claim |
| /v1/owner/status | /v1/device/receipt |
| /v1/owner/cancel | |
| /v1/owner/recover | |

The submit/cancel/recover bodies contain only requestId; status and claim
take an empty object; receipt takes only proof. Responses are marked
no-store. Unknown, unauthorized, or invalid transitions never echo input.
Two concurrent claims return at most one payload. The receipt is still
synthetic key evidence, not physical-device execution.

This adapter is deliberately not reachable from an iPhone or ChatGPT
account. Do not tunnel or proxy it into a public service. A separate
production identity/enrollment and revocation review remains required.

Run: node --test plugins/iphone-connect/test/owner-device-relay-https.test.mjs

## Native claim client (development only)

The internal Swift AgentLoopRelayClaimClient builds the fixed loopback
POST, uses an ephemeral URLSession with ordinary system certificate
validation and no redirect, cache or cookie handling, and consumes one
attempt per instance. It bounds the response to 2048 bytes and verifies
the exact response shape, nonce syntax, signed canonical wire, request ID,
expiration and issuance time using the existing native verifier. A failed
transport is uncertain, never a reason for automatic retry. The parsed
claim is a preview only; it is not wired to an App Intent, owner approval
button or receipt signer. The Swift tests use an independent Node-generated
wire fixture, not a live native TLS request. No system trust settings are
changed. The native client still needs actual TLS/owner-device enrollment,
a production endpoint and owner-reviewed execution before physical use.
