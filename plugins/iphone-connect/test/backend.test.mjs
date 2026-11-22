import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, rm, chmod } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { loadConfig, MobileBackend, hasUsablePhysicalTunnel } from '../src/backend.mjs';
import { run } from '../src/process.mjs';

test('unconfigured physical mode never silently falls back to fixture', async () => {
  const b = new MobileBackend(null);
  assert.equal(b.kind, 'physical'); assert.deepEqual(await b.list(), []);
  await assert.rejects(b.open(), /notConfigured/);
});
test('config requires private permissions, fixed bundle and strict keys', async t => {
  const dir = await mkdtemp(join(tmpdir(), 'igentic-config-')); t.after(() => rm(dir, { recursive: true, force: true }));
  const path = join(dir, 'config.json'); await writeFile(path, '{}', { mode: 0o644 });
  await assert.rejects(loadConfig(path), /configMustBePrivate/);
  await chmod(path, 0o600);
  await writeFile(path, JSON.stringify({ deviceId: 'a'.repeat(24), bundleId: 'com.apple.MobileSMS',
    policyPath: process.execPath, mobilecliPath: process.execPath }));
  await assert.rejects(loadConfig(path), /invalidConfig/);
  await writeFile(path, JSON.stringify({ deviceId: 'a'.repeat(24), bundleId: 'org.example.iGenticDiagnostics',
    policyPath: process.execPath, mobilecliPath: process.execPath, approved: true }));
  await assert.rejects(loadConfig(path), /invalidConfig/);
});
test('subprocess timeout, cancellation and output bounds return only coarse errors', async () => {
  await assert.rejects(run(process.execPath, ['-e', 'setTimeout(()=>{},10000)'], { timeout: 20 }), /backendTimeout/);
  await assert.rejects(run(process.execPath, ['-e', 'process.stdout.write("secret".repeat(10000))'], { maxBytes: 100 }), /backendOutputLimit/);
  const c = new AbortController(); c.abort();
  await assert.rejects(run(process.execPath, ['-e', 'setTimeout(()=>{},10000)'], { signal: c.signal }), /cancelled/);
});
test('actual Swift policy helper allows only fixed public read/prepare operations', {
  skip: !process.env.IGENTIC_POLICY_TEST_PATH
}, async () => {
  const path = process.env.IGENTIC_POLICY_TEST_PATH;
  for (const op of ['device-status', 'observe-diagnostics', 'open-diagnostics', 'open-discovery']) {
    const decision = JSON.parse(await run(path, [op]));
    assert.equal(decision.allowed, true); assert.equal(decision.auditEvents, 1);
  }
  const denied = JSON.parse(await run(path, ['send-message']));
  assert.equal(denied.allowed, false);
});

test('only an actively paired physical Xcode tunnel is considered available', () => {
  const fixture = (reality, tunnelState, pairingState = 'paired', transportType = 'wired') => ({
    hardwareProperties: { reality, platform: 'iOS', deviceType: 'iPhone' },
    connectionProperties: { tunnelState, pairingState, transportType }
  });
  for (const state of ['connected', 'available']) {
    assert.equal(hasUsablePhysicalTunnel(fixture('physical', state)), true);
    assert.equal(hasUsablePhysicalTunnel(fixture('simulated', state)), false);
  }
  for (const state of ['unavailable', 'disconnected', 'connecting', undefined]) {
    assert.equal(hasUsablePhysicalTunnel(fixture('physical', state)), false,
      `stale wired transport with ${state} tunnel must be rejected`);
  }
  assert.equal(hasUsablePhysicalTunnel(fixture('physical', 'connected', 'unpaired')), false);
  for (const [key, value] of [['deviceType', 'iPad'], ['platform', 'macOS']]) {
    const wrongDevice = fixture('physical', 'connected');
    wrongDevice.hardwareProperties[key] = value;
    assert.equal(hasUsablePhysicalTunnel(wrongDevice), false, `${key} must identify a real iPhone`);
  }
  assert.equal(hasUsablePhysicalTunnel(null), false);
});
