import test from 'node:test';
import assert from 'node:assert/strict';
import { signReadOnlyDeviceKeyReceipt } from '../src/agent-loop-protocol.mjs';

// Independent Swift test pins the same public, synthetic, non-production vector.
// This is a key possession fixture, NOT an iPhone action or device attestation.
const expected = '{"body":{"schema":1,"kind":"read-only-device-key-ack",'
  + '"requestId":"11111111-2222-4333-8444-555555555555",'
  + '"capability":"igentic.own_app.status.read",'
  + '"nonce":"22222222-3333-4444-8555-666666666666",'
  + '"observedAt":2000000010,"status":"key-holder-reports-read"},'
  + '"signature":"5fab62c61d742fbf674ac743bbcce402f9c926bc125e0e39ff0ac60b8cf4e491"}';

test('Node key receipt matches Swift DEBUG-only canonical fixture', () => {
  const result = signReadOnlyDeviceKeyReceipt({
    key: Buffer.from(Array.from({ length:32 }, (_,i) => i)),
    requestId: '11111111-2222-4333-8444-555555555555',
    nonce: '22222222-3333-4444-8555-666666666666',
    observedAt: 2_000_000_010
  });
  assert.equal(JSON.stringify(result), expected);
  assert.equal(Object.hasOwn(result.body,'actionExecuted'), false);
  assert.equal(Object.hasOwn(result.body,'ownerApproved'), false);
});
