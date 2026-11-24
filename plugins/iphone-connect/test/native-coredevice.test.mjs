import test from 'node:test';
import assert from 'node:assert/strict';
import { NativeCoreDeviceBackend, verifiedNativeReceipt, projectOwnAppStatus } from '../src/native-coredevice.mjs';
import { randomUUID } from 'node:crypto';
import { PhoneService } from '../src/service.mjs';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const receipt = (action, nonce) => ({
  schema: 1, action, nonce,
  view: action === 'open-discovery' ? 'discovery' : 'diagnostics',
  status: 'observed'
});

test('first-party receipt accepts exactly fixed own-app views and no private fields', () => {
  const nonce = randomUUID();
  assert.deepEqual(verifiedNativeReceipt(receipt('open-diagnostics', nonce), { action: 'open-diagnostics', nonce }),
    { elementCount: 2, markers: ['iGentic Diagnostics', 'Open local discovery'] });
  assert.deepEqual(verifiedNativeReceipt(receipt('open-discovery', nonce), { action: 'open-discovery', nonce }),
    { elementCount: 2, markers: ['Explore', 'Topics'] });
  assert.throws(() => verifiedNativeReceipt({ ...receipt('open-diagnostics', nonce), privateLabel: 'SECRET' },
    { action: 'open-diagnostics', nonce }), /nativeReceiptInvalid/);
});

test('first-party receipt rejects replay, wrong view, invalid action, unobserved and malformed files', () => {
  const nonce = randomUUID();
  const valid = receipt('open-diagnostics', nonce);
  for (const altered of [
    { ...valid, nonce: randomUUID() },
    { ...valid, action: 'open-discovery' },
    { ...valid, view: 'discovery' },
    { ...valid, status: 'launched' },
    { ...valid, schema: 2 },
    { ...valid, personal: 'never return this' }, null, [], { ...valid, status: null }
  ]) {
    assert.throws(() => verifiedNativeReceipt(altered, { action: 'open-diagnostics', nonce }), /nativeReceiptInvalid/);
  }
  assert.throws(() => verifiedNativeReceipt(valid, { action: 'delete-user-app', nonce }), /nativeReceiptInvalid/);
});

test('own CoreDevice dispatch pins bundle, device and command; never executes arbitrary UI', async () => {
  const commands = [];
  const cfg = { deviceId: '1'.repeat(24), bundleId: 'org.example.iGenticDiagnostics',
    policyPath: process.execPath };
  class FakeNative extends NativeCoreDeviceBackend {
    async policy(operation) { assert.ok(['open-diagnostics', 'open-discovery', 'observe-diagnostics'].includes(operation)); }
    async core(args) { commands.push(args); return ''; }
    async receipt({ action, nonce }) { return verifiedNativeReceipt(receipt(action, nonce), { action, nonce }); }
  }
  const native = new FakeNative(cfg);
  assert.equal(native.driver, 'coredevice-native');
  await assert.rejects(native.discovery(), /nativeStateUnknown/);
  const initial = await native.open();
  assert.ok(initial.markers.includes('Open local discovery'));
  assert.deepEqual(await native.observe(), initial);
  const after = await native.discovery();
  assert.ok(after.markers.includes('Explore'));
  assert.deepEqual(await native.observe(), after);
  assert.equal(commands.length, 2);
  for (const command of commands) {
    assert.deepEqual(command.slice(0, 5), ['device', 'process', 'launch', '--device', cfg.deviceId]);
    assert.equal(command.filter(k => k === cfg.bundleId).length, 1);
    assert.ok(command.includes('--terminate-existing'));
    assert.equal(command.filter(k => k.startsWith('--igentic-bridge-action=')).length, 1);
    assert.equal(command.filter(k => k.startsWith('--igentic-bridge-nonce=')).length, 1);
    assert.equal(command.some(k => k === 'com.apple.MobileSMS'), false);
  }
  await assert.rejects(native.launch('tap-arbitrary-app'), /unsupportedAction/);
  assert.equal(commands.length, 2);
});

test('a launched process without matching view receipt never counts as success', async () => {
  const native = new NativeCoreDeviceBackend({ deviceId: '1'.repeat(24),
    bundleId: 'org.example.iGenticDiagnostics', policyPath: process.execPath });
  native.policy = async () => {};
  native.core = async () => '';
  native.receipt = async () => { throw new Error('file-not-found'); };
  await assert.rejects(native.open(), /nativeReceiptUnverified/);
  await assert.rejects(native.observe(), /nativeStateUnknown/);
});

test('first-party device receipt completes a session/proposal/verified receipt without MobileCLI', async t => {
  const stateDir = await mkdtemp(join(tmpdir(), 'igentic-own-native-session-'));
  t.after(() => rm(stateDir, { recursive: true, force: true }));
  const cfg = { deviceId: '1'.repeat(24), bundleId: 'org.example.iGenticDiagnostics',
    policyPath: process.execPath };
  class FakeNative extends NativeCoreDeviceBackend {
    async policy() { return { allowed: true, auditEvents: 1 }; }
    async list() { return [{ id: 'iphone-1', kind: 'physical', available: true,
      connectionState: 'xcode-tunnel-available', connectionPath: 'network-coredevice' }]; }
    async core() { return ''; }
    async receipt({ action, nonce }) { return verifiedNativeReceipt(receipt(action, nonce), { action, nonce }); }
  }
  const service = new PhoneService({ backend: new FakeNative(cfg), stateDir });
  t.after(() => service.close());
  const { sessionId } = await service.start('iphone-1');
  const before = await service.open(sessionId);
  assert.ok(before.markers.includes('Open local discovery'));
  const proposal = service.prepare(sessionId, before.observationId, 'open-discovery');
  const after = await service.execute(sessionId, proposal.proposalId);
  assert.equal(after.status, 'verified');
  assert.equal(service.result(sessionId, proposal.proposalId).status, 'verified');
  await assert.rejects(service.execute(sessionId, proposal.proposalId), /invalidProposal/);
  await service.stop(sessionId);
});

