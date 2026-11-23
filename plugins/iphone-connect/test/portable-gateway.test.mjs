import test from 'node:test';
import assert from 'node:assert/strict';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import { startPortableGateway } from '../src/portable-gateway.mjs';

test('portable Streamable HTTP MCP works for generic clients read-only', async t => {
  const gateway = await startPortableGateway();
  t.after(() => gateway.close());
  assert.equal(gateway.host, '127.0.0.1');
  const client = new Client({ name: 'generic-mcp-client', version: '1.0.0' });
  t.after(() => client.close());
  await client.connect(new StreamableHTTPClientTransport(
    new URL('http://127.0.0.1:' + gateway.port + '/mcp')
  ));
  const tools = (await client.listTools()).tools;
  assert.deepEqual(tools.map(x => x.name).sort(),
    ['iphone_connection_report', 'iphone_get_capabilities']);
  assert.ok(tools.every(x => x.annotations.readOnlyHint === true));
  assert.ok(tools.every(x => x.annotations.destructiveHint === false));
  const result = await client.callTool({ name: 'iphone_connection_report', arguments: {} });
  assert.notEqual(result.isError, true);
  assert.equal(result.structuredContent.data.backend, 'portable-preview');
  assert.equal(result.structuredContent.data.deviceStatus, 'not-observed');
  assert.equal(result.structuredContent.data.actionReadiness, 'not-verified');
  assert.equal(result.structuredContent.data.routes.length, 5);
  assert.equal(result.structuredContent.data.routes[2].state, 'companion-readiness-not-verified');
  assert.doesNotMatch(JSON.stringify(result), /udid|serial|privateNetwork/i);
  const caps = await client.callTool({ name: 'iphone_get_capabilities', arguments: {} });
  assert.deepEqual(caps.structuredContent.data.actions, []);
  assert.equal(caps.structuredContent.data.deviceControl, 'not-connected');
  const unavailable = await client.callTool({ name: 'iphone_execute_action', arguments: {} });
  assert.equal(unavailable.isError, true);
});

test('portable HTTP endpoint stays on loopback and rejects other methods', async t => {
  const gateway = await startPortableGateway();
  t.after(() => gateway.close());
  const url = 'http://127.0.0.1:' + gateway.port;
  assert.equal((await fetch(url + '/')).status, 404);
  const get = await fetch(url + '/mcp');
  assert.equal(get.status, 405);
  assert.equal(get.headers.get('allow'), 'POST');
  assert.equal((await fetch(url + '/mcp', { method: 'DELETE' })).status, 405);
  const tooBig = await fetch(url + '/mcp', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: 'x'.repeat(65537)
  });
  assert.equal(tooBig.status, 413);
  await assert.rejects(startPortableGateway({ port: -1 }), /invalidPort/);
});
