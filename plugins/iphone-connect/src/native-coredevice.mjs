import { randomUUID } from 'node:crypto';
import { mkdtemp, readFile, rm, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { MobileBackend } from './backend.mjs';
import { PluginError, run, decode } from './process.mjs';

// Fixed-action iGentic-owned alternative to MobileCLI: Apple CoreDevice CLI
// plus a receipt emitted by our own SwiftUI view after onAppear.
// No arbitrary taps, screenshots, personal data, shell or foreign apps.
const BUNDLE_RECEIPT = 'Documents/igentic-plugin-receipt.json';
const VIEWS = Object.freeze({
  'open-diagnostics': 'diagnostics',
  'open-discovery': 'discovery'
});
export const NATIVE_DRIVER = 'coredevice-native';

export function verifiedNativeReceipt(value, { action, nonce }) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new PluginError('nativeReceiptInvalid');
  const keys = Object.keys(value).sort();
  if (keys.join('|') !== 'action|nonce|schema|status|view') throw new PluginError('nativeReceiptInvalid');
  if (!Object.hasOwn(VIEWS, action) || !/^[0-9a-f-]{36}$/.test(nonce)) throw new PluginError('nativeReceiptInvalid');
  if (value.schema !== 1 || value.action !== action || value.nonce !== nonce
      || value.view !== VIEWS[action] || value.status !== 'observed') throw new PluginError('nativeReceiptInvalid');
  return {
    elementCount: 2,
    markers: action === 'open-diagnostics'
      ? ['iGentic Diagnostics', 'Open local discovery'] : ['Explore', 'Topics']
  };
}

// Never return app URLs, executable paths, process IDs or device identities.
export function projectOwnAppStatus(apps, processes, bundleId) {
  if (!Array.isArray(apps) || !Array.isArray(processes)) throw new PluginError('backendFailed');
  const matches = apps.filter(a => a && a.bundleIdentifier === bundleId);
  if (matches.length > 1) throw new PluginError('backendFailed');
  if (matches.length === 0) {
    return { supported: true, installed: false, processRunning: false,
      evidence: 'apple-coredevice-metadata' };
  }
  const url = matches[0].url;
  // Compare the exact installed app bundle path to the executable path.
  // The process name by itself is insufficient evidence of app identity.
  const rooted = typeof url === 'string' && url.startsWith('file:') && url.endsWith('.app/');
  const processRunning = !rooted ? 'not-verified' : processes.some(p =>
    typeof p?.executable === 'string' && p.executable === url + 'iGenticDiagnostics');
  return { supported: true, installed: true, processRunning,
    evidence: 'apple-coredevice-metadata' };
}

