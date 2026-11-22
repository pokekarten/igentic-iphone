import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { ROOT } from '../src/paths.mjs';
import { readBusinessCatalog, listBusinessSolutions, getBusinessSolution } from '../src/b2b-catalog.mjs';

test('catalog is bounded, offline and all solutions are explicitly non-executing', async () => {
  const catalog = await readBusinessCatalog();
  const listing = await listBusinessSolutions();
  assert.equal(catalog.solutions.length, 6);
  assert.equal(listing.solutions.length, 6);
  assert.equal(listing.requiresDevice, false);
  assert.equal(listing.executionEnabled, false);
  for (const s of listing.solutions) {
    assert.equal(s.executionEnabled, false);
    const detail = await getBusinessSolution(s.slug);
    assert.equal(detail.backendConnected, false);
    assert.equal(detail.customerReady, false);
    assert.match(detail.detailMarkdown, /\*\*Today:\*\*/);
    assert.match(detail.detailMarkdown, /\*\*Missing before/);
  }
  await assert.rejects(getBusinessSolution('../../private'), { code: 'unknownSolution' });
});

test('official MCP client exposes B2B tools without opening device session', async t => {
  const state = await mkdtemp(join(tmpdir(), 'igentic-b2b-protocol-'));
  const transport = new StdioClientTransport({
    command: process.execPath, args: [join(ROOT, 'src/server.mjs')],
    env: { PATH: process.env.PATH, IGENTIC_IPHONE_BACKEND: 'fixture', IGENTIC_IPHONE_STATE_DIR: state },
    stderr: 'pipe'
  });
  const client = new Client({ name: 'b2b-test', version: '1.0.0' });
  t.after(async () => { await client.close(); await rm(state, { recursive: true, force: true }); });
  await client.connect(transport);
  const tools = (await client.listTools()).tools;
  assert.equal(tools.length, 12);
  for (const name of ['igentic_list_business_solutions', 'igentic_get_business_solution']) {
    const tool = tools.find(t => t.name === name);
    assert.ok(tool);
    assert.equal(tool.annotations.readOnlyHint, true);
    assert.equal(tool.annotations.destructiveHint, false);
  }
  const invoke = (name, args = {}) => client.callTool({ name, arguments: args });
  const list = await invoke('igentic_list_business_solutions');
  assert.equal(list.isError, undefined);
  assert.equal(list.structuredContent.data.solutions.length, 6);
  const detail = await invoke('igentic_get_business_solution', { slug: 'enterprise-agent-trust' });
  assert.equal(detail.isError, undefined);
  assert.equal(detail.structuredContent.data.executionEnabled, false);
  assert.equal((await invoke('igentic_get_business_solution', { slug: '../../private' })).isError, true);
  assert.equal((await invoke('igentic_list_business_solutions', { token: 'secret' })).isError, true);
  assert.equal((await invoke('igentic_get_business_solution', { slug: 'insurance-risk', execute: true })).isError, true);
});

test('catalog-only mode needs no physical config and fails closed for phone sessions', async t => {
  const state = await mkdtemp(join(tmpdir(), 'igentic-catalog-only-'));
  const transport = new StdioClientTransport({
    command: process.execPath, args: [join(ROOT, 'src/server.mjs')],
    env: {
      PATH: process.env.PATH,
      IGENTIC_IPHONE_BACKEND: 'catalog',
      IGENTIC_IPHONE_CONFIG: join(state, 'intentionally-missing-config.json'),
      IGENTIC_IPHONE_STATE_DIR: state
    }, stderr: 'pipe'
  });
  const client = new Client({ name: 'catalog-only-test', version: '1.0.0' });
  t.after(async () => { await client.close(); await rm(state, { recursive: true, force: true }); });
  await client.connect(transport);
  const invoke = (name, args = {}) => client.callTool({ name, arguments: args });
  const listing = await invoke('igentic_list_business_solutions');
  assert.equal(listing.isError, undefined);
  assert.equal(listing.structuredContent.data.solutions.length, 6);
  const devices = await invoke('iphone_list_devices');
  assert.deepEqual(devices.structuredContent.data, { backend: 'catalog', devices: [] });
  const capabilities = await invoke('iphone_get_capabilities');
  assert.equal(capabilities.structuredContent.data.mode, 'business-catalog-only');
  assert.deepEqual(capabilities.structuredContent.data.actions, []);
  assert.equal(capabilities.structuredContent.data.requiresMac, false);
  const unavailable = await invoke('iphone_start_session', { device: 'iphone-1' });
  assert.equal(unavailable.isError, true);
  assert.equal(unavailable.content[0].text, 'deviceUnavailable');
});
