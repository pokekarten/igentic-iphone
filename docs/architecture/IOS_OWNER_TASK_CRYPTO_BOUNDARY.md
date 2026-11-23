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
