// Read-only status projection for the Mac plugin. A tunnel alone is never
// authorization or proof that an app-owned iPhone action was executed.
const PATHS = Object.freeze([
  ['usb-c', true], ['wifi', true], ['cellular', false],
  ['on-device', false], ['simulator', true]
]);
const STATES = new Set(['xcode-tunnel-available', 'no-active-tunnel',
  'pairing-required', 'unsupported-device']);
const TRANSPORTS = new Set(['none', 'usb-coredevice', 'network-coredevice',
  'coredevice-transport-unclassified']);

export function makeConnectionReport({ backend, devices }) {
  const kind = backend === 'fixture' ? 'fixture' : 'physical';
  const device = kind === 'physical' && Array.isArray(devices)
    ? devices.find(d => d && d.id === 'iphone-1' && d.kind === 'physical') : null;
  const rawState = device?.connectionState;
  const observed = STATES.has(rawState) ? rawState : 'not-observed';
  // An inconsistent backend result is NOT positive evidence.
  const active = kind === 'physical' && device?.available === true
    && observed === 'xcode-tunnel-available';
  const rawTransport = device?.connectionPath;
  const transport = active && TRANSPORTS.has(rawTransport) && rawTransport !== 'none'
    ? rawTransport : active ? 'coredevice-transport-unclassified' : 'none';
  const status = kind === 'fixture' ? 'synthetic-only'
    : active ? 'coredevice-tunnel-observed' : observed;
  const routes = PATHS.map(([id, macRequired]) => {
    const state = id === 'usb-c' && active && transport === 'usb-coredevice'
      || id === 'wifi' && active && transport === 'network-coredevice'
      ? 'transport-observed'
      : id === 'cellular' ? 'companion-not-implemented'
      : id === 'on-device' ? 'separate-native-app'
      : id === 'simulator' ? kind === 'fixture' ? 'fixture-only' : 'test-only'
      : 'not-verified';
    return { id, state, macRequired };
  });
  const nextStep = kind === 'fixture' ? 'test-only'
    : active ? 'verify-mobilecli-and-fixed-app'
    : observed === 'pairing-required' ? 'pair-and-trust-locally'
    : observed === 'no-active-tunnel' ? 'retry-usb-or-wifi-when-available'
    : 'check-local-configuration-and-device';
  return {
    backend: kind, deviceStatus: status, transport, actionReadiness: 'not-verified',
    routes, nextStep,
  };
}
