import test from 'node:test';
import assert from 'node:assert/strict';
import { build } from 'esbuild';
import { fileURLToPath } from 'node:url';
import { handleSitesMcp } from '../../igentic-chatgpt-iphone/sites-reference/mcp-handler.mjs';
import { HANDOFF_ACTIONS, prepareChatGPTHandoff } from '../src/chatgpt-handoff.mjs';

const request = (rpc, options = {}) => new Request('https://owner-site.invalid/mcp', {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify(rpc), ...options
});
const call = (method, params, id = 1) => ({ jsonrpc: '2.0', id, method, ...(params === undefined ? {} : { params }) });

test('Sites wire protocol discovers one read-only tool and returns all canonical handoffs', async () => {
  const discovery = await (await handleSitesMcp(request(call('server/discover')))).json();
  assert.deepEqual(discovery.result, { supportedVersions: ['2026-07-28'], capabilities: { tools: {} } });
  const listing = await (await handleSitesMcp(request(call('tools/list')))).json();
  assert.equal(listing.result.tools.length, 1);
  const tool = listing.result.tools[0];
  assert.equal(tool.annotations.readOnlyHint, true);
  assert.equal(tool.annotations.destructiveHint, false);
  for (const action of HANDOFF_ACTIONS) {
    const response = await handleSitesMcp(request(call('tools/call', {
      name: tool.name, arguments: { action }
    }, action)));
    assert.equal(response.headers.get('cache-control'), 'no-store');
    const result = await response.json();
    assert.equal(result.id, action);
    assert.equal(result.result.isError, false);
    assert.deepEqual(result.result.structuredContent.data, prepareChatGPTHandoff(action));
    assert.deepEqual(JSON.parse(result.result.content[0].text), prepareChatGPTHandoff(action));
  }
});

test('Sites rejects unsupported tools, injected arguments and write intent without reflecting content', async () => {
  for (const params of [
    { name: 'iphone_execute_action', arguments: { action: 'diagnostics' } },
    { name: 'iphone_chatgpt_handoff', arguments: { action: 'delete-contacts' } },
    { name: 'iphone_chatgpt_handoff', arguments: { action: 'diagnostics', text: 'SYNTHETIC_PRIVATE_SENTINEL' } },
    { name: 'iphone_chatgpt_handoff', arguments: { action: 'diagnostics', approved: true } },
    { name: 'iphone_chatgpt_handoff', arguments: { action: 'https://example.invalid' } }
  ]) {
    const reply = await handleSitesMcp(request(call('tools/call', params)));
    const body = await reply.text();
    assert.equal(JSON.parse(body).result.isError, true);
    assert.doesNotMatch(body, /SYNTHETIC_PRIVATE_SENTINEL|delete-contacts|https:/);
  }
});

test('Sites validates HTTP and JSON-RPC boundaries without executing notifications or batches', async () => {
  for (const method of ['GET', 'DELETE', 'OPTIONS']) {
    const response = await handleSitesMcp(new Request('https://owner-site.invalid/mcp', { method }));
    assert.equal(response.status, 405);
    assert.equal(response.headers.get('allow'), 'POST');
  }
  assert.equal((await handleSitesMcp(new Request('https://owner-site.invalid/mcp?secret=x'))).status, 404);
  assert.equal((await handleSitesMcp(request({}, { headers: { 'content-type': 'text/plain' } }))).status, 415);
  assert.equal((await handleSitesMcp(request({}, { body: '{' }))).status, 400);
  for (const rpc of [null, [], [call('tools/list')], {},
    { jsonrpc: '2.0', method: 'tools/call', params: { name: 'iphone_chatgpt_handoff', arguments: { action: 'diagnostics' } } },
    call('tools/list', {}, {}), { ...call('tools/list'), approved: true }]) {
    const response = await handleSitesMcp(request(rpc));
    assert.equal(response.status, 400);
    assert.equal((await response.json()).error.code, -32600);
  }
  for (const params of [[], null, { approved: true }]) {
    const result = await (await handleSitesMcp(request(call('tools/list', params)))).json();
    assert.equal(result.error.code, -32602);
  }
  const unknown = await (await handleSitesMcp(request(call('resources/read', {})))).json();
  assert.equal(unknown.error.code, -32601);
});

test('Sites bounds streamed input even without Content-Length and cancels excess data', async () => {
  let cancelled = false;
  const body = new ReadableStream({
    pull(controller) { controller.enqueue(new Uint8Array(1024)); },
    cancel() { cancelled = true; }
  });
  const response = await handleSitesMcp(request({}, { body, duplex: 'half' }));
  assert.equal(response.status, 413);
  assert.equal(cancelled, true);
});

test('built Worker serves the fixed page and MCP without network, secrets or device dependencies', async () => {
  const bundle = await build({
    entryPoints: [fileURLToPath(new URL('../../igentic-chatgpt-iphone/sites-reference/worker.mjs', import.meta.url))],
    bundle: true, write: false, format: 'esm', platform: 'browser',
    loader: { '.html': 'text' }, metafile: true
  });
  assert.equal(bundle.outputFiles.length, 1);
  assert.equal(Object.keys(bundle.metafile.inputs).length, 5);
  for (const file of Object.keys(bundle.metafile.inputs))
    assert.doesNotMatch(file, /native-coredevice|node_modules|oauth|server\.mjs/);
  const { default: worker } = await import('data:text/javascript;base64,' +
    Buffer.from(bundle.outputFiles[0].text).toString('base64'));
  const page = await worker.fetch(new Request('https://owner-site.invalid/'));
  assert.equal(page.status, 200);
  assert.match(page.headers.get('content-security-policy'), /default-src 'none'/);
  const html = await page.text();
  assert.equal([...html.matchAll(/href="igentic:\/\/handoff\/v1\//g)].length, 3);
  const response = await worker.fetch(request(call('tools/call', {
    name: 'iphone_chatgpt_handoff', arguments: { action: 'discovery' }
  }), { headers: { 'content-type': 'application/json',
    'oai-authenticated-user-email': 'SYNTHETIC_PRIVATE_SENTINEL' } }));
  const text = await response.text();
  assert.doesNotMatch(text, /SYNTHETIC_PRIVATE_SENTINEL/);
  assert.deepEqual(JSON.parse(text).result.structuredContent.data, prepareChatGPTHandoff('discovery'));
  assert.equal((await worker.fetch(new Request('https://owner-site.invalid/secret'))).status, 404);
});
