import test from 'node:test';
import assert from 'node:assert/strict';
import { parseTailscaleExtension, networkPreflight } from '../src/network-diagnostics.mjs';

const line = state => [
  '1 extension(s)',
  'enabled active teamID bundleID (version) name [state]',
  ' * W5364U7YZB io.tailscale.ipn.macsys.network-extension (1.1/1.1) Tailscale Network Extension [' + state + ']'
].join('\n');

test('read-only extension parser separates owner approval from VPN connectivity', () => {
  assert.equal(parseTailscaleExtension(line('activated waiting for user')), 'awaitingUserApproval');
  assert.equal(parseTailscaleExtension(line('activated enabled')), 'extensionActivated');
  assert.equal(parseTailscaleExtension(line('terminated waiting to uninstall')), 'extensionNotActive');
  assert.equal(parseTailscaleExtension(line('unexpected state')), 'extensionNotActive');
  assert.equal(parseTailscaleExtension('no extensions'), 'notRegistered');
  assert.equal(parseTailscaleExtension(line('activated enabled').replace(/\[[^\]]+\]$/, '')), 'unverified');
  assert.equal(parseTailscaleExtension(null), 'unverified');
});

test('preflight never promotes extension registration to reachable VPN or iPhone', async () => {
  for (const state of ['activated waiting for user', 'activated enabled']) {
    const result = await networkPreflight({ platform: 'darwin', inspect: async () => line(state) });
    assert.equal(result.tailscaleExtension,
      state === 'activated enabled' ? 'extensionActivated' : 'awaitingUserApproval');
    assert.equal(result.vpnConnectivity, 'notTested');
    assert.equal(result.iphoneCellularReachability, 'notTested');
    assert.equal(result.xcodeOverCellular, 'notEstablished');
  }
});

test('unsupported host or broken local tool stays unverified without leaking raw diagnostics', async () => {
  const unsupported = await networkPreflight({ platform: 'linux', inspect: () => { throw Error('should not run'); } });
  assert.equal(unsupported.tailscaleExtension, 'unsupportedHost');
  const failure = await networkPreflight({ platform: 'darwin', inspect: async () => {
    throw Error('private device id or other sensitive stderr text');
  } });
  assert.equal(failure.tailscaleExtension, 'unverified');
  assert.ok(!JSON.stringify(failure).includes('private'));
});
