// iGentic v0 control-plane admission, independent of Sites and iPhone transport.
// HMAC authenticates an explicitly provisioned owner relay, NOT a physical phone
// action, user approval, a ChatGPT identity, or Apple device attestation.
// Deliberately no listener, queue, credentials, file storage or executor.
import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';

const DOMAIN = 'igentic-owner-task-proposal-v0\n';
const CAPABILITY = 'igentic.own_app.status.read';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const HEX = /^[0-9a-f]{64}$/;
const MAX_TTL_SECONDS = 60;
const FUTURE_CLOCK_SKEW = 5;
const OWN = Object.prototype.hasOwnProperty;

function fail() { throw new Error('invalidTaskEnvelope'); }
function assertKey(key) {
  // Length alone does not establish a secret: an all-zero or repeated-byte
  // test/default key is trivially guessable. This guard catches obvious
  // misconfiguration, not low entropy in general. Provision randomly.
  if (!Buffer.isBuffer(key) || key.length !== 32
    || key.every(byte => byte === key[0])) throw new Error('invalidOwnerRelayKey');
}
function exactFields(object, fields) {
  return object !== null && typeof object === 'object' && !Array.isArray(object)
    && Object.keys(object).length === fields.length
    && fields.every(field => OWN.call(object, field));
}
function normalForm(body) {
  if (!exactFields(body, ['schema', 'kind', 'requestId', 'issuedAt',
    'expiresAt', 'capability', 'parameters'])
    || body.schema !== 1 || body.kind !== 'read-only-task-proposal'
    || typeof body.requestId !== 'string' || !UUID.test(body.requestId)
    || body.capability !== CAPABILITY
    || !exactFields(body.parameters, [])
    || !Number.isSafeInteger(body.issuedAt) || body.issuedAt < 0
    || !Number.isSafeInteger(body.expiresAt)
    || body.expiresAt <= body.issuedAt
    || body.expiresAt - body.issuedAt > MAX_TTL_SECONDS)
    fail();
  // Explicit order avoids relying on attacker-supplied property ordering.
  return {
    schema: 1,
    kind: 'read-only-task-proposal',
    requestId: body.requestId,
    issuedAt: body.issuedAt,
    expiresAt: body.expiresAt,
    capability: CAPABILITY,
    parameters: {}
  };
}
function mac(key, body) {
  return createHmac('sha256', key).update(DOMAIN + JSON.stringify(normalForm(body)))
    .digest('hex');
}

/**
 * A caller must already possess a separately provisioned 32-byte owner-relay key.
 * Never put the key in GitHub, a URL, a model prompt, or a ChatGPT Site response.
 * This only prepares a proposal; it does not dispatch or enqueue work.
 */
export function prepareSignedReadOnlyProposal({
  key, requestId = randomUUID(), issuedAt,
  ttlSeconds = MAX_TTL_SECONDS
}) {
  assertKey(key);
  if (!Number.isSafeInteger(ttlSeconds) || ttlSeconds < 1
    || ttlSeconds > MAX_TTL_SECONDS) fail();
  const body = normalForm({
    schema: 1, kind: 'read-only-task-proposal', requestId,
    issuedAt, expiresAt: issuedAt + ttlSeconds,
    capability: CAPABILITY, parameters: {}
  });
  return { body, signature: mac(key, body) };
}

/**
 * An in-memory admission preflight for future authenticated transport.
 * Real deployment requires a scoped secret store, TLS, owner/device enrolment,
 * persistent replay protection and independent device receipts. No action runs.
 */
export function createOwnerProposalAdmission({
  key, nowSeconds = () => Math.floor(Date.now() / 1000), maxInflight = 128,
  replayStore
} = {}) {
  assertKey(key);
  if (typeof nowSeconds !== 'function' || !Number.isSafeInteger(maxInflight)
    || maxInflight < 1 || maxInflight > 1024
    || (replayStore !== undefined
      && (!replayStore || typeof replayStore.reserve !== 'function')))
    throw new Error('invalidOwnerRelayConfig');
  // Pin the owner key at admission construction. The caller retains its Buffer
  // and must not be able to change which secret this verifier trusts later.
  const relayKey = Buffer.from(key);
  const seen = new Map();
  return {
    admit(envelope) {
      if (!exactFields(envelope, ['body', 'signature'])
        || typeof envelope.signature !== 'string' || !HEX.test(envelope.signature))
        fail();
      const body = normalForm(envelope.body);
      const now = nowSeconds();
      if (!Number.isSafeInteger(now) || now < 0) throw new Error('invalidOwnerRelayClock');
      if (body.issuedAt > now + FUTURE_CLOCK_SKEW || body.expiresAt <= now)
        throw new Error('expiredOrFutureTaskEnvelope');
      const expected = Buffer.from(mac(relayKey, body), 'hex');
      const received = Buffer.from(envelope.signature, 'hex');
      if (received.length !== expected.length || !timingSafeEqual(received, expected))
        throw new Error('unauthenticatedTaskEnvelope');
      // Only authenticated, in-window requests enter the bounded replay cache.
      // A durable store is opt-in and MUST be independently provisioned before
      // any future network listener. It persists one-time use across restarts.
      if (replayStore !== undefined) {
        if (replayStore.reserve({
          requestId: body.requestId, expiresAt: body.expiresAt, now,
          maxEntries: maxInflight
        }) !== true) throw new Error('ownerReplayStoreUnavailable');
      } else {
        for (const [id, expiration] of seen) if (expiration <= now) seen.delete(id);
        if (seen.has(body.requestId)) throw new Error('replayedTaskEnvelope');
        if (seen.size >= maxInflight) throw new Error('ownerRelayCapacityReached');
        seen.set(body.requestId, body.expiresAt);
      }
      return Object.freeze({
        schema: 1, requestId: body.requestId, capability: CAPABILITY,
        state: 'authenticated-proposal-only', expiresAt: body.expiresAt,
        iPhoneConnected: 'not-checked', actionExecuted: false,
        ownerApproved: false, deviceReceipt: 'none',
        nextStep: 'requires-separate-transport-policy-and-device-verification'
      });
    }
  };
}
