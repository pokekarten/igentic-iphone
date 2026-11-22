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
test('every physical MobileCLI invocation pins the configured iPhone, never a discovered first device', async t => {
  const dir = await mkdtemp(join(tmpdir(), 'igentic-pinned-phone-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const command = join(dir, 'fake-mobilecli');
  // Synthetic executable echoes only argument names; no phone or account is used.
  await writeFile(command, `#!${process.execPath}\nprocess.stdout.write(JSON.stringify({ status: 'ok', data: { argv: process.argv.slice(2) } }));\n`, { mode: 0o700 });
  await chmod(command, 0o700);
  const pinnedId = 'a'.repeat(24);
  const backend = new MobileBackend({ deviceId: pinnedId,
    bundleId: 'org.example.iGenticDiagnostics', mobilecliPath: command, policyPath: command });
  const output = await backend.mobile(['dump', 'ui']);
  assert.deepEqual(output.argv, ['dump', 'ui', '--device', pinnedId]);
  assert.equal(output.argv.filter(x => x === '--device').length, 1);
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

test('child tools never inherit MCP-host tokens or injected runtime variables', async () => {
  const key = 'IGENTIC_SYNTHETIC_TEST_PROVIDER_TOKEN';
  const old = process.env[key];
  const telemetry = process.env.MOBILEMCP_DISABLE_TELEMETRY;
  try {
    process.env[key] = 'synthetic-not-a-secret';
    process.env.MOBILEMCP_DISABLE_TELEMETRY = '0';
    const script = `process.stdout.write(JSON.stringify({
      injected: process.env.${key} ?? null,
      telemetry: process.env.MOBILEMCP_DISABLE_TELEMETRY ?? null,
      hasHome: typeof process.env.HOME === 'string',
      leakedProviderNames: Object.keys(process.env).some(k =>
        /^(OPENAI_API_KEY|GH_TOKEN|GITHUB_TOKEN|HF_TOKEN|AWS_SECRET_ACCESS_KEY|SSH_AUTH_SOCK)$/.test(k))
    }))`;
    const observed = JSON.parse(await run(process.execPath, ['-e', script]));
    assert.equal(observed.injected, null);
    assert.equal(observed.telemetry, '1');
    assert.equal(observed.hasHome, true);
    assert.equal(observed.leakedProviderNames, false);
  } finally {
    if (old === undefined) delete process.env[key];
    else process.env[key] = old;
    if (telemetry === undefined) delete process.env.MOBILEMCP_DISABLE_TELEMETRY;
    else process.env.MOBILEMCP_DISABLE_TELEMETRY = telemetry;
  }
});
