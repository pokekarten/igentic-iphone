import { readFile, stat, mkdtemp, rm } from 'node:fs/promises';
import { isAbsolute, join } from 'node:path';
import { tmpdir } from 'node:os';
import { run, decode, PluginError } from './process.mjs';

const BUNDLES = new Set(['de.bos.neoagent.igenticdiagnostics', 'org.example.iGenticDiagnostics']);
export const MARKERS = Object.freeze(['iGentic Diagnostics', 'Open local discovery', 'Explore',
  'Featured', 'Topics', 'Collections', 'Sample / preview snapshot']);

// A remembered pairing or a stale wired transport is not proof of a usable tunnel.
// In particular, a simulator must never satisfy the physical-device contract.
// Deliberately expose only one of four fixed readiness codes. Never echo
// CoreDevice identifiers, transport metadata or arbitrary device labels.
// A usable CoreDevice tunnel is not proof that MobileCLI or our app is ready.
export function physicalConnectionState(device) {
  if (device?.hardwareProperties?.reality !== 'physical'
      || device?.hardwareProperties?.platform !== 'iOS'
      || device?.hardwareProperties?.deviceType !== 'iPhone') return 'unsupported-device';
  if (device?.connectionProperties?.pairingState !== 'paired') return 'pairing-required';
  if (!['connected', 'available'].includes(device?.connectionProperties?.tunnelState))
    return 'no-active-tunnel';
  return 'xcode-tunnel-available';
}

export function hasUsablePhysicalTunnel(device) {
  return physicalConnectionState(device) === 'xcode-tunnel-available';
}

export function sanitizeTree(value) {
  const found = new Set(); let count = 0;
  function visit(node, depth = 0) {
    if (!node || typeof node !== 'object' || depth > 50 || count >= 3000) return;
    count++;
    for (const key of ['label', 'name', 'text', 'identifier']) {
      if (typeof node[key] === 'string' && MARKERS.includes(node[key])) found.add(node[key]);
    }
    for (const child of node.children ?? []) visit(child, depth + 1);
  }
  for (const node of value ?? []) visit(node);
  return { elementCount: count, markers: [...found].sort() };
}

export async function loadConfig(path) {
  if (!path) return null;
  if (!isAbsolute(path)) throw new PluginError('configPathMustBeAbsolute');
  const info = await stat(path);
  if ((info.mode & 0o077) !== 0 || !info.isFile()) throw new PluginError('configMustBePrivate');
  const c = decode(await readFile(path, 'utf8'));
  if (!c || Object.keys(c).some(k => !['deviceId', 'bundleId', 'mobilecliPath', 'policyPath'].includes(k)))
    throw new PluginError('invalidConfig');
  if (!/^[A-Fa-f0-9-]{20,50}$/.test(c.deviceId ?? '') || !BUNDLES.has(c.bundleId))
    throw new PluginError('invalidConfig');
  for (const key of ['mobilecliPath', 'policyPath']) {
    if (!isAbsolute(c[key] ?? '') || !(await stat(c[key])).isFile()) throw new PluginError('invalidConfig');
  }
  return c;
}

export class MobileBackend {
  kind = 'physical';
  constructor(config) { this.config = config; }
  async policy(operation, signal) {
    if (!this.config) throw new PluginError('notConfigured');
    const r = decode(await run(this.config.policyPath, [operation], { signal, timeout: 5000 }));
    if (r.allowed !== true || r.auditEvents !== 1) throw new PluginError('policyDenied');
    return r;
  }
  async list(signal) {
    if (!this.config) return [];
    await this.policy('device-status', signal);
    const directory = await mkdtemp(join(tmpdir(), 'igentic-device-'));
    try {
      const path = join(directory, 'devices.json');
      await run('/usr/bin/xcrun', ['devicectl', 'list', 'devices', '--json-output', path], { signal });
      const json = decode(await readFile(path, 'utf8'));
      const devices = json.result?.devices ?? [];
      const d = devices.find(d => d.hardwareProperties?.reality === 'physical'
        && (d.hardwareProperties?.udid === this.config.deviceId || d.identifier === this.config.deviceId));
      if (!d) return [];
      const connectionState = physicalConnectionState(d);
      return [{ id: 'iphone-1', kind: this.kind,
        available: connectionState === 'xcode-tunnel-available', connectionState }];
    } finally { await rm(directory, { recursive: true, force: true }); }
  }
  async mobile(args, signal) {
    if (!this.config) throw new PluginError('notConfigured');
    const response = decode(await run(this.config.mobilecliPath,
      [...args, '--device', this.config.deviceId], { signal }));
    if (response.status !== 'ok') throw new PluginError('backendFailed');
    return response.data;
  }
  async assertApp(signal) {
    const app = await this.mobile(['apps', 'foreground'], signal);
    if (app?.packageName !== this.config.bundleId) throw new PluginError('wrongForegroundApp');
  }
  async tree(signal) {
    await this.assertApp(signal);
    const data = await this.mobile(['dump', 'ui'], signal);
    await this.assertApp(signal);
    if (!Array.isArray(data?.elements)) throw new PluginError('screenUnavailable');
    return data.elements;
  }
  async observe(signal) {
    await this.policy('observe-diagnostics', signal);
    return sanitizeTree(await this.tree(signal));
  }
  async open(signal) {
    await this.policy('open-diagnostics', signal);
    await run('/usr/bin/xcrun', ['devicectl', 'device', 'process', 'launch', '--device',
      this.config.deviceId, this.config.bundleId], { signal });
    // A launch exit code alone is not a verified foreground result.
    return this.observe(signal);
  }
  async discovery(signal) {
    await this.policy('open-discovery', signal);
    const tree = await this.tree(signal); const matches = [];
    const visit = (n, depth = 0) => {
      if (!n || depth > 50) return;
      if (n.label === 'Open local discovery' && /button/i.test(n.type ?? '') && n.enabled !== false
          && /^@?e\d+$/.test(n.ref ?? '')) matches.push(n.ref);
      for (const c of n.children ?? []) visit(c, depth + 1);
    };
    for (const n of tree) visit(n);
    if (matches.length !== 1) throw new PluginError('navigationTargetUnavailable');
    await this.assertApp(signal);
    await this.mobile(['io', 'tap', matches[0]], signal);
    return this.observe(signal);
  }
}

// Explicit fixture mode for CI and a clean installation without a phone.
// Never selected as fallback after physical errors.
export class FixtureBackend {
  kind = 'fixture'; page = 'diagnostics';
  async policy() { return { allowed: true, auditEvents: 1 }; }
  async list() { return [{ id: 'iphone-1', kind: this.kind, available: true }]; }
  async observe() { return { elementCount: 8, markers: this.page === 'diagnostics'
    ? ['iGentic Diagnostics', 'Open local discovery'] : ['Explore', 'Topics'] }; }
  async open() { this.page = 'diagnostics'; return this.observe(); }
  async discovery() { this.page = 'discovery'; return this.observe(); }
}
