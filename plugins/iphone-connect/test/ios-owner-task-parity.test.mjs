import test from 'node:test';
import assert from 'node:assert/strict';
import { prepareSignedReadOnlyProposal } from '../src/authenticated-task-envelope.mjs';

// Paired with iOS AgentLoopRemoteTaskVerifierTests.swift. Test-only vector;
// the sequential bytes are public and MUST NEVER be used as an owner key.
const expectedWire = '{"body":{"schema":1,"kind":"read-only-task-proposal",'
  + '"requestId":"11111111-2222-4333-8444-555555555555",'
  + '"issuedAt":2000000000,"expiresAt":2000000060,'
  + '"capability":"igentic.own_app.status.read","parameters":{}},'
  + '"signature":"5109a32fd50436db89b96cd4970abd29626f0d0fd786fd71f79e0855821093b2"}';

test('Node owner-relay wire format pins exact Swift-compatible proposal vector', () => {
  const signed = prepareSignedReadOnlyProposal({
    key: Buffer.from(Array.from({length: 32}, (_, i) => i)),
    requestId: '11111111-2222-4333-8444-555555555555',
    issuedAt: 2_000_000_000,
    ttlSeconds: 60
  });
  assert.equal(JSON.stringify(signed), expectedWire);
  assert.equal(signed.body.capability, 'igentic.own_app.status.read');
  assert.deepEqual(signed.body.parameters, {});
});
