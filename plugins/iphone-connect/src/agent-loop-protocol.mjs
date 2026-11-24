// Transport-neutral, offline-only agent loop protocol. Never dispatches network,
// Siri/Shortcuts, an iOS App Intent, or any device operation. A MAC authenticates
// key possession only; it does not attest a physical iPhone or owner consent.
import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const MAC = /^[0-9a-f]{64}$/;
const CAPABILITY = 'igentic.own_app.status.read';
const ENTRIES = new Set([
  'chatgpt-site', 'shortcuts-chatgpt', 'siri-shortcut',
  'igentic-app', 'local-model', 'manual-client'
]);
const ROUTES = new Set([
  'cellular-foreground', 'coredevice-usb', 'coredevice-wifi', 'local-shortcuts'
]);
const OUTCOMES = new Set(['definitely-not-sent', 'sent-unconfirmed', 'transport-acknowledged']);
const EXACT = (obj, keys) =>
  obj !== null && typeof obj === 'object' && !Array.isArray(obj)
  && Object.keys(obj).length === keys.length
  && keys.every(key => Object.hasOwn(obj, key));
const invalid = () => { throw Error('invalidAgentLoopTransition'); };
const receiptInvalid = () => { throw Error('invalidAgentLoopReceipt'); };

function requireKey(key) {
  if (!Buffer.isBuffer(key) || key.length !== 32
      || key.every(x => x === key[0])) throw Error('invalidLoopReceiptKey');
}
function normalizeReceipt(body) {
  if (!EXACT(body, [
    'schema', 'kind', 'requestId', 'capability', 'nonce', 'observedAt', 'status'
  ]) || body.schema !== 1 || body.kind !== 'read-only-device-key-ack'
      || typeof body.requestId !== 'string' || !UUID.test(body.requestId)
      || body.capability !== CAPABILITY
      || typeof body.nonce !== 'string' || !UUID.test(body.nonce)
      || !Number.isSafeInteger(body.observedAt) || body.observedAt < 0
      || body.status !== 'key-holder-reports-read') receiptInvalid();
  return {
    schema: 1, kind: 'read-only-device-key-ack', requestId: body.requestId,
    capability: CAPABILITY, nonce: body.nonce, observedAt: body.observedAt,
    status: 'key-holder-reports-read'
  };
}
const signBody = (key, body) =>
  createHmac('sha256', key).update(
    'igentic-device-receipt-key-proof-v1\n' +
    JSON.stringify(normalizeReceipt(body))
  ).digest('hex');

/**
 * Protocol fixture signer. Must run ONLY on an independently trusted,
 * owner-enrolled iOS origin in any future deployment. Local Node tests using
 * this signer prove crypto parity, not that an iPhone did anything.
 */
export function signReadOnlyDeviceKeyReceipt({ key, requestId, nonce, observedAt }) {
  requireKey(key);
  const body = normalizeReceipt({
    schema: 1, kind: 'read-only-device-key-ack',
    requestId, capability: CAPABILITY, nonce, observedAt,
    status: 'key-holder-reports-read'
  });
  return { body, signature: signBody(key, body) };
}

/**
 * Single-task state machine. Admission must be wired to an authenticated
 * owner-relay proposal verifier, ideally a durable replay ledger.
 *
 * No methods send/poll a task, call an AI provider, handle iOS approvals, or
 * verify that the receipt key lives on a real physical iPhone.
 */
