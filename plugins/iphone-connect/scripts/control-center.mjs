import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const plans = Object.freeze({
  plan: [],
  prepare: ['dependencies'],
  doctor: ['nativeDoctor', 'wirelessReadiness'],
  fixture: ['fixtureRoundtrip'],
  wifi: ['nativeWifi', 'nativeUi'],
  preview: ['nativePreview'],
  'wifi-ui': ['wirelessReadiness', 'legacyUi'],
});

// No arbitrary commands, IDs, paths, prompts, or external endpoints accepted.
export function parseMode(args) {
  if (args.length !== 1 || !Object.hasOwn(plans, args[0])) throw new Error('invalidMode');
  return args[0];
}

export function evidence(name, result) {
  // Subprocess output may contain private paths or identifiers: never echo it.
  if (result.error?.code === 'ETIMEDOUT') return { step: name, status: 'unknown', reason: 'timeout-no-retry' };
  if (result.error || result.signal || result.status !== 0)
    return { step: name, status: name === 'dependencies' ? 'failed' : 'blocked', reason: 'command-did-not-complete' };
  if (name === 'dependencies') return { step: name, status: 'pass', scope: 'lockfile-install-no-lifecycle-scripts' };
  let data;
  for (const line of String(result.stdout ?? '').split('\n').reverse()) {
    try {
      const candidate = JSON.parse(line);
      if (name === 'nativeDoctor' && !Object.hasOwn(candidate, 'configured')) continue;
      data = candidate; break;
    } catch {}
  }
  let ok = false, scope;
  if (name === 'nativeDoctor') {
    ok = data?.configured === true && data?.devices?.some(d => d.kind === 'physical' && d.available === true);
    scope = 'physical-discovery-only';
  } else if (name === 'wirelessReadiness') {
    ok = data?.wireless_discovery_candidate === true;
    scope = 'optional-mobilecli-discovery-only';
  } else if (['fixtureRoundtrip', 'legacyUi', 'nativeUi'].includes(name)) {
    ok = data?.backend === (name === 'fixtureRoundtrip' ? 'fixture' : 'physical') &&
      data?.action === 'verified' && data?.receipt === 'verified' && data?.privateContentReturned === false;
    scope = name === 'fixtureRoundtrip' ? 'fixture-only' : name === 'legacyUi' ? 'own-app-navigation-via-mobilecli' : 'own-app-navigation-receipt-not-touch';
  } else if (name === 'nativeWifi') {
    ok = data?.backend === 'physical' && data?.transport === 'network-coredevice' &&
      data?.installed === true && data?.independentProcessVerification === true &&
      data?.privateContentReturned === false;
    scope = 'physical-app-process-not-ui';
  } else if (name === 'nativePreview') {
    // The existing harness exits successfully only after checking fresh own-app
    // preview receipts. Never promote this to ChatGPT-account execution.
    ok = data?.backend === 'physical' && data?.transport === 'network-coredevice' &&
      data?.mcpClient === 'local-sdk-test-client' && data?.ownAppInstalled === true &&
      data?.mcpHandoffToolInvoked === true && data?.distinctFreshPreviewReceipts === true &&
      data?.freshComparedWithPriorRun === true && data?.invalidOwnAppRouteIgnored === true &&
      data?.reminderCreationAttempted === false && data?.manualApprovalBypassed === false &&
      data?.crossAppControl === false && data?.privateContentReturned === false;
    scope = 'physical-own-app-preview-local-mcp-not-chatgpt';
  }
  return { step: name, status: ok ? 'pass' : 'blocked', scope };
}

function execute(name) {
  const clean = { ...process.env };
  // Do not allow fixture/driver/config overrides or node code injection to turn
  // a physical acceptance into a fixture success. Use installed owner config.
  for (const key of Object.keys(clean)) {
    if (key.startsWith('IGENTIC_IPHONE_') || key === 'NODE_OPTIONS' || key === 'NODE_PATH') delete clean[key];
  }
  const scripts = {
    nativeDoctor: ['scripts/doctor.mjs'],
    fixtureRoundtrip: ['scripts/smoke.mjs'],
    nativeWifi: ['scripts/smoke-native-transport.mjs', '--wifi'],
    nativeUi: ['scripts/smoke.mjs'],
    nativePreview: ['scripts/smoke-handoff-wifi.mjs'],
    legacyUi: ['scripts/smoke.mjs'],
  };
  if (name === 'fixtureRoundtrip') clean.IGENTIC_IPHONE_BACKEND = 'fixture';
  if (name === 'legacyUi') clean.IGENTIC_IPHONE_DRIVER = 'mobilecli';
  // Fixture sessions must never acquire or alter the physical device lease.
  if (name === 'fixtureRoundtrip') {
    const { mkdtempSync, rmSync } = fixtureFs;
    const tmp = mkdtempSync(join(osTmp, 'igentic-fixture-control-'));
    try {
      clean.IGENTIC_IPHONE_STATE_DIR = tmp;
      return spawnSync(process.execPath, scripts[name], { cwd: root, env: clean, encoding: 'utf8', timeout: 45000, maxBuffer: 1024 * 1024 });
    } finally { rmSync(tmp, { recursive: true, force: true }); }
  }
  const options = { cwd: root, env: clean, encoding: 'utf8', timeout: 120000, maxBuffer: 1024 * 1024 };
  if (name === 'dependencies') return spawnSync('npm', ['ci', '--ignore-scripts', '--no-audit', '--no-fund'], options);
  if (name === 'wirelessReadiness') return spawnSync('python3', [resolve(root, '../../scripts/iphone_wireless_readiness.py')], options);
  return spawnSync(process.execPath, scripts[name], options);
}
import * as fixtureFs from 'node:fs';
import { tmpdir } from 'node:os';
const osTmp = tmpdir();

export function run(mode, runner = execute, platform = process.platform) {
  if (!Object.hasOwn(plans, mode)) throw new Error('invalidMode');
  if (mode === 'plan') return { mode, steps: [], manual: ['system-permissions', 'owner-authentication', 'shortcut-import', 'chatgpt-account-roundtrip'], dependencyLock: existsSync(join(root, 'package-lock.json')) };
  if (['doctor','wifi','wifi-ui','preview'].includes(mode) && platform !== 'darwin')
    return { mode, steps: [{ step: 'platform', status: 'blocked', reason: 'macos-required' }] };
  const steps = [];
  for (const name of plans[mode]) {
    const result = evidence(name, runner(name));
    steps.push(result);
    // No action retry or continuation after an uncertain physical operation.
    if (result.status !== 'pass' && mode !== 'doctor') break;
  }
  return { mode, steps, chatGPTAccountRoundtripVerified: false };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const report = run(parseMode(process.argv.slice(2)));
    console.log(JSON.stringify(report));
    if (report.steps.some(s => s.status !== 'pass')) process.exitCode = 2;
  } catch { console.error('Usage: control-center.mjs plan|prepare|doctor|fixture|wifi|wifi-ui|preview'); process.exitCode = 2; }
}
