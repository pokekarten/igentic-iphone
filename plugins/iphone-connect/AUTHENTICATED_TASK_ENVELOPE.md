# iGentic offline authenticated task proposal v0

This is **pre-transport code** for future ChatGPT/plugin -> owner relay -> iGentic
control-plane development. It is not published on Sites, reachable on the
network, deployed to iPhone, or able to dispatch a task. No OpenAI model API is
used. The phone can be disconnected during every test in this PR.

## What exists

`src/authenticated-task-envelope.mjs` prepares a narrowly typed
`igentic.own_app.status.read` proposal signed using a separately provisioned
32-byte HMAC-SHA256 owner-relay secret. The wire object has exactly two fields:
`body` and `signature`. The body is canonicalized with exact field names,
a UUID request ID, integer issued/expiry times, a <= 60-second lifetime and
empty parameters. The signature is domain-separated from the existing cellular
readiness HMAC. Secrets must never be stored in Git, source, URLs, or ChatGPT
prompts. No key is included in the plugin tool output. Keys must be
generated using a cryptographically secure random source and separately
provisioned. The code rejects uniform-byte keys (including all-zero defaults)
but cannot measure or guarantee the entropy of an otherwise 32-byte key.

`createOwnerProposalAdmission` validates this request with constant-time
MAC comparison, bounded skew, expiry, exact schema, strictly one read-only
capability, and a bounded in-memory replay cache. The only successful output is
an **authenticated proposal**, with:
- `state = authenticated-proposal-only`
- `iPhoneConnected = not-checked`
- `actionExecuted = false`
- `ownerApproved = false`
- `deviceReceipt = none`

The module has no HTTP listener, no queue, no iOS adapter, no model call,
no memory of private conversations and no command/shell invocation. No Site
MCP tool is added by this change. The default in-memory replay defense is sufficient only for local
protocol tests; it is **not** safe across process restarts or multiple workers.

## Optional single-host durable replay store (still offline-only)

The new src/durable-task-replay-store.mjs module provides an opt-in
SQLite-backed replay store. It uses the built-in Node.js node:sqlite module
(verified on the Mac with Node 26), explicit BEGIN IMMEDIATE transactions,
a unique request ID constraint, expiry pruning and a bounded number of active
records. A successful admission records a UUID and expiry time; it **never**
stores the HMAC key, a signed payload, private text or device metadata.
The original in-memory default remains for isolated demonstration tests.

A caller must provision an existing, owner-owned 0700 directory and give an
absolute database filename. A newly created database uses 0600 permissions.
Existing symlinks, unsafe permissions and storage errors fail closed. Two
independent local database connections and a separate operating-system
process are exercised by regression tests against the same database.

Offline example; the real owner key must come from a separate protected
secret store and never be put in Git, an AI prompt or a web link:

    import { createDurableTaskReplayStore } from './src/durable-task-replay-store.mjs';
    import { createOwnerProposalAdmission } from './src/authenticated-task-envelope.mjs';

    const replayStore = createDurableTaskReplayStore({
      filePath: '/private/owner-only/igentic-replay.sqlite'
    });
    const admission = createOwnerProposalAdmission({
      key: ownerRelayKey, replayStore
    });
    // Admit only after separate authentication, transport and policy checks.
    // admission.admit(envelope)
    replayStore.close();

This module is **not** a hosted multi-tenant or distributed replay service.
All processes must share the same owner-controlled local disk database.
A shared network mount, separately hosted replicas, unverifiable filesystem,
or the default in-memory mode is not sufficient for remote deployment.
Database key rotation, hardened provisioning, HTTPS, owner enrollment,
device attestation, separate iOS approval and device execution receipts
remain unsolved product gates. Using a durable store **does not** create an
iPhone connection or authorize a device action. Other Node runtimes need
independent compatibility checks for the built-in node:sqlite API.


## Next implementation gates — not included or claimed here

1. Enroll a real owner and explicitly bound device identity over a trusted
   channel. Define key rotation, expiry, emergency revoke and permissions
   using native iOS Keychain plus a server-side secret store. Do not reuse
   the existing cellular *readiness* secret for task authorization.
2. Add an authenticated HTTPS transport independently from the ChatGPT Sites
   manual-link Worker, with proper TLS, OAuth or equivalent account-bound
   permission, tenant/owner isolation, replay protection persistent across
   restarts, size/rate limits and request audit. Do **not** put a generic
   device-control endpoint on the public Sites Worker.
3. Deliver one read-only proposal to a trusted Mac CoreDevice bridge **or**
   an explicit foreground iPhone companion. A signed request does not provide
   iOS permissions and cannot override a policy or an owner's approval.
4. Bind an independently observed receipt to request ID, policy decision,
   exact capability, fresh nonce and executing device. A tunnel or Mac process
   launch is not evidence of an iPhone action. After timeout of a possibly
   executed write, the outcome must remain unknown rather than automatic retry.
5. Only once the physical device is available, independently test USB-C,
   Wi-Fi, and cellular paths; do not assume background execution on iOS.
   Validate a real ChatGPT MCP invocation and receipt from the same request.

The existing `iphone_chatgpt_handoff` stays navigation-only and the
new `igentic_get_capabilities` and `igentic_shortcuts_setup` remain static
reference tools until the *existing* private Site is explicitly updated
and reviewed. No new Site or account access is created by this PR.

## Validation

Run `cd plugins/iphone-connect && npm test`. The new tests cover accepted
read-only proposals, strict negative schemas, unknown actions and private
payload injection, authentic MAC checks, replay, expiry, clock skew, bounded
memory, and absence of implicit device actions. This test suite does not
constitute hardware verification.
