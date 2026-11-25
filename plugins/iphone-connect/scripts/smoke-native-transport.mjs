import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { join } from 'node:path';
import { ROOT } from '../src/server.mjs';

// Owner-run physical USB-C or Wi-Fi-only acceptance; one first-party app
// process launch and two independent read-only checks, no raw device data.
const expected = process.argv.slice(2).length === 1 && process.argv[2] === '--usb'
  ? 'usb-coredevice' : process.argv.slice(2).length === 1 && process.argv[2] === '--wifi'
    ? 'network-coredevice' : null;
if (!expected) {
  console.error('Specify --usb or --wifi; no default physical transport.');
  process.exit(2);
}
if (process.env.IGENTIC_IPHONE_BACKEND === 'fixture'
    || process.env.IGENTIC_IPHONE_DRIVER === 'mobilecli') {
  console.error('First-party physical mode required; fixture/legacy not accepted.');
  process.exit(2);
}
const client = new Client({ name: 'igentic-first-party-physical-acceptance', version: '0.1.0' });
const transport = new StdioClientTransport({
  command: process.execPath, args: [join(ROOT, 'src/server.mjs')],
  env: Object.fromEntries(Object.entries({
    ...process.env, IGENTIC_IPHONE_BACKEND: 'physical', IGENTIC_IPHONE_DRIVER: 'coredevice'
  }).filter(([, value]) => value !== undefined)),
  stderr: 'pipe'
});
let sessionId;
const invoke = async (name, args = {}) => {
  const result = await client.callTool({ name, arguments: args });
  if (result.isError) throw new Error(result.content?.[0]?.text ?? 'toolFailed');
  return result.structuredContent?.data;
};
try {
  await client.connect(transport);
  const report = await invoke('iphone_connection_report');
  if (report.transport !== expected || report.deviceStatus !== 'coredevice-tunnel-observed')
    throw new Error('requestedPhysicalTransportNotVerified');
  const before = await invoke('iphone_native_app_status');
  if (before.installed !== true || before.connectionPath !== expected)
    throw new Error('igenticAppNotVerified');
  sessionId = (await invoke('iphone_start_session', { device: 'iphone-1' })).sessionId;
  const launch = await invoke('iphone_native_launch_app', { sessionId });
  const after = await invoke('iphone_native_app_status');
  if (launch.status !== 'own-app-process-observed'
      || launch.connectionPath !== expected || after.processRunning !== true)
    throw new Error('independentOwnAppProcessVerificationFailed');
  console.log(JSON.stringify({
    backend: 'physical', driver: 'coredevice-native', transport: expected,
    installed: true, launchStatus: launch.status,
    independentProcessVerification: true,
    foregroundVerified: false, viewNavigationVerified: false,
    privateContentReturned: false
  }));
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  if (sessionId) await invoke('iphone_stop_session', { sessionId }).catch(() => {});
  await client.close();
}
