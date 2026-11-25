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
| /v1/owner/result | |
| /v1/owner/cancel | |
| /v1/owner/recover | |

Submit, result, cancel and recover take `{"requestId":"<uuid>"}`.
Status and claim take an empty object. Receipt takes only proof.
Use the owner result route for a task-specific lookup. A matching request
returns its ID, lifecycle state and receipt evidence flags. An unknown ID
returns `{"schema":1,"result":null}`, including after a relay restart that
lost the in-memory task. A lookup can be repeated without claiming or
re-executing the task. The UUID correlates a task, while the owner key
authenticates the caller. Responses are marked
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
claim is a preview only; it is not wired to an App Intent or owner approval
button. The internal enrolled review session is described below. Swift package tests use an independent Node-generated
wire fixture. The macOS HTTPS integration test below exercises the live relay. No system trust settings are
changed. The native client still needs actual TLS/owner-device enrollment,
a production endpoint and owner-reviewed execution before physical use.

## Owner-gated synthetic receipt fixture

The DEBUG fixture exercises the same internal fixed key-holder proof encoder
and native signed owner status gate used by the enrolled review session.
The gate binds a decoded claim to its receipt nonce, rechecks the signed
proposal and reserves a durable replay marker before local review.
A separate sharing review may prepare one acknowledgement after an unexpired
local read, using a distinct receipt key and current external-sharing policy.
No status observation is included. Nonce substitution, replay, expiration,
clock rollback after expiration and Local Only mode cannot yield a new proof.
The macOS fixture sends a synthetic proof over loopback HTTPS. The fixture
entry points remain DEBUG-only; the internal encoder is available in Release.
A production sender, native approval UI and actual owner-device enrollment
are still open. An independent synthetic HMAC vector is checked in tests.

## macOS native HTTPS interoperability

On a Mac with Xcode command-line tools, run
`node --test plugins/iphone-connect/test/owner-device-relay-https.test.mjs`.
The native smoke test builds a private Debug fixture against the local iGenticApp package. The ordinary client sees an untrusted, newly generated certificate
and consumes its attempt. A separate test-only URLSession explicitly trusts
that certificate for this process, requests the pending claim over HTTPS and
verifies the live Node response with the Swift parser against the owner's
fresh request ID. The fixture stages the claim in the native review gate
using a temporary replay journal. It feeds a synthetic status into the local
read and explicitly simulates the separate sharing review. Swift submits
the resulting one-use proof via HTTPS. The Node owner looks up that same
request ID twice and observes `receipt-key-authenticated` with
`actionExecuted=false`. A second device claim is empty. Before the read and
in Local Only mode, the gate supplies no proof. The test reads synthetic
data on the Mac and installs no trust in the system Keychain.

For a product roundtrip, bind one owner and foreground app installation to
the same task, obtain an owner-reviewed app read, then return a minimal result
through a plugin lookup bound to that owner and task. Verify it from the
originating ChatGPT conversation. Exercise the reverse Shortcuts/Siri entry
separately on a physical iPhone, including whether it opens the intended
conversation or starts a new one.

## Native local enrollment storage

AgentLoopDeviceEnrollmentVault provides explicit import and local revocation
of a single credential bundle, using a non-synchronizing, unlocked-only,
ThisDeviceOnly iOS Keychain item. Device access, proposal, receipt and local
replay keys must all differ. Missing, malformed or inaccessible storage
does not auto-enroll or reset. Local revocation replaces the credential
record with a tombstone; no automatic re-enrollment or rotation is exposed.
This is single-process main-actor serialization, not distributed CAS or
rollback-resistant storage. Revocation does not invalidate previously copied
keys or revoke the remote relay; server-side revocation and session lifecycle
remain required. The vault is not wired to a setup screen, claim client or
production signer. Tests use a synthetic in-memory backend; no real Keychain
items are written during tests. The iOS backend requires a native build and
physical-device acceptance.

## Local MCP result lookup

An explicitly configured local MCP host can pass an owner-bound
`lookupOwnerResult(requestId)` to `createServer`. This enables the
read-only `iphone_owner_task_result` tool. The host supplies owner
authentication and returns the bounded relay result for that ID. Tool
arguments contain only the ID. The default server and the deployed Site
have no configured lookup.

