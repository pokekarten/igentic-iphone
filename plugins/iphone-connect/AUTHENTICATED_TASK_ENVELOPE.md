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

## Persistent local replay admission: PR #412

The default in-memory replay cache remains **test-only**, and cannot provide
restart-safe protection. The separately reviewed
[sealed local SQLite replay ledger](DURABLE_REPLAY_LEDGER.md) is the preferred
offline durable prototype. The earlier auto-creating replay store was removed
from the combined integration branch: silent database re-creation after
deletion could erase the history of admitted requests.

The sealed ledger requires explicit one-time owner provisioning and an
existing private database; it stores keyed digests rather than raw task IDs.
It fails closed when its file is missing, replaced, corrupted or sealed
with a different key. No running relay, transport, iOS action or owner
permission is implied. Single-host SQLite is not cross-host consensus or
protection against rollback of an entire trusted-host backup.

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