test('own-app status compares exact app URL to executable and never returns paths or IDs', () => {
  const bundleId = 'org.example.iGenticDiagnostics';
  const url = 'file:///private/var/containers/Bundle/Application/SECRET-UUID/iGenticDiagnostics.app/';
  const apps = [{ bundleIdentifier: bundleId, url, privateNote: 'SECRET-NOTE' }];
  const processes = [{ executable: url + 'iGenticDiagnostics', processIdentifier: 321, personal: 'SECRET' }];
  const result = projectOwnAppStatus(apps, processes, bundleId);
  assert.deepEqual(result, { supported: true, installed: true, processRunning: true,
    evidence: 'apple-coredevice-metadata' });
  assert.doesNotMatch(JSON.stringify(result), /SECRET|321|private/i);
  assert.equal(projectOwnAppStatus(apps, [{ executable: url + 'some-other-app' }], bundleId).processRunning, false);
  assert.equal(projectOwnAppStatus(apps, [{ executable: url + 'Frameworks/iGenticDiagnostics' }], bundleId).processRunning, false);
  assert.equal(projectOwnAppStatus(apps, [{ executable: url.replace('SECRET-UUID', 'OTHER') + 'iGenticDiagnostics' }],
    bundleId).processRunning, false);
  assert.deepEqual(projectOwnAppStatus([], [], bundleId),
    { supported: true, installed: false, processRunning: false, evidence: 'apple-coredevice-metadata' });
});

test('own-app status fails closed on unknown and duplicated CoreDevice response', () => {
  const bundleId = 'org.example.iGenticDiagnostics';
  const app = { bundleIdentifier: bundleId, url: 'garbled' };
  assert.equal(projectOwnAppStatus([app], [], bundleId).processRunning, 'not-verified');
  assert.throws(() => projectOwnAppStatus([app, app], [], bundleId), /backendFailed/);
  assert.throws(() => projectOwnAppStatus(undefined, [], bundleId), /backendFailed/);
  assert.throws(() => projectOwnAppStatus([app], {}, bundleId), /backendFailed/);
});


test('first-party own-app launch verifies process after Apple launch, without a view claim', async () => {
  const config = {
    deviceId: '1'.repeat(24),
    bundleId: 'org.example.iGenticDiagnostics',
    policyPath: process.execPath
  };
  const calls = [];
  class NativeAppLaunchFake extends NativeCoreDeviceBackend {
    async policy(operation) { calls.push(['policy',operation]); }
    async core(args) {
      calls.push(['core',args]);
      const idx=args.indexOf('--json-output');
      assert.ok(idx>=0);
      await writeFile(args[idx+1], JSON.stringify({
        info: { outcome: 'success' }, result: { process: { processIdentifier: 123 } }
      }));
      return '';
    }
    async appStatus() {
      calls.push(['status']);
      return { supported: true, installed: true, processRunning: true,
        connectionPath: 'usb-coredevice' };
    }
  }
  const bridge=new NativeAppLaunchFake(config);
  const result=await bridge.launchOwnApp();
  assert.deepEqual(result,{
    status:'own-app-process-observed', connectionPath:'usb-coredevice',
    foreground:'not-verified',viewNavigation:'not-verified',
    personalDataReturned:false
  });
  assert.deepEqual(calls.map(c=>c[0]),['policy','core','status']);
  assert.equal(calls[0][1],'open-diagnostics');
  const args=calls[1][1];
  assert.ok(args.includes(config.bundleId));
  assert.ok(args.includes(config.deviceId));
  assert.equal(args.includes('--terminate-existing'),false);
  assert.equal(args.some(x=>x.startsWith('--igentic-bridge-')),false);
  assert.doesNotMatch(JSON.stringify(result), /123|de\.bos|org\.example/);
});

test('first-party own-app launch refuses false process confirmation and bad launch receipts', async () => {
  const cfg={deviceId:'1'.repeat(24),bundleId:'org.example.iGenticDiagnostics',policyPath:process.execPath};
  class NativeAppLaunchFake extends NativeCoreDeviceBackend {
    async policy() {}
    async core(args) {
      const idx=args.indexOf('--json-output');
      await writeFile(args[idx+1],JSON.stringify({
        info:{outcome:this.outcome??'success'},
        result:{process:{processIdentifier:22}}
      }));
      return '';
    }
    async appStatus() { return {installed:true,processRunning:this.running??false}; }
  }
  const b=new NativeAppLaunchFake(cfg);
  await assert.rejects(b.launchOwnApp(),/nativeProcessUnverified/);
  b.running=true;b.outcome='failed';
  await assert.rejects(b.launchOwnApp(),/nativeProcessUnverified/);
});

test('Shortcut completion is scoped to the requested task and omits journal contents', async () => {
  const { shortcutCompletion } = await import('../src/native-coredevice.mjs');
  const taskId = '5fd452bc-6815-48da-9a5b-02f555553d05';
  const row = { schema: 1, id: taskId.toUpperCase(), createdAt: 123, stage: 'finished' };
  assert.deepEqual(shortcutCompletion(row, taskId), {
    taskId, stage: 'finished', evidence: 'physical-own-app-journal'
  });
  for (const change of [{ stage: 'readAttempted' }, { id: 'other' }, { extra: true }, { createdAt: null }])
    assert.throws(() => shortcutCompletion({ ...row, ...change }, taskId), /shortcutCompletionUnverified/);
});
