import assert from 'node:assert/strict';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { ROOT } from '../src/paths.mjs';
import { join } from 'node:path';

const transport = new StdioClientTransport({
  command: process.execPath,
  args: [join(ROOT, 'src/server.mjs')],
  env: {
    PATH: process.env.PATH,
    IGENTIC_IPHONE_BACKEND: 'catalog',
    IGENTIC_IPHONE_CONFIG: join(ROOT, 'no-physical-config-required.json')
  },
  stderr: 'pipe'
});
const client = new Client({ name: 'catalog-only-smoke', version: '1.0.0' });
const invoke = (name, args = {}) => client.callTool({ name, arguments: args });

try {
  await client.connect(transport);
  assert.equal((await client.listTools()).tools.length, 12);
  const listed = await invoke('igentic_list_business_solutions');
  assert.equal(listed.isError, undefined);
  assert.equal(listed.structuredContent.data.solutions.length, 6);
  assert.equal(listed.structuredContent.data.executionEnabled, false);
  const detail = await invoke('igentic_get_business_solution', { slug: 'field-evidence' });
  assert.equal(detail.isError, undefined);
  assert.equal(detail.structuredContent.data.customerReady, false);
  const devices = await invoke('iphone_list_devices');
  assert.deepEqual(devices.structuredContent.data, { backend: 'catalog', devices: [] });
  const capabilities = await invoke('iphone_get_capabilities');
  assert.deepEqual(capabilities.structuredContent.data.actions, []);
  const attempt = await invoke('iphone_start_session', { device: 'iphone-1' });
  assert.equal(attempt.isError, true);
  assert.equal(attempt.content[0].text, 'deviceUnavailable');
  console.log(JSON.stringify({
    backend: 'catalog', toolCount: 12, solutionCount: 6, requiresPhone: false,
    businessExecutionEnabled: false, phoneSessionsAvailable: false
  }));
} catch (err) {
  console.error(err.message);
  process.exitCode = 1;
} finally {
  await client.close();
}
