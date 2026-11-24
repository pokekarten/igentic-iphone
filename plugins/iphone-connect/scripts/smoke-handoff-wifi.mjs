import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';
import { mkdtemp, readFile, rm, stat } from 'node:fs/promises';
import { NativeCoreDeviceBackend } from '../src/native-coredevice.mjs';
import { loadConfig } from '../src/backend.mjs';
import { run, decode } from '../src/process.mjs';
import { HANDOFF_ACTIONS, verifyChatGPTHandoffPreviewReceipt } from '../src/chatgpt-handoff.mjs';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import { startPortableGateway } from '../src/portable-gateway.mjs';

// This is an owner-run acceptance on the *physical* iPhone and ONLY via Wi-Fi.
// The actions are limited to own-app previews and an invalid-link rejection.
// It is not a
// ChatGPT-account test or arbitrary mobile UI control.
const includeReminderPreview = process.argv.length === 3 &&
  process.argv[2] === '--reminder-preview';
if ((process.argv.length !== 2 && !includeReminderPreview) ||
    process.env.IGENTIC_IPHONE_BACKEND === 'fixture' ||
    process.env.IGENTIC_IPHONE_DRIVER === 'mobilecli') {
  console.error('physicalFirstPartyWifiOnly');
  process.exit(2);
}
const configPath = process.env.IGENTIC_IPHONE_CONFIG
  ?? join(homedir(), 'Library/Application Support/iGentic/iphone-connect/config.json');
const expectedBundle = 'de.bos.neoagent.igenticdiagnostics';
const receiptPath = 'Documents/igentic-chatgpt-preview-receipt.json';
const config = await loadConfig(configPath);
if (config?.bundleId !== expectedBundle) throw new Error('expectedOwnAppOnly');

