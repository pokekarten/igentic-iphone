import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, rm, chmod } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { loadConfig, MobileBackend, hasUsablePhysicalTunnel, physicalConnectionState, physicalConnectionPath, discoveryControlRef } from '../src/backend.mjs';
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

test('connection diagnostics emit fixed codes and never device metadata', () => {
  const fixture = (pairingState, tunnelState, reality = 'physical') => ({
    hardwareProperties: {
      reality, platform: 'iOS', deviceType: 'iPhone',
      udid: 'DO-NOT-REVEAL-IDENTIFIER'
    },
    connectionProperties: {
      pairingState, tunnelState, transportType: 'secret-transport-metadata'
    },
    privateNote: 'DO-NOT-REVEAL-PRIVATE-NOTE'
  });
  const samples = [
    [fixture('paired', 'connected'), 'xcode-tunnel-available', true],
    [fixture('paired', 'available'), 'xcode-tunnel-available', true],
    [fixture('paired', 'unavailable'), 'no-active-tunnel', false],
    [fixture('paired', 'connecting'), 'no-active-tunnel', false],
    [fixture('paired', undefined), 'no-active-tunnel', false],
    [fixture('unpaired', 'connected'), 'pairing-required', false],
    [fixture(undefined, 'connected'), 'pairing-required', false],
    [fixture('paired', 'connected', 'simulated'), 'unsupported-device', false],
    [null, 'unsupported-device', false]
  ];
  for (const [device, expectedCode, shouldBeAvailable] of samples) {
    const code = physicalConnectionState(device);
    assert.equal(code, expectedCode);
    assert.equal(hasUsablePhysicalTunnel(device), shouldBeAvailable);
    assert.match(code, /^[a-z-]+$/);
    assert.ok(!code.includes('DO-NOT-REVEAL'));
    assert.ok(!code.includes('secret-transport'));
  }
});

test('bounded discovery selector accepts an exact SwiftUI Link or Button only', () => {
  const labelLink = { type: 'Link', label: 'Open local discovery', ref: '@e12', enabled: true };
  const nativeLink = { type: 'XCUIElementTypeLink',
    identifier: 'igentic-open-local-discovery', label: 'Localized discovery', ref: 'e9' };
  const button = { type: 'button', label: 'Open local discovery', ref: 'e8' };
  assert.equal(discoveryControlRef([{ children: [labelLink] }]), '@e12');
  assert.equal(discoveryControlRef([nativeLink]), 'e9');
  assert.equal(discoveryControlRef([button]), 'e8');
});

test('discovery selector fails closed on wrong, disabled, duplicate or oversized elements', () => {
  const valid = { type: 'Link', identifier: 'igentic-open-local-discovery',
    label: 'Open local discovery', ref: '@e11' };
  const rejected = [
    [],
    null,
    [{ ...valid, enabled: false }],
    [{ ...valid, type: 'StaticText' }],
    [{ ...valid, label: 'Other app', identifier: 'unknown' }],
    [{ ...valid, ref: '0; send message' }],
    [valid, { ...valid, ref: 'e13' }],
    [{ children: 'unexpected-private-payload' }],
    [{ ...valid, children: [valid] }],
    [{ children: Array.from({ length: 3001 }, () => ({ type: 'StaticText' })) }],
  ];
  for (const tree of rejected) {
    assert.throws(() => discoveryControlRef(tree), /navigationTargetUnavailable/);
  }
});


test('connection path is a fixed projection of the live physical CoreDevice tunnel only', () => {
  const device = (transportType, tunnelState = 'connected', reality = 'physical', pairingState = 'paired') => ({
    hardwareProperties: { reality, platform: 'iOS', deviceType: 'iPhone' },
    connectionProperties: { transportType, tunnelState, pairingState,
      privateNetworkName: 'DO-NOT-RETURN' }
  });
  const cases = [
    [device('wired'), 'usb-coredevice'],
    [device('usb'), 'usb-coredevice'],
    [device('wireless'), 'network-coredevice'],
    [device('network'), 'network-coredevice'],
    [device('wifi'), 'network-coredevice'],
    [device('network', 'disconnected'), 'none'],
    [device('wired', 'unavailable'), 'none'],
    [device('wired', 'connected', 'simulated'), 'none'],
    [device('network', 'connected', 'physical', 'unpaired'), 'none'],
    [device('VPN-only'), 'coredevice-transport-unclassified'],
    [device('wireless;DO-NOT-RETURN'), 'coredevice-transport-unclassified'],
    [device(undefined), 'coredevice-transport-unclassified'],
    [null, 'none']
  ];
  for (const [input, expected] of cases) {
    const result = physicalConnectionPath(input);
    assert.equal(result, expected);
    assert.doesNotMatch(result, /DO-NOT-RETURN|VPN-only|privateNetworkName/);
    assert.ok(['usb-coredevice','network-coredevice','coredevice-transport-unclassified','none'].includes(result));
  }
});
