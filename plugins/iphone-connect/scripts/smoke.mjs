import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { join } from 'node:path';
import { ROOT } from '../src/server.mjs';
const client = new Client({ name: 'igentic-acceptance', version: '0.1.0' });
const transport = new StdioClientTransport({ command: process.execPath, args: [join(ROOT, 'src/server.mjs')],
  env: Object.fromEntries(Object.entries(process.env).filter(([,v]) => v !== undefined)), stderr: 'pipe' });
let sessionId;
const call = async (name, args = {}) => {
  const r = await client.callTool({ name, arguments: args });
  if (r.isError) throw new Error(`${name}: ${r.content?.[0]?.text}`);
  return r.structuredContent.data;
};
try {
  await client.connect(transport);
  const tools = await client.listTools();
  if (tools.tools.length !== 12) throw new Error('toolContractDrift');
  const catalog = await call('igentic_list_business_solutions');
  if (catalog.solutions.length !== 6 || catalog.executionEnabled !== false) throw new Error('businessCatalogDrift');
  const businessDetail = await call('igentic_get_business_solution', { slug: 'enterprise-agent-trust' });
  if (businessDetail.executionEnabled !== false || businessDetail.customerReady !== false) throw new Error('businessDetailDrift');
  const devices = await call('iphone_list_devices');
  if (!devices.devices.some(d => d.available)) throw new Error('deviceUnavailable');
  sessionId = (await call('iphone_start_session', { device: 'iphone-1' })).sessionId;
  const before = await call('iphone_open_diagnostics', { sessionId });
  const proposal = await call('iphone_prepare_action', { sessionId, observationId: before.observationId, action: 'open-discovery' });
  const action = await call('iphone_execute_action', { sessionId, proposalId: proposal.proposalId });
  const receipt = await call('iphone_get_action_result', { sessionId, proposalId: proposal.proposalId });
  const card = await client.readResource({ uri: 'ui://igentic/iphone-dashboard.html' });
  console.log(JSON.stringify({ backend: devices.backend, toolCount: tools.tools.length,
    businessSolutionCount: catalog.solutions.length, businessExecutionEnabled: catalog.executionEnabled,
    beforeMarkers: before.markers, action: action.status, receipt: receipt.status,
    dashboardResource: card.contents[0].mimeType, privateContentReturned: false }));
  if (action.status !== 'verified' || receipt.status !== 'verified') throw new Error('notVerified');
} catch (e) { console.error(e.message); process.exitCode = 1; }
finally {
  if (sessionId) await call('iphone_stop_session', { sessionId }).catch(() => {});
  await client.close();
}
