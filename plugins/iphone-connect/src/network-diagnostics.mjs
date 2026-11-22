import { run } from './process.mjs';

// Extension registration is not proof of a connected VPN, and an active VPN
// would still not make CoreDevice/MobileCLI available over cellular.
export function parseTailscaleExtension(output) {
  if (typeof output !== 'string') return 'unverified';
  const entry = output.split('\n').find(line =>
    /\bio\.tailscale\.ipn\.macsys\.network-extension\s*\(/.test(line));
  if (!entry) return 'notRegistered';
  const state = entry.match(/\[([^\]\r\n]{1,100})\]\s*$/)?.[1];
  if (!state) return 'unverified';
  if (state.includes('waiting for user')) return 'awaitingUserApproval';
  if (state === 'activated enabled') return 'extensionActivated';
  return 'extensionNotActive';
}

export async function networkPreflight({
  platform = process.platform,
  inspect = () => run('/usr/bin/systemextensionsctl', ['list'], {
    timeout: 5000, maxBytes: 128 * 1024
  })
} = {}) {
  let tailscaleExtension = 'unsupportedHost';
  if (platform === 'darwin') {
    try { tailscaleExtension = parseTailscaleExtension(await inspect()); }
    catch { tailscaleExtension = 'unverified'; }
  }
  return {
    tailscaleExtension,
    vpnConnectivity: 'notTested',
    iphoneCellularReachability: 'notTested',
    xcodeOverCellular: 'notEstablished'
  };
}
