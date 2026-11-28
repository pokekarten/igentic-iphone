import test from 'node:test';
import assert from 'node:assert/strict';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { InMemoryTransport } from '@modelcontextprotocol/sdk/inMemory.js';
import { createServer } from '../src/server.mjs';
import { createPortableMcp } from '../src/portable-gateway.mjs';

const requestId = '00000000-0000-4000-8000-000000000001';
const otherId = '00000000-0000-4000-8000-000000000002';
const receipt = { requestId, state: 'receipt-key-authenticated',
  receiptKeyAuthenticated: true, deviceReceipt: 'key-authenticated-not-device-attested',
  actionExecuted: false, ownerApproved: false, iPhoneConnected: 'not-checked' };

for (const [label, create] of [
  ['local', lookupOwnerResult => createServer({}, { lookupOwnerResult })],
  ['portable', lookupOwnerResult => createPortableMcp({ lookupOwnerResult })]
]) {
  test(label + ' MCP refuses mismatched and overbroad owner results', async t => {
    let value = receipt;
    const server = create(async id => { assert.equal(id, requestId); return value; });
    const client = new Client({ name: 'owner-result-test', version: '1' });
    const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
    t.after(async () => { await client.close(); await server.close(); });
    await server.connect(serverTransport);
    await client.connect(clientTransport);
    const call = () => client.callTool({
      name: 'iphone_owner_task_result', arguments: { requestId }
    });
    assert.deepEqual((await call()).structuredContent, { data: { result: receipt } });
    value = null;
    assert.deepEqual((await call()).structuredContent, { data: { result: null } });
    for (const invalid of [{...receipt, requestId: otherId},
      {...receipt, prompt: 'SYNTHETIC_PRIVATE_SENTINEL'},
      {...receipt, actionExecuted: true}]) {
      value = invalid;
      const result = await call();
      assert.equal(result.isError, true);
      assert.doesNotMatch(JSON.stringify(result), /SYNTHETIC_PRIVATE_SENTINEL|00000000-0000-4000-8000-000000000002/);
    }
  });
}