export class NativeCoreDeviceBackend extends MobileBackend {
  driver = NATIVE_DRIVER;
  constructor(config, { cli = '/usr/bin/xcrun', launchTimeout = 20000 } = {}) {
    super(config);
    this.cli = cli;
    this.launchTimeout = launchTimeout;
    this.last = null;
  }
  async core(args, signal, timeout = 20000) {
    return run(this.cli, ['devicectl', ...args], { signal, timeout });
  }
  async list(signal) {
    const original = await super.list(signal);
    if (!this.config || original.some(d => d.available)) return original;
    // Paired Wi-Fi/USB can be dormant. Read-only details may open an on-demand
    // CoreDevice tunnel, but never authorize an app action by themselves.
    const directory = await mkdtemp(join(tmpdir(), 'igentic-coredevice-ready-'));
    try {
      await this.core(['device', 'info', 'details', '--device', this.config.deviceId,
        '--timeout', '12', '--json-output', join(directory, 'details.json')], signal, 16000);
      return await super.list(signal);
    } catch (e) {
      if (e.code === 'cancelled') throw e;
      return original;
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  }
  async receipt({ action, nonce }, signal) {
    const dir = await mkdtemp(join(tmpdir(), 'igentic-native-receipt-'));
    try {
      const path = join(dir, 'receipt.json');
      await this.core(['device', 'copy', 'from', '--device', this.config.deviceId,
        '--source', BUNDLE_RECEIPT, '--domain-type', 'appDataContainer',
        '--domain-identifier', this.config.bundleId, '--destination', path,
        '--timeout', '12'], signal, 17000);
      const info = await stat(path);
      if (!info.isFile() || info.size > 512) throw new PluginError('nativeReceiptInvalid');
      return verifiedNativeReceipt(decode(await readFile(path, 'utf8')), { action, nonce });
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  }
  async appStatus(signal) {
    await this.policy('device-status', signal);
    const devices = await this.list(signal);
    const physical = devices.find(d => d.id === 'iphone-1');
    if (!physical?.available) return {
      supported: true, installed: 'not-verified', processRunning: 'not-verified',
      evidence: 'no-active-tunnel', connectionPath: 'none'
    };
    const dir = await mkdtemp(join(tmpdir(), 'igentic-own-app-status-'));
    try {
      const appsPath = join(dir, 'apps.json');
      const processesPath = join(dir, 'processes.json');
      await this.core(['device', 'info', 'apps', '--device', this.config.deviceId,
        '--bundle-id', this.config.bundleId, '--timeout', '15',
        '--json-output', appsPath], signal, 20000);
      await this.core(['device', 'info', 'processes', '--device', this.config.deviceId,
        '--search', 'iGentic', '--timeout', '15',
        '--json-output', processesPath], signal, 20000);
      const apps = decode(await readFile(appsPath, 'utf8')).result?.apps;
      const processes = decode(await readFile(processesPath, 'utf8')).result?.runningProcesses;
      return { ...projectOwnAppStatus(apps, processes, this.config.bundleId),
        connectionPath: physical.connectionPath };
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  }
  // Separate, explicitly requested limited action for older installed app
  // builds without the nonce receipt bridge. Does not claim view navigation.
  async launchOwnApp(signal) {
    await this.policy('open-diagnostics', signal);
    const directory = await mkdtemp(join(tmpdir(), 'igentic-own-app-launch-'));
    try {
      const path = join(directory, 'launch.json');
      await this.core(['device', 'process', 'launch', '--device',
        this.config.deviceId, '--timeout', '16',
        '--json-output', path, this.config.bundleId], signal, 21000);
      const response = decode(await readFile(path, 'utf8'));
      if (response.info?.outcome !== 'success' || !response.result?.process)
        throw new PluginError('nativeProcessUnverified');
      // Observe the fixed app identity independently AFTER launch.
      const status = await this.appStatus(signal);
      if (status.installed !== true || status.processRunning !== true)
        throw new PluginError('nativeProcessUnverified');
      return {
        status: 'own-app-process-observed',
        connectionPath: status.connectionPath,
        foreground: 'not-verified',
        viewNavigation: 'not-verified',
        personalDataReturned: false
      };
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  }
  async launch(action, signal) {
    if (!Object.hasOwn(VIEWS, action)) throw new PluginError('unsupportedAction');
    await this.policy(action, signal);
    // A process-launch success is not a navigation receipt. Require a new
    // per-launch UUID in the sandboxed SwiftUI view's own receipt file.
    const nonce = randomUUID();
    await this.core(['device', 'process', 'launch', '--device', this.config.deviceId,
      '--timeout', '18', '--terminate-existing', '--', this.config.bundleId,
      '--igentic-bridge-action=' + action, '--igentic-bridge-nonce=' + nonce],
      signal, this.launchTimeout);
    let observation;
    for (let i = 0; i < 4; i++) {
      try {
        observation = await this.receipt({ action, nonce }, signal);
        break;
      } catch (e) {
        if (signal?.aborted) throw new PluginError('cancelled');
        if (i === 3 || e.code === 'nativeReceiptInvalid') throw new PluginError('nativeReceiptUnverified');
        await new Promise(resolve => setTimeout(resolve, 400));
      }
    }
    this.last = { action, nonce };
    return observation;
  }
  async open(signal) { return this.launch('open-diagnostics', signal); }
  async discovery(signal) {
    if (!this.last || this.last.action !== 'open-diagnostics') throw new PluginError('nativeStateUnknown');
    return this.launch('open-discovery', signal);
  }
  async observe(signal) {
    await this.policy('observe-diagnostics', signal);
    if (!this.last) throw new PluginError('nativeStateUnknown');
    return this.receipt(this.last, signal);
  }
}
