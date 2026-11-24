import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';
import { mkdtemp, readFile, rm, stat } from 'node:fs/promises';
import { NativeCoreDeviceBackend } from '../src/native-coredevice.mjs';
import { loadConfig } from '../src/backend.mjs';
import { run, decode } from '../src/process.mjs';
import { HANDOFF_ACTIONS, verifyChatGPTHandoffPreviewReceipt } from '../src/chatgpt-handoff.mjs';
import { validatePublishedHandoffEvidence } from '../src/published-handoff-evidence.mjs';

// Input is exactly three real ChatGPT-site tool result wrappers (JSON on stdin).
// A local operator must supply these results and authorize this test. They are
// not an autonomous Site->Mac channel or evidence of an owner tap.
const maxBytes = 16000;
let input = '';
for await (const chunk of process.stdin) {
  input += chunk.toString('utf8');
  if (Buffer.byteLength(input, 'utf8') > maxBytes)
    throw new Error('publishedHandoffInputTooLarge');
}
const actions = validatePublishedHandoffEvidence(JSON.parse(input));
const config = await loadConfig(join(homedir(),
  'Library/Application Support/iGentic/iphone-connect/config.json'));
if (config?.bundleId !== 'de.bos.neoagent.igenticdiagnostics')
  throw new Error('unexpectedOwnApp');
const backend = new NativeCoreDeviceBackend(config);
const physical = (await backend.list()).find(x => x.id === 'iphone-1');
if (physical?.available !== true || physical.connectionPath !== 'network-coredevice')
  throw new Error('physicalWifiOnly');
if ((await backend.appStatus()).installed !== true) throw new Error('ownAppNotInstalled');
const core = args => run('/usr/bin/xcrun', ['devicectl', ...args], { timeout: 25000 });
const readReceipt = async () => {
  const dir = await mkdtemp(join(tmpdir(), 'igentic-published-site-'));
  try {
    const path = join(dir, 'receipt.json');
    await core(['device','copy','from','--device',config.deviceId,
      '--source','Documents/igentic-chatgpt-preview-receipt.json',
      '--domain-type','appDataContainer','--domain-identifier',config.bundleId,
      '--destination',path,'--timeout','15']);
    const file = await stat(path);
    if (!file.isFile() || file.size > 512) throw new Error('invalidReceipt');
    return decode(await readFile(path, 'utf8'));
  } finally { await rm(dir, { recursive: true, force: true }); }
};
const prior = await readReceipt();
if (!HANDOFF_ACTIONS.includes(prior?.route)) throw new Error('unverifiedBaseline');
let lastID = verifyChatGPTHandoffPreviewReceipt(prior, prior.route);
const verified = [];
for (const {action,launchUrl} of actions) {
  await backend.policy(action === 'discovery' ? 'open-discovery' : 'open-diagnostics');
  await core(['device','process','launch','--device',config.deviceId,
    '--terminate-existing','--timeout','18',config.bundleId]);
  await core(['device','process','openURL','--device',config.deviceId,
    '--timeout','18',launchUrl]);
  let observation;
  for (let attempt = 0; attempt < 9; attempt++) {
    try {
      observation = verifyChatGPTHandoffPreviewReceipt(
        await readReceipt(), action, lastID);
      break;
    } catch {
      if (attempt === 8) throw new Error('freshPreviewNotVerified');
      await new Promise(resolve => setTimeout(resolve, 450));
    }
  }
  lastID = observation;
  verified.push(action);
}
console.log(JSON.stringify({
  input: 'operator-supplied-published-plugin-results',
  backend: 'physical', transport: 'network-coredevice',
  urlOpenedBy: 'mac-acceptance-harness', routesWithFreshReceipts: verified,
  siteToMacAutonomous: false, ownerTapVerified: false,
  reminderCreationAttempted: false, personalDataReturned: false
}));