export function createTransportNeutralAgentLoop({
  admission, receiptKey, nowSeconds = () => Math.floor(Date.now() / 1000),
  deliveryAttemptMarker
} = {}) {
  if (!admission || typeof admission.admit !== 'function'
      || typeof nowSeconds !== 'function'
      || (deliveryAttemptMarker !== undefined
        && (!deliveryAttemptMarker
          || typeof deliveryAttemptMarker.markPrepared !== 'function'))) invalid();
  requireKey(receiptKey);
  const trustedReceiptKey = Buffer.from(receiptKey);
  let state = 'empty', task = null, transport = null;
  let attemptCount = 0, authenticatedReceipt = false;
  let deliveryAttempted = false;
  // A sent-but-unconfirmed attempt may later receive a valid key receipt.
  // This flag never permits retry or a physical device-success claim.
  let lateReceiptAllowed = false;
  const now = () => {
    const t = nowSeconds();
    if (!Number.isSafeInteger(t) || t < 0) throw Error('invalidAgentLoopClock');
    return t;
  };
  const snapshot = () => {
    expire();
    return Object.freeze({
    schema: 1,
    requestId: task?.requestId ?? null,
    capability: task?.capability ?? null,
    entryPoint: task?.entryPoint ?? null,
    transport,
    state,
    deliveryAttempted,
    attemptCount,
    receiptKeyAuthenticated: authenticatedReceipt,
    // No local protocol stage can assert a physical iPhone or actual action.
    actionExecuted: false, ownerApproved: false,
    iPhoneConnected: 'not-checked',
    deviceReceipt: authenticatedReceipt ? 'key-authenticated-not-device-attested' : 'none',
    automaticRetryAllowed: false
    });
  };
  const match = id => task && typeof id === 'string' && id === task.requestId;
  const expire = (sampledTime) => {
    if (!task) return false;
    if ((sampledTime ?? now()) < task.expiresAt) return false;
    lateReceiptAllowed = false;
    if (!['receipt-key-authenticated', 'cancelled-local', 'outcome-unknown',
          'expired-before-send'].includes(state)) {
      // Once a payload was handed to an adapter, a crash or timeout may
      // happen after a send but before recordTransport. Never turn that
      // unobserved send into the stronger "expired-before-send" assertion.
      state = (deliveryAttempted || state === 'delivery-prepared-not-sent')
        ? 'outcome-unknown' : 'expired-before-send';
    }
    return true;
  };
  return Object.freeze({
    snapshot,
    start({ envelope, entryPoint } = {}) {
      if (state !== 'empty' || !ENTRIES.has(entryPoint)) invalid();
      const accepted = admission.admit(envelope);
      // Never trust an arbitrary claim that admission authorized an iOS action.
      if (!accepted || accepted.state !== 'authenticated-proposal-only'
          || accepted.capability !== CAPABILITY
          || accepted.actionExecuted !== false
          || accepted.ownerApproved !== false
          || accepted.iPhoneConnected !== 'not-checked'
          || accepted.deviceReceipt !== 'none'
          || accepted.requestId !== envelope?.body?.requestId
          || !Number.isSafeInteger(accepted.expiresAt)
          || accepted.expiresAt <= now()
          || accepted.expiresAt - envelope.body.issuedAt > 60) invalid();
      task = {
        requestId: accepted.requestId,
        capability: accepted.capability,
        expiresAt: accepted.expiresAt,
        issuedAt: envelope.body.issuedAt,
        entryPoint
      };
      state = 'awaiting-manual-delivery';
      return snapshot();
    },
    prepareDelivery({ requestId, route } = {}) {
      if (!match(requestId) || !ROUTES.has(route)
          || state !== 'awaiting-manual-delivery' || expire()) invalid();
      // Bind the eventual key-authenticated acknowledgement to this exact
      // delivery preparation, not merely a valid owner task ID. This
      // challenge is local protocol data, never owner approval or attestation.
      const receiptNonce = randomUUID();
      // An optional local crash guard MUST persist the may-have-been-sent
      // marker before returning a payload that an adapter could dispatch.
      // If persistence fails, leave the loop awaiting delivery and fail closed.
      if (deliveryAttemptMarker !== undefined && deliveryAttemptMarker.markPrepared({
        requestId: task.requestId, receiptNonce, route
      }) !== true) invalid();
      task.receiptNonce = receiptNonce;
      transport = route;
      attemptCount += 1;
      state = 'delivery-prepared-not-sent';
      // Persistence can cross the deadline. Keep the durable uncertainty
      // boundary, but never release an already expired payload to an adapter.
      if (expire()) invalid();
      // This intentionally does not expose an executable command or private
      // input. A separate adapter must do the actual transport.
      return Object.freeze({
        schema: 1, requestId: task.requestId,
        capability: CAPABILITY, route,
        receiptNonce: task.receiptNonce,
        status: 'prepared-not-sent', actionExecuted: false,
        iPhoneConnected: 'not-checked'
      });
    },
    recordTransport({ requestId, outcome } = {}) {
      if (!match(requestId) || state !== 'delivery-prepared-not-sent'
          || !OUTCOMES.has(outcome)) invalid();
      if (expire()) return snapshot();
      if (outcome === 'definitely-not-sent') {
        state = 'not-sent'; // manual intervention; never automatic retry
      } else if (outcome === 'sent-unconfirmed') {
        deliveryAttempted = true;
        lateReceiptAllowed = true;
        state = 'outcome-unknown'; // no speculative resend
      } else {
        deliveryAttempted = true;
        state = 'awaiting-key-authenticated-receipt';
      }
      return snapshot();
    },
    acceptKeyReceipt(envelope) {
      // An unknown delivery is not permission to retry, but an independently
      // authenticated, nonce-matched late receipt may resolve the uncertainty
      // while this exact attempt's TTL is still open.
      if (state !== 'awaiting-key-authenticated-receipt'
          && !(state === 'outcome-unknown' && lateReceiptAllowed)) invalid();
      if (expire()) return snapshot();
      if (!EXACT(envelope, ['body', 'signature'])
          || typeof envelope.signature !== 'string' || !MAC.test(envelope.signature))
        receiptInvalid();
      const body = normalizeReceipt(envelope.body);
      const receiptCheckTime = now();
      // Close the receipt window on any observed expiry, even if a later
      // clock reading rolls back into the original validity interval.
      if (expire(receiptCheckTime)) return snapshot();
      if (!match(body.requestId) || body.nonce !== task.receiptNonce
          || body.observedAt < task.issuedAt
          || body.observedAt > receiptCheckTime + 5
          || body.observedAt >= task.expiresAt) receiptInvalid();
      const supplied = Buffer.from(envelope.signature, 'hex');
      const expected = Buffer.from(signBody(trustedReceiptKey, body), 'hex');
      if (supplied.length !== expected.length
          || !timingSafeEqual(supplied, expected)) receiptInvalid();
      // A valid signature cannot revive a task whose deadline passed
      // during verification. Commit the receipt only inside its TTL.
      if (expire()) return snapshot();
      authenticatedReceipt = true;
      lateReceiptAllowed = false;
      state = 'receipt-key-authenticated';
      // Still not "executed", "device verified", or a ChatGPT reply. The
      // independent physical device, policy and owner receipts are missing.
      return snapshot();
    },
    cancel({ requestId } = {}) {
      // A prepared payload may already be at a transport adapter. Only
      // cancel before preparation, or after an explicit definitely-not-sent
      // report. Otherwise the outcome must remain uncertain, not cancelled.
      if (!match(requestId) || !['awaiting-manual-delivery',
          'not-sent'].includes(state)
          || expire()) invalid();
      state = 'cancelled-local';
      return snapshot();
    },
    timeout() {
      expire();
      return snapshot();
    }
  });
}
