import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { prepareSignedReadOnlyProposal, createOwnerProposalAdmission }
  from '../src/authenticated-task-envelope.mjs';

const key = () => randomBytes(32);
const clock = { value: 2_000_000_000 };
const sign = (secret, options = {}) => prepareSignedReadOnlyProposal({
  key: secret, issuedAt: clock.value, ...options
});

test('valid signed read-only owner task remains an unexecuted proposal', () => {
  const secret = key();
  const admission = createOwnerProposalAdmission({
    key: secret, nowSeconds: () => clock.value
  });
  const envelope = sign(secret);
  const result = admission.admit(envelope);
  assert.equal(result.schema, 1);
  assert.equal(result.capability, 'igentic.own_app.status.read');
  assert.equal(result.state, 'authenticated-proposal-only');
  assert.equal(result.iPhoneConnected, 'not-checked');
  assert.equal(result.actionExecuted, false);
  assert.equal(result.ownerApproved, false);
  assert.equal(result.deviceReceipt, 'none');
  assert.equal(result.requestId, envelope.body.requestId);
  assert.equal(result.expiresAt, envelope.body.expiresAt);
  assert.ok(Object.isFrozen(result));
});

test('envelope cannot gain action, extra params, privileges or mock receipt', () => {
  const secret = key();
  const admission = createOwnerProposalAdmission({
    key: secret, nowSeconds: () => clock.value
  });
  for (const mutation of [
    body => { body.capability = 'reminder.create'; },
    body => { body.parameters = { text: 'SYNTHETIC_PRIVATE_VALUE' }; },
    body => { body.ownerApproved = true; },
    body => { body.actionExecuted = true; },
    body => { body.kind = 'write-task'; },
    body => { body.requestId = 'not-uuid'; },
    body => { body.expiresAt += 600; },
    body => { body.parameters = null; }
  ]) {
    const envelope = sign(secret);
    mutation(envelope.body);
    assert.throws(() => admission.admit(envelope), /invalidTaskEnvelope/);
  }
  for (const extra of [
    { approved: true }, { deviceConnected: true }, { action: 'execute' },
    { privateText: 'SYNTHETIC_PRIVATE_VALUE' }
  ]) {
    const envelope = { ...sign(secret), ...extra };
    assert.throws(() => admission.admit(envelope), /invalidTaskEnvelope/);
  }
  assert.throws(() => admission.admit(null), /invalidTaskEnvelope/);
  assert.throws(() => admission.admit({}), /invalidTaskEnvelope/);
});

test('MAC authenticates a separate owner key, and exact replay is rejected', () => {
  const a = key(), b = key();
  const admission = createOwnerProposalAdmission({
    key: a, nowSeconds: () => clock.value
  });
  assert.throws(() => admission.admit(sign(b)), /unauthenticatedTaskEnvelope/);
  const envelope = sign(a);
  const wrong = { ...envelope, signature: '0'.repeat(64) };
  assert.throws(() => admission.admit(wrong), /unauthenticatedTaskEnvelope/);
  admission.admit(envelope);
  assert.throws(() => admission.admit(envelope), /replayedTaskEnvelope/);
  // No signature or device consent can be inferred from a merely valid UUID.
  assert.throws(() => admission.admit({ ...sign(a), signature: 'abc' }), /invalidTaskEnvelope/);
});

test('admission key is pinned even if the caller mutates its Buffer', () => {
  const supplied = key();
  const original = Buffer.from(supplied);
  const admission = createOwnerProposalAdmission({
    key: supplied, nowSeconds: () => clock.value
  });
  const authenticEnvelope = sign(original);
  supplied.fill(0);
  assert.equal(admission.admit(authenticEnvelope).state, 'authenticated-proposal-only');
  assert.throws(() => admission.admit(sign(supplied)),
    /unauthenticatedTaskEnvelope/);
});

test('obviously predictable constant-byte relay keys fail closed', () => {
  const invalidKeys = [Buffer.alloc(32), Buffer.alloc(32, 0xff),
    Buffer.alloc(32, 0x41)];
  for (const weakKey of invalidKeys) {
    assert.throws(() => createOwnerProposalAdmission({ key: weakKey }),
      /invalidOwnerRelayKey/);
    assert.throws(() => prepareSignedReadOnlyProposal({
      key: weakKey, issuedAt: clock.value
    }), /invalidOwnerRelayKey/);
  }
  // An ordinary random key is accepted; this does not prove general entropy.
  const validKey = key();
  assert.equal(sign(validKey).body.capability, 'igentic.own_app.status.read');
});

test('short TTL, future/expired timestamps, and malformed IDs fail closed', () => {
  const secret = key();
  let now = clock.value;
  const admission = createOwnerProposalAdmission({ key: secret, nowSeconds: () => now });
  assert.throws(() => sign(secret, { ttlSeconds: 61 }), /invalidTaskEnvelope/);
  assert.throws(() => sign(secret, { ttlSeconds: 0 }), /invalidTaskEnvelope/);
  assert.throws(() => sign(secret, { issuedAt: -1 }), /invalidTaskEnvelope/);
  assert.throws(() => sign(secret, { requestId: 'SYNTHETIC_PRIVATE_VALUE' }), /invalidTaskEnvelope/);
  assert.throws(() => admission.admit(sign(secret, { issuedAt: now + 6 })),
    /expiredOrFutureTaskEnvelope/);
  assert.throws(() => admission.admit(sign(secret, { issuedAt: now - 60 })),
    /expiredOrFutureTaskEnvelope/);
  const short = sign(secret, { ttlSeconds: 1 });
  now++;
  assert.throws(() => admission.admit(short), /expiredOrFutureTaskEnvelope/);
});

test('bounded replay map never turns repeated proposals into device actions', () => {
  const secret = key();
  let now = clock.value;
  const admission = createOwnerProposalAdmission({
    key: secret, nowSeconds: () => now, maxInflight: 1
  });
  admission.admit(sign(secret, { issuedAt: now, ttlSeconds: 2 }));
  assert.throws(() => admission.admit(sign(secret, { issuedAt: now })),
    /ownerRelayCapacityReached/);
  now += 3;
  const newProposal = sign(secret, { issuedAt: now, requestId: randomUUID() });
  assert.equal(admission.admit(newProposal).actionExecuted, false);
});

test('no embedded network listener, iPhone control, or system credentials', () => {
  const source = readFileSync(
    new URL('../src/authenticated-task-envelope.mjs', import.meta.url), 'utf8'
  );
  assert.doesNotMatch(source, /from ['"]node:(?:http|https|net|child_process|fs)['"]/);
  assert.doesNotMatch(source, /process\.env|fetch\(|server\.listen\(|device\.install/);
  assert.throws(() => createOwnerProposalAdmission({ key: Buffer.alloc(0) }),
    /invalidOwnerRelayKey/);
  assert.throws(() => prepareSignedReadOnlyProposal({
    key: Buffer.alloc(0), issuedAt: clock.value
  }), /invalidOwnerRelayKey/);
});