The macOS integration test uses an MCP SDK client to discover the tool
and read the Swift-generated fixture proof twice by its original ID.
It also checks an unknown ID and rejects malformed input.

## Enrollment-bound native claim session

The internal main-actor AgentLoopEnrolledClaimSession connects existing local
enrollment storage to a single explicit loopback claim. External AI mode is
required; Trusted Devices mode is not sufficient because the relay has no
trusted-device identity binding yet. It reads existing enrollment before I/O,
then checks cancellation, current mode and exact enrollment again before
returning a preview. Revocation while the network request is in flight blocks
its result, not the already transmitted request. The attempt is consumed
before I/O; no implicit enrollment, retry, UI or production endpoint is
enabled. Native gate review and proof preparation remain separate transitions.
Tests use synthetic credentials and an injected transport; no actual
Keychain changes are made.

The loopback Streamable HTTP gateway also accepts an explicit
`ownerResults` configuration with `issuer`, `subject` and `lookup`.
Only a verified OAuth token for that issuer and subject can discover or
call the tool. The host binds `lookup` to the corresponding owner's relay.
The standard command-line startup leaves this option disabled.

## Durable server-side revocation (local development)

The owner-only POST /v1/owner/revoke-device accepts exactly an empty JSON
object and permanently disables this single relay ledger's device authority.
The SQLite record is authenticated with a separate MAC domain under the
existing ledger key and committed before success is returned. New submissions,
claims and receipt submissions are rejected after revocation, including on
reopen. Unclaimed pending tasks can be cancelled; already prepared payloads
remain uncertain, and prior authenticated evidence is not erased. No automatic
retry or re-enrollment is available. This is a single-host development seam,
not remote identity revocation, distributed synchronization or recall of an
already released payload. Concurrent processes may have in-flight operations
when revocation commits; use one serving relay process. It cannot resist
restoring an older authenticated revocation record or database backup. Legacy ledgers without the
revocation table fail closed; migration must be reviewed separately, never
delete an existing ledger to upgrade. No MCP tool exposes revocation.

## Explicit offline relay role binding

New relay ledgers must be explicitly provisioned with the proposal key and
a relayRoles object containing ownerAccessKey, deviceAccessKey, receiptKey
and markerKey. All five keys must be distinct. The ledger stores only a
domain-separated HMAC commitment to the ordered roles, never the raw keys.
A generic offline replay ledger cannot be promoted to a serving relay.
Reopening with substituted role keys fails before the marker is provisioned.
The binding is checked during admission, revocation and owner/device
operations; a normal restart cannot silently replace an enrolled role.
Existing ledgers without this schema fail closed, not auto-migrate.
No existing owner files are modified by these tests. This binds configured
roles, not a physical device identity or an OAuth account; actual enrollment
exchange, rotation, backup rollback protection and UI remain separate.

## Enrollment-to-native-review integration

The internal enrolled claim session now stages the verified, correlated
claim directly in a fresh native status gate with a durable replay
journal. A separate local review action can consume this session's
pending review exactly once. It rechecks the current external-AI mode,
cancellation and the exact existing enrollment before the local read
and before returning the local result. Revocation or mode changes block
the session's result; a failed review is not automatically retried.
The gate and journal must be supplied by trusted native code.
After a successful read within this same session, a third explicit native
owner action can prepare a one-use, signed key-holder acknowledgement.
The session consumes the sharing opportunity before checking policy and
the exact live enrollment, and checks both again before returning the
proof. A read outside the session cannot qualify. Revocation, a change to
Local Only, expiry, or a duplicate sharing attempt prevents proof return.
The proof contains only the request ID, nonce, fixed capability, read time
and fixed acknowledgement label, plus an HMAC. It proves possession of
the configured receipt key, not hardware attestation or remote execution.
No private status observation, owner-consent attestation, or device
identity is included. No UI, receipt upload, remote endpoint, real
enrollment exchange or physical-device acceptance is added. Tests use
synthetic claim responses and in-memory enrollment, not real owner keys.
