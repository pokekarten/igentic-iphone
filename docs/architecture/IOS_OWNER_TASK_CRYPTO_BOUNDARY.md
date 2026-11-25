# iGentic iOS owner-task cryptographic verification – pre-transport boundary

**Status:** Offline-tested Swift / Node compatibility gate, no actual iPhone
transport or authorization. No OpenAI API, Siri session, installed Shortcut
or private ChatGPT Site tool is required for these tests.

## Purpose

Before implementing a mobile-data task pull, the future iGentic iPhone client
must reject arbitrary commands masquerading as a signed task. This task
introduces the pure-Swift AgentLoopRemoteTaskVerifier in the iGenticApp Swift
package. It recognizes one bounded **read-only** proposal originating from
the existing owner relay's Node prepareSignedReadOnlyProposal contract.
A checked value is **not** an execution receipt, owner permission, or
replay-admitted task.

## Canonical single-action wire format

The relay's JSON object must be encoded with the exact fixed property order,
field names, lowercase UUID, integer times and lowercase hex signature:
a body object containing schema, kind, requestId, issuedAt,
expiresAt, capability, parameters, followed by signature.
Only igentic.own_app.status.read and empty parameters are supported.

The Swift implementation validates JSON structure and requires the
incoming bytes to **equal** its reconstructed canonical JSON before checking
the HMAC. This prevents duplicated keys, escaped key names, extra fields,
unrecognized actions, rewritten numbers and other ambiguous encodings from
being interpreted differently by Node and Swift.

The separate owner-relay signing key must be a randomly generated 32-byte
secret. It must not be placed in Git, a ChatGPT prompt, an MCP response, a
deep link, a console log, or reused as a cellular readiness key.

The HMAC-SHA256 domain is pinned to igentic-owner-task-proposal-v0 plus newline.
Verification also enforces a maximum 1024-byte envelope, at most 60 seconds
TTL, at most 5 seconds of future clock skew, and time-sensitive rejection of
expired proposals. The iOS verifier returns nil on error, never an
untrusted private-text description.

## Status intentionally remains pre-admission

A valid AgentLoopRemoteTaskPreview explicitly reports:

- status = cryptographically-verified-preview-only
- actionExecuted = false
- ownerApproved = false
- replayAdmitted = false
- iPhoneConnected = not-checked
- deviceReceipt = none

This is **not** the same as the separately deployed, owner-private SQLite
replay admission on PR #412. That host-side database must have an
independently reviewed, owner-specific deployment and a persistent ledger.
The future iOS app needs local replay protection appropriate to its own
trust boundary. No iOS transport, task receiver, app permission request,
Keychain enrollment or device receipt was added here.

## Test contract

- ios/Tests/iGenticAppTests/AgentLoopRemoteTaskVerifierTests.swift
  verifies a fixed synthetic Node test vector, wrong keys, all-zero keys,
  tampered actions, unexpected private fields, duplicate JSON keys, invalid
  numbers, timestamps and expiration.
- plugins/iphone-connect/test/ios-owner-task-parity.test.mjs regenerates
  the **exact** Node wire bytes and MAC from the same public test vector.
- swift test --package-path ios --filter AgentLoopRemoteTaskVerifierTests
  tests the Swift path on a Mac with CryptoKit.
- cd plugins/iphone-connect && npm test ensures Node parity and existing
  plugin contracts still work.

A source-compatible macOS test is **not** the physical iPhone acceptance:
the signed iOS app must independently prove a real 4G/5G HTTPS request,
the actual native read and a device-bound, independently verified receipt.

## Bidirectional key-receipt format parity (debug fixture only)

The read-only agent loop has a second cryptographic schema for a returned
key-holder acknowledgement, separate from the owner-task HMAC domain:

- domain: igentic-device-receipt-key-proof-v1 plus a trailing newline;
- exact canonical body order: schema, kind, requestId, capability, nonce,
  observedAt, status; then a lowercase 64-character HMAC signature;
