import test from 'node:test';
import assert from 'node:assert/strict';
import { makeConnectionReport } from '../src/connection-report.mjs';

const physical = (state, path, available = true) => ({
  id: 'iphone-1', kind: 'physical', available, connectionState: state,
  connectionPath: path, name: 'SENSITIVE-DEVICE', udid: 'SENSITIVE-UDID',
  privateNetworkName: 'SENSITIVE-WIFI'
});
const byPath = (report, path) => report.routes.find(route => route.id === path);

test('USB and Wi-Fi observations are independent and never imply executable app actions', () => {
  for (const [transport, observed, notObserved] of [
    ['usb-coredevice', 'usb-c', 'wifi'], ['network-coredevice', 'wifi', 'usb-c']]) {
    const report = makeConnectionReport({ backend: 'physical',
      devices: [physical('xcode-tunnel-available', transport)] });
    assert.equal(report.deviceStatus, 'coredevice-tunnel-observed');
    assert.equal(byPath(report, observed).state, 'transport-observed');
    assert.equal(byPath(report, notObserved).state, 'not-verified');
    assert.equal(report.actionReadiness, 'not-verified');
    assert.equal(report.nextStep, 'verify-mobilecli-and-fixed-app');
  }
});

test('missing, unavailable, unpaired and contradictory signals always fail closed', () => {
  const inputs = [
    { backend: 'physical', devices: [] },
    { backend: 'physical', devices: [physical('no-active-tunnel', 'usb-coredevice', false)] },
    { backend: 'physical', devices: [physical('pairing-required', 'network-coredevice', false)] },
    { backend: 'physical', devices: [physical('xcode-tunnel-available', 'network-coredevice', false)] },
    { backend: 'physical', devices: [physical('no-active-tunnel', 'usb-coredevice', true)] },
    { backend: 'physical', devices: [physical('xcode-tunnel-available', 'none', true)] },
    { backend: 'physical', devices: [{ id:'other', kind:'physical', available:true,
      connectionState:'xcode-tunnel-available', connectionPath:'usb-coredevice' }] },
    { backend: 'physical', devices: [{ ...physical('xcode-tunnel-available', 'usb-coredevice'), kind:'fixture' }] }
  ];
  for (const input of inputs) {
    const r = makeConnectionReport(input);
    assert.equal(byPath(r, 'usb-c').state, 'not-verified');
    assert.equal(byPath(r, 'wifi').state, 'not-verified');
    assert.equal(r.actionReadiness, 'not-verified');
  }
});

test('unclassified live CoreDevice transport does not guess wired or wireless', () => {
  const report = makeConnectionReport({ backend:'physical',
    devices:[physical('xcode-tunnel-available', 'SENSITIVE-WIFI')] });
  assert.equal(report.transport, 'coredevice-transport-unclassified');
  assert.equal(report.deviceStatus, 'coredevice-tunnel-observed');
  assert.equal(byPath(report, 'usb-c').state, 'not-verified');
  assert.equal(byPath(report, 'wifi').state, 'not-verified');
});

test('fixture is never represented as a reachable physical iPhone', () => {
  const r = makeConnectionReport({ backend:'fixture', devices:[
    { id:'iphone-1', kind:'fixture', available:true, connectionState:'xcode-tunnel-available',
      connectionPath:'usb-coredevice' }] });
  assert.equal(r.deviceStatus,'synthetic-only');
  assert.equal(r.transport,'none');
  assert.equal(byPath(r,'simulator').state,'fixture-only');
  assert.equal(byPath(r,'cellular').state,'companion-not-implemented');
  assert.equal(byPath(r,'on-device').state,'separate-native-app');
});

test('all output is allowlisted and omits untrusted device strings', () => {
  const r = makeConnectionReport({ backend:'physical',
    devices:[physical('no-active-tunnel', 'SENSITIVE-WIFI', false)] });
  const text = JSON.stringify(r);
  assert.doesNotMatch(text, /SENSITIVE-|UDID|privateNetwork/);
  assert.deepEqual(r.routes.map(x => x.id),['usb-c','wifi','cellular','on-device','simulator']);
  assert.equal(r.nextStep,'retry-usb-or-wifi-when-available');
  assert.equal(r.actionReadiness,'not-verified');
});