const backend = new NativeCoreDeviceBackend(config);
const physicalWifi = async () => {
  const devices = await backend.list();
  const owned = devices.find(d => d.id === 'iphone-1');
  if (owned?.available !== true || owned.connectionPath !== 'network-coredevice')
    throw new Error('wifiPhysicalTunnelNotVerified');
};
const core = async args => run('/usr/bin/xcrun', ['devicectl', ...args], { timeout: 25000 });
const readReceipt = async () => {
  const dir = await mkdtemp(join(tmpdir(), 'igentic-handoff-observed-'));
  try {
    const dest = join(dir, 'receipt.json');
    await core(['device', 'copy', 'from', '--device', config.deviceId,
      '--source', receiptPath, '--domain-type', 'appDataContainer',
      '--domain-identifier', expectedBundle, '--destination', dest,
      '--timeout', '15']);
    const info = await stat(dest);
    if (!info.isFile() || info.size > 512) throw new Error('receiptInvalid');
    return decode(await readFile(dest, 'utf8'));
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
};
// Establish a previously observed event *before* any new dispatch. Without
// this baseline, the first route could falsely pass against a stale receipt
// from a prior test run. This owner-run hardware acceptance requires a
// previously initialized iGentic install with a valid preview receipt.
const snapshotBeforeDispatch = async () => {
  const prior = await readReceipt();
  if (!HANDOFF_ACTIONS.includes(prior?.route))
    throw new Error('baselineHandoffPreviewNotVerified');
  return verifyChatGPTHandoffPreviewReceipt(prior, prior.route);
};
const observe = async (route, previousID) => {
  if (typeof previousID !== 'string')
    throw new Error('missingPreDispatchReceiptBaseline');
  for (let retry = 0; retry < 9; retry++) {
    try {
      const eventID = verifyChatGPTHandoffPreviewReceipt(
        await readReceipt(), route, previousID);
      return eventID;
    } catch {
      if (retry === 8) throw new Error('freshOwnAppHandoffPreviewNotVerified');
      await new Promise(resolve => setTimeout(resolve, 450));
    }
  }
};
const dispatch = async (route, fixedMcpHandoffUrl) => {
  // Fail closed if the MCP tool returned a different URL or embedded text.
  if (fixedMcpHandoffUrl !== 'igentic://handoff/v1/' + route)
    throw new Error('untrustedHandoffUrl');
  // An exact, owned app process restart gives the next URL a clean sheet
  // lifecycle. Never activate another app or enumerate private data.
  await backend.policy(route === 'discovery' ? 'open-discovery' : 'open-diagnostics');
  await core(['device', 'process', 'launch', '--device', config.deviceId,
    '--terminate-existing', '--timeout', '18', expectedBundle]);
  await core(['device', 'process', 'openURL', '--device', config.deviceId,
    '--timeout', '18', fixedMcpHandoffUrl]);
};

// A real SDK MCP client requests the same read-only tool ChatGPT would use.
// The local test harness (not ChatGPT or a user tap) opens the returned
// allowlisted link using Apple's CoreDevice, then independently reads only
// the own-app privacy-safe view receipts.
const gateway = await startPortableGateway();
const client = new Client({ name: 'igentic-physical-mcp-acceptance', version: '0.1.0' });
try {
  await client.connect(new StreamableHTTPClientTransport(
    new URL('http://127.0.0.1:' + gateway.port + '/mcp')
  ));
  const tools = (await client.listTools()).tools;
  const tool = tools.find(t => t.name === 'iphone_chatgpt_handoff');
  if (!tool || tool.annotations?.readOnlyHint !== true ||
      tool.annotations?.destructiveHint !== false)
    throw new Error('readOnlyMcpToolUnavailable');
  const prepareViaMcp = async action => {
    const reply = await client.callTool({
      name: 'iphone_chatgpt_handoff', arguments: { action }
    });
    const data = reply.structuredContent?.data;
    if (reply.isError || data?.launchUrl !== 'igentic://handoff/v1/' + action
        || data?.action !== action || data?.requiresOwnerTap !== true
        || data?.actionExecuted !== false || data?.iPhoneConnected !== 'not-checked'
        || data?.dataSentToIPhone !== 'none') throw new Error('unsafeMcpHandoff');
    return data.launchUrl;
  };
  await physicalWifi();
  const status = await backend.appStatus();
  if (status.installed !== true) throw new Error('ownAppNotInstalled');
  const baselineID = await snapshotBeforeDispatch();
  const diagnosticsUrl = await prepareViaMcp('diagnostics');
  await dispatch('diagnostics', diagnosticsUrl);
  const firstID = await observe('diagnostics', baselineID);
  const discoveryUrl = await prepareViaMcp('discovery');
  await dispatch('discovery', discoveryUrl);
  const discoveryID = await observe('discovery', firstID);
  let finalID = discoveryID;
  let finalRoute = 'discovery';

  if (includeReminderPreview) {
    // Optional third *navigation preview* only. This is deliberately NOT
    // a native policy operation (the native driver has no reminder-write
    // capability). The signed first-party app merely shows a sheet with
    // another manual in-app navigation step; no EventKit API is invoked.
    const reminderUrl = await prepareViaMcp('reminder-draft');
    await core(['device', 'process', 'launch', '--device', config.deviceId,
      '--terminate-existing', '--timeout', '18', expectedBundle]);
    await core(['device', 'process', 'openURL', '--device', config.deviceId,
      '--timeout', '18', reminderUrl]);
    finalID = await observe('reminder-draft', finalID);
    finalRoute = 'reminder-draft';
  }

  // Negative acceptance. Open an invalid first-party URL ONLY; never send
  // an arbitrary scheme or a URL from an MCP tool. The app's strict parser
  // must ignore the invalid route without creating a new sheet receipt.
  const forbiddenRoute = 'igentic://handoff/v1/delete-contacts';
  await core(['device', 'process', 'openURL', '--device', config.deviceId,
    '--timeout', '18', forbiddenRoute]);
  await new Promise(resolve => setTimeout(resolve, 850));
  const afterInvalid = await readReceipt();
  const afterID = verifyChatGPTHandoffPreviewReceipt(afterInvalid, finalRoute);
  if (afterID !== finalID) throw new Error('invalidHandoffCreatedPreview');
  await physicalWifi();
  console.log(JSON.stringify({
    backend: 'physical', driver: 'coredevice-native',
    transport: 'network-coredevice', ownAppInstalled: true,
    mcpClient: 'local-sdk-test-client', mcpHandoffToolInvoked: true,
    urlOpenedBy: 'mac-acceptance-harness',
    distinctFreshPreviewReceipts: true,
    freshComparedWithPriorRun: true, invalidOwnAppRouteIgnored: true,
    routes: includeReminderPreview
      ? ['diagnostics', 'discovery', 'reminder-draft']
      : ['diagnostics', 'discovery'],
    reminderCreationAttempted: false,
    manualApprovalBypassed: false, crossAppControl: false,
    privateContentReturned: false
  }));
} finally {
  await client.close();
  await gateway.close();
}