- capability remains exclusively igentic.own_app.status.read;
- status is exactly key-holder-reports-read.

The Swift source AgentLoopReadOnlyReceiptFixture.swift provides a
**DEBUG + CryptoKit only** protocol signer. It is unavailable in Release
builds and cannot be reached from a production iOS App Intent, a ChatGPT
Site/MCP tool or an untrusted model instruction. Its only purpose is to test
byte-exact parity with the existing Node signReadOnlyDeviceKeyReceipt
fixture. A synthetic test key and request ID prove only that the two
runtimes use the same wire format, not that the iPhone was contacted
or that an actual read occurred.

Swift and Node tests ensure the key, nonce, correlation ID and observed
time change the proof; invalid keys, malformed identifiers and
JavaScript-unsafe timestamps fail closed. The fixture contains no
actionExecuted, ownerApproved, user text, hostname or device identity.

For real mobile-device receipts, **do not promote this DEBUG function into
a production signing endpoint**. Independently verify a policy-allowed
native read, bind the signed challenge to a one-time delivery and device
identity, provision a separate protected device key with revocation, and
return a status that explicitly distinguishes key authentication from
genuine iOS execution evidence. Build and test that in its own reviewed PR.

## Next implementation gates

1. Review and consolidate the two replay approaches on PR #411 / #412,
   including integrity protections on PR #414.
2. Enroll owner and device separately; store keys using appropriate iOS
   Keychain/secure hardware and a dedicated relay-side secret store.
3. Build an opt-in, foreground-only HTTPS read-only task poll and receipt
   upload without expanding the currently readiness-only cellular gateway.
4. Bind a fresh challenge, one-time task ID, native action, iOS policy result,
   and device evidence to an independent receipt. A HMAC alone proves only
   key possession.
5. Independently test Siri → Shortcut → model → iGentic, and ChatGPT Site →
   owner relay → iPhone foreground poll → verified result. No API key is
   required for either **model** route if the supported ChatGPT app/Shortcut
   integration is available on-device. That availability requires a real test.

## Local iOS replay reservation (offline draft)

`AgentLoopLocalReplayJournal` is a separate, opt-in Swift primitive for a
**previously cryptographically verified** `AgentLoopRemoteTaskPreview`.
It is not yet connected to an iPhone transport, Site tool or App Intent.
The caller must explicitly supply a pre-provisioned, owner-private directory
(mode 0700) and a separate, stable 32-byte local marker key. No key material
or user task text may be put in Git, model prompts or logs.

The journal atomically creates one zero-byte, owner-private marker per task ID
using `openat(O_EXCL | O_NOFOLLOW)`, with an HMAC-derived filename and
file/directory `fsync` before it returns. Duplicate reservations, disk errors,
directory replacement or unsafe permissions fail closed. Expired and
unsupported capability previews cannot reserve markers. A crashed process
cannot silently reserve that same ID a second time **while it uses the same
intact directory and marker key**.

This is a reservation marker, **not** a proof that a task was sent, that
an iPhone was connected, that a model ran, or that any action was executed.
In particular, the `AgentLoopRemoteTaskPreview` continues to report
`replayAdmitted=false`, `ownerApproved=false`, `actionExecuted=false`.
There is no automatic retry or garbage collection of unknown outcomes.

**Unresolved before live usage:** owner/device enrollment, protected stable-key
provisioning in Keychain, key rotation and revocation, marker directory
rollback/deletion protection, process and multi-device coordination, iOS data
protection policy, native `PolicyEngine` gating, app foreground lifecycle,
the independent receipt challenge, and end-to-end iPhone testing. Changing
the local marker key or restoring an older directory would bypass this
same-key reservation history; the caller must not use this draft as a
complete replay-admission solution. The owner-relay SQLite ledger from
PR #412/#414 remains an independent requirement.

