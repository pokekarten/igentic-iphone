// Local single-task relay seam. No listener, identity provider, enrollment,
// model call or device execution. Access keys represent pre-provisioned
// roles only; a future authenticated TLS adapter must keep them secret.
import { timingSafeEqual } from 'node:crypto';
import { prepareSignedReadOnlyProposal } from './authenticated-task-envelope.mjs';
import { createDurableOwnerProposalAdmission } from './durable-task-admission.mjs';
import { createPrivateDeliveryAttemptMarker } from './delivery-attempt-marker.mjs';
import { createTransportNeutralAgentLoop } from './agent-loop-protocol.mjs';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const validKey = k => Buffer.isBuffer(k) && k.length === 32 && !k.every(b => b === k[0]);
const reject = () => { throw Error('relayAccessDenied'); };

export function createOwnerDeviceRelay({
  ownerAccessKey, deviceAccessKey, proposalKey, receiptKey, markerKey,
  databasePath, markerDirectory, nowSeconds = () => Math.floor(Date.now() / 1000)
} = {}) {
  const keys = [ownerAccessKey, deviceAccessKey, proposalKey, receiptKey, markerKey];
  if (!keys.every(validKey) || keys.some((k, i) => keys.slice(i + 1).some(other => timingSafeEqual(k, other)))
      || typeof nowSeconds !== 'function') throw Error('invalidRelayConfig');
  const [owner, device, proposal, receipt, markerSecret] = keys.map(k => Buffer.from(k));
  const admission = createDurableOwnerProposalAdmission({key: proposal, databasePath, nowSeconds,
    relayRoles:{ownerAccessKey:owner,deviceAccessKey:device,receiptKey:receipt,markerKey:markerSecret}});
  let marker;
  try { marker = createPrivateDeliveryAttemptMarker({directory: markerDirectory, key: markerSecret}); }
  catch(error) { admission.close(); throw error; }
  const loop = createTransportNeutralAgentLoop({admission, receiptKey: receipt, nowSeconds,
    deliveryAttemptMarker: marker});
  let envelope = null, claimed = false, released = false, closed = false;
  const auth = (supplied, expected) => {
    if (closed || !Buffer.isBuffer(supplied) || supplied.length !== 32 ||
        !timingSafeEqual(supplied, expected)) reject();
  };
  const clock = () => {
    const t = nowSeconds();
    if (!Number.isSafeInteger(t) || t < 0) throw Error('invalidRelayClock');
    return t;
  };
  function requireActiveDevice() {
    if (admission.isRevoked()) reject();
  }
  function status(key) {
    auth(key, owner);
    const revoked = admission.isRevoked();
    let state = loop.snapshot();
    if (revoked && !claimed && state.state === 'awaiting-manual-delivery') {
      state = loop.cancel({requestId:state.requestId});
    }
    return claimed && !released
      ? Object.freeze({...state,state:'outcome-unknown',automaticRetryAllowed:false})
      : state;
  }
  return Object.freeze({
    submit(key, requestId) {
      auth(key, owner);
      requireActiveDevice();
      if (envelope !== null || claimed || typeof requestId !== 'string' || !UUID.test(requestId))
        throw Error('invalidRelaySubmission');
      // A marker survives the shorter replay-ledger TTL. Never reissue a
      // request ID for which delivery was previously prepared.
      if (marker.recover({requestId}) !== null) throw Error('relayDeliveryAlreadyUncertain');
      const signed = prepareSignedReadOnlyProposal({key:proposal, requestId, issuedAt:clock()});
      const state = loop.start({envelope:signed, entryPoint:'chatgpt-site'});
      envelope = signed;
      return state;
    },
    status,
    revokeDevice(key) {
      auth(key, owner);
      admission.revoke();
      // Do not erase historical receipt evidence or claim that a prepared
      // payload was recalled. An unclaimed pending task can be cancelled.
      const current = loop.snapshot();
      if (!claimed && current.state === 'awaiting-manual-delivery')
        loop.cancel({requestId:current.requestId});
      return Object.freeze({schema:1,deviceRevoked:true,automaticRetryAllowed:false,
        actionExecuted:false,ownerApproved:false});
    },
    result(key, requestId) {
      const current = status(key);
      if (typeof requestId !== 'string' || !UUID.test(requestId)) throw Error('invalidRelayRequestId');
      if (current.requestId !== requestId) return null;
      // Explicit external projection. Internal status fields may grow independently.
      const {state, receiptKeyAuthenticated, deviceReceipt, actionExecuted, ownerApproved, iPhoneConnected} = current;
      return Object.freeze({requestId, state, receiptKeyAuthenticated, deviceReceipt, actionExecuted, ownerApproved, iPhoneConnected});
    },
    cancel(key, requestId) {
      auth(key, owner);
      admission.isRevoked();
      if (claimed) throw Error('invalidAgentLoopTransition');
      return loop.cancel({requestId});
    },
    claim(key) {
      auth(key, device);
      requireActiveDevice();
      if (claimed || !envelope || loop.snapshot().state !== 'awaiting-manual-delivery') return null;
      // Once an attempt begins, never release another payload from this
      // instance, even if marker persistence or delivery outcome is uncertain.
      claimed = true;
      const {requestId, issuedAt, expiresAt} = envelope.body;
      const prepared = loop.prepareDelivery({requestId, route:'cellular-foreground'});
      const state = loop.recordTransport({requestId, outcome:'sent-unconfirmed'});
      const now = clock();
      if (!state.deliveryAttempted || now < issuedAt || now >= expiresAt) {
        loop.timeout();
        return null;
      }
      // Mark uncertainty before returning; losing this response is not
      // grounds for replay. Only the device role receives the nonce/wire.
      requireActiveDevice();
      released = true;
      return Object.freeze({canonicalWire:JSON.stringify(envelope),
        receiptNonce:prepared.receiptNonce, requestId, expiresAt});
    },
    acceptReceipt(key, proof) {
      auth(key, device);
      requireActiveDevice();
      if (!released) throw Error('invalidAgentLoopTransition');
      return loop.acceptKeyReceipt(proof);
    },
    recover(key, requestId) {
      auth(key, owner);
      admission.isRevoked();
      return marker.recover({requestId});
    },
    close(key) {
      auth(key, owner);
      closed = true;
      admission.close();
      for (const k of [owner, device, proposal, receipt, markerSecret]) k.fill(0);
      envelope = null;
    }
  });
}
