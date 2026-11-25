import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import {
  prepareSignedReadOnlyProposal, createOwnerProposalAdmission
} from '../src/authenticated-task-envelope.mjs';
import {
  createTransportNeutralAgentLoop, signReadOnlyDeviceKeyReceipt
} from '../src/agent-loop-protocol.mjs';

const T = 2_000_000_000;
function fixture() {
  const ownerKey = randomBytes(32);
  const receiptKey = randomBytes(32);
  let current = T;
  const nowSeconds = () => current;
  const admission = createOwnerProposalAdmission({
    key: ownerKey, nowSeconds
  });
  const loop = createTransportNeutralAgentLoop({
    admission, receiptKey, nowSeconds
  });
  const envelope = prepareSignedReadOnlyProposal({
    key: ownerKey, issuedAt: current
  });
  const requestId = envelope.body.requestId;
  loop.start({ envelope, entryPoint: 'chatgpt-site' });
  const preparation = loop.prepareDelivery({
    requestId, route: 'cellular-foreground'
  });
  const sign = (options = {}) => signReadOnlyDeviceKeyReceipt({
    key: receiptKey, requestId, observedAt: current,
    nonce: preparation.receiptNonce, ...options
  });
  return {
    loop, requestId, preparation, sign,
    setTime(next) { current = next; }
  };
}

test('an uncertain delivery can be resolved by a valid late key receipt, without retry', () => {
  const f = fixture();
  const pending = f.loop.recordTransport({
    requestId: f.requestId, outcome: 'sent-unconfirmed'
  });
  assert.equal(pending.state, 'outcome-unknown');
  assert.equal(pending.actionExecuted, false);
  assert.equal(pending.automaticRetryAllowed, false);
  assert.throws(() => f.loop.prepareDelivery({
    requestId: f.requestId, route: 'cellular-foreground'
  }), /invalidAgentLoopTransition/);

  const accepted = f.loop.acceptKeyReceipt(f.sign());
  assert.equal(accepted.state, 'receipt-key-authenticated');
  assert.equal(accepted.receiptKeyAuthenticated, true);
  assert.equal(accepted.actionExecuted, false);
  assert.equal(accepted.ownerApproved, false);
  assert.equal(accepted.iPhoneConnected, 'not-checked');
  assert.equal(accepted.deviceReceipt, 'key-authenticated-not-device-attested');
});

test('a mismatched signed nonce cannot resolve uncertain delivery', () => {
  const f = fixture();
  f.loop.recordTransport({
    requestId: f.requestId, outcome: 'sent-unconfirmed'
  });
  assert.throws(() => f.loop.acceptKeyReceipt(
    f.sign({ nonce: randomUUID() })
  ), /invalidAgentLoopReceipt/);
  assert.equal(f.loop.snapshot().state, 'outcome-unknown');
  assert.equal(f.loop.snapshot().receiptKeyAuthenticated, false);
  assert.equal(f.loop.acceptKeyReceipt(f.sign()).state, 'receipt-key-authenticated');
});

test('an expired uncertain delivery does not accept even a valid late key receipt', () => {
  const f = fixture();
  f.loop.recordTransport({requestId:f.requestId, outcome:'sent-unconfirmed'});
  f.setTime(T + 61);
  const s = f.loop.acceptKeyReceipt(f.sign({observedAt: T + 59}));
  assert.equal(s.state, 'outcome-unknown');
  assert.equal(s.receiptKeyAuthenticated, false);
  assert.equal(s.actionExecuted, false);
});

test('wrong signing key cannot resolve uncertain delivery', () => {
  const f = fixture();
  f.loop.recordTransport({requestId:f.requestId, outcome:'sent-unconfirmed'});
  const forged = f.sign({key:randomBytes(32)});
  assert.throws(() => f.loop.acceptKeyReceipt(forged), /invalidAgentLoopReceipt/);
  assert.equal(f.loop.snapshot().state, 'outcome-unknown');
  assert.equal(f.loop.snapshot().automaticRetryAllowed, false);
});

test('expired receipt window cannot be reopened by clock moving backwards', () => {
  const f = fixture();
  f.loop.recordTransport({requestId:f.requestId, outcome:'sent-unconfirmed'});
  f.setTime(T + 61);
  assert.equal(f.loop.timeout().state, 'outcome-unknown');
  f.setTime(T + 10);
  assert.throws(() => f.loop.acceptKeyReceipt(f.sign()),
    /invalidAgentLoopTransition/);
  assert.equal(f.loop.snapshot().receiptKeyAuthenticated, false);
});

test('an acknowledged delivery that expired cannot become a late receipt', () => {
  const f = fixture();
  f.loop.recordTransport({requestId:f.requestId, outcome:'transport-acknowledged'});
  f.setTime(T + 61);
  assert.equal(f.loop.timeout().state, 'outcome-unknown');
  f.setTime(T + 10);
  assert.throws(() => f.loop.acceptKeyReceipt(f.sign()),
    /invalidAgentLoopTransition/);
  assert.equal(f.loop.snapshot().actionExecuted, false);
});


test('receipt verification crossing expiry never authenticates or reopens the window', () => {
  for (const outcome of ['transport-acknowledged', 'sent-unconfirmed']) {
    for (const expiryRead of [2, 3]) {
      const ownerKey = randomBytes(32), receiptKey = randomBytes(32);
      let armed = false, reads = 0;
      const envelope = prepareSignedReadOnlyProposal({key:ownerKey, issuedAt:T});
      const requestId = envelope.body.requestId;
      // Simulate one clock reading at the deadline, followed by rollback.
      const nowSeconds = () => armed && ++reads === expiryRead
        ? envelope.body.expiresAt : T;
      const loop = createTransportNeutralAgentLoop({
        admission: createOwnerProposalAdmission({key:ownerKey, nowSeconds}),
        receiptKey, nowSeconds
      });
      loop.start({envelope, entryPoint:'chatgpt-site'});
      const prepared = loop.prepareDelivery({requestId, route:'cellular-foreground'});
      loop.recordTransport({requestId, outcome});
      const receipt = signReadOnlyDeviceKeyReceipt({
        key:receiptKey, requestId, nonce:prepared.receiptNonce, observedAt:T
      });
      armed = true;
      const result = loop.acceptKeyReceipt(receipt);
      assert.equal(result.state, 'outcome-unknown');
      assert.equal(result.receiptKeyAuthenticated, false);
      assert.equal(result.actionExecuted, false);
      assert.equal(result.automaticRetryAllowed, false);
      assert.throws(() => loop.acceptKeyReceipt(receipt), /invalidAgentLoopTransition/);
      assert.equal(loop.snapshot().state, 'outcome-unknown');
    }
  }
});