Tests: `swift test --package-path ios --filter AgentLoopLocalReplayJournalTests`
verifies restart duplicate rejection, empty/private markers, expiry,
directory permission failure and symlink rejection on macOS. These tests
do not verify iOS Shortcuts, a phone network connection or physical actions.

### Fail-closed combined read-only admission (offline prototype)

`AgentLoopLocalReplayJournal.inspectAndReserveCanonicalProposal(_:relayKey:nowSeconds:)`
is now a module-internal, intentionally non-executing admission helper. It accepts raw
bytes only, re-runs exact canonical HMAC verification and expiry/allowlist checks,
then persists a one-shot journal marker **before** returning a preview.
The lower-level `reserveVerifiedPreview` helper is module-internal; it is
not a public mechanism for an untrusted external caller to declare a preview
verified. A bad signature, unsupported action, expired task or changed replay
key does not produce an authorized output. Invalid signed payloads do not burn
a journal entry. A duplicate valid proposal always fails even after a simulated
app restart. Use distinct pre-provisioned keys for signing and on-device
journal filenames.

This is **not** an execution or owner-approval pipeline: successful admission
still returns `actionExecuted=false`, `ownerApproved=false`,
`replayAdmitted=false` and `deviceReceipt=none`. Production still requires
private iOS key enrollment and storage, explicit local policy/consent, lifecycle
integration, an authenticated transport, signed independent device receipts and
physical-iPhone acceptance. Do not expose the bridge as a remote write API.

### Native policy preflight (non-executing)

AgentLoopNativePolicyPreflight.inspectForOwnerReview runs BEFORE a replay
reservation or iOS action. It examines exact cryptographically verified wire
bytes, then applies native PolicyEngine to the potential external disclosure of
own-app status, using ActionRisk.externalShare and
DelegationTarget.externalProvider. Local Only blocks the external return;
restricted sensitive data blocks automatic delegation. Other eligible privacy
settings yield only requiresLocalOwnerReview. No verdict enables automatic
execution, changes approval policy, signs receipts, or sends data.

Privacy mode and actual status data classification MUST come from native
owner-controlled state, never from Site, ChatGPT or task text. This pure
function does NOT claim settings loading, owner confirmation UI, consent
receipt, or transport is wired up. The later replay reservation, protected
enrollment, explicit action-specific consent and device receipts remain
distinct mandatory production checks.

The lower-level combined cryptographic helper and replay reservation are
module-internal. The public journal entry point is the native
inspectPolicyAndReserveForOwnerReview method. It rejects invalid or blocked
tasks before creating replay files, then persists a one-shot marker only for
a manually reviewed candidate. This does not obtain owner approval or send
any result. Regression tests cover mode-denied tasks not consuming markers
and duplicate rejection across restarted journal instances.

### Owner-enrolled replay key in native Keychain (offline-only)

AgentLoopReplayKeyVault keeps the independent 32-byte local HMAC replay-marker
key in a nonsynchronizing device-only, When Unlocked Keychain item. Reading
never creates a replacement. Only a future **explicit owner setup flow** may
call enrollExplicitly after provisioning an empty owner-private 0700 directory.
The Keychain operation is create-once (no update, delete or key rotation).
If a Keychain item is missing while replay markers or a prior binding remain,
enrollment fails closed instead of silently resetting replay history. Invalid
stored keys and Keychain I/O failures also fail closed. Targeted unit tests
use an isolated fake backend; they do not alter the Mac or iPhone Keychain.

**Not yet integrated:** the owner setup UI, protected relay-signing key
enrollment, persistent trust policy, directory protection against a privileged
rollback, and the foreground transport/independent device receipts. This code
does not touch the existing Cellular Companion Keychain or add network access.

The openExistingJournal(directory:) path loads an existing protected key
without provisioning anything and constructs the durable local journal.
A restart regression verifies that duplicate signed, policy-reviewed tasks
remain blocked even when reopened through the vault. Keychain enrollment is a
distinct explicit owner setup action, never automatic on task receipt.
