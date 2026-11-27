import test from 'node:test';
import assert from 'node:assert/strict';
import { validateOwnerTaskResult } from '../src/owner-result-boundary.mjs';

const id = '00000000-0000-4000-8000-000000000001';
const other = '00000000-0000-4000-8000-000000000002';
const pending = { requestId: id, state: 'outcome-unknown',
  receiptKeyAuthenticated: false, deviceReceipt: 'none', actionExecuted: false,
  ownerApproved: false, iPhoneConnected: 'not-checked' };
const receipt = { ...pending, state: 'receipt-key-authenticated',
  receiptKeyAuthenticated: true, deviceReceipt: 'key-authenticated-not-device-attested' };

test('valid bounded result and unknown task', () => {
  assert.equal(validateOwnerTaskResult(id, null), null);
  assert.deepEqual(validateOwnerTaskResult(id, pending), pending);
  assert.deepEqual(validateOwnerTaskResult(id, receipt), receipt);
  for (const state of ['awaiting-manual-delivery', 'delivery-prepared-not-sent',
    'not-sent', 'awaiting-key-authenticated-receipt', 'cancelled-local', 'expired-before-send']) {
    assert.deepEqual(validateOwnerTaskResult(id, {...pending, state}), {...pending, state});
  }
});
test('wrong task, invalid result and private extras fail closed', () => {
  for (const value of [undefined, [], {}, {...pending, requestId: other},
    {...pending, state: 'complete'}, {...pending, prompt: 'SYNTHETIC_PRIVATE_SENTINEL'},
    {...pending, requestId: undefined}, {...pending, iPhoneConnected: true}]) {
    assert.throws(() => validateOwnerTaskResult(id, value), /invalidOwnerTaskResult/);
  }
  assert.throws(() => validateOwnerTaskResult('invalid', null), /invalidOwnerTaskResult/);
});
test('no contradictory receipt, execution, or approval claim', () => {
  for (const value of [{...pending, receiptKeyAuthenticated: true},
    {...receipt, receiptKeyAuthenticated: false}, {...receipt, deviceReceipt: 'none'},
    {...pending, deviceReceipt: 'key-authenticated-not-device-attested'},
    {...receipt, actionExecuted: true}, {...receipt, ownerApproved: true}]) {
    assert.throws(() => validateOwnerTaskResult(id, value), /invalidOwnerTaskResult/);
  }
});
