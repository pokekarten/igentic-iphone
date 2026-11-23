// Manual Mac-side acceptance step for an owner-operated HTTPS readiness host.
// No network access until the owner explicitly sets both configuration values.
// NEVER an iPhone / LTE / 5G transport acceptance test.
import { lstat, readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { decodeSharedKey } from '../src/cellular-gateway.mjs';
import { probeOwnerCellularHost } from '../src/cellular-host-probe.mjs';

const safeCodes = new Set([
  'invalidOwnerEndpoint', 'invalidOwnerPairingKey', 'invalidProbeTimeout',
  'ownerHostRejected', 'ownerHostResponseMalformed', 'ownerHostResponseTooLarge',
  'ownerHostProofInvalid', 'ownerHostTimeout', 'ownerHostNetworkOrTLSFailed'
]);

export async function checkConfiguredHost(env = process.env) {
  if (!env.IGENTIC_CELLULAR_ENDPOINT || !env.IGENTIC_CELLULAR_SHARED_KEY_FILE) {
    return { status: 'blocked', reason: 'ownerHostConfigurationMissing',
      cellularVerified: false, iphoneAppVerified: false };
  }
  let key;
  try {
    const st = await lstat(env.IGENTIC_CELLULAR_SHARED_KEY_FILE);
    if (!st.isFile() || (st.mode & 0o077) !== 0)
      throw Error('privatePairingKeyRequired');
    key = decodeSharedKey(await readFile(env.IGENTIC_CELLULAR_SHARED_KEY_FILE, 'utf8'));
  } catch {
    return { status: 'blocked', reason: 'privatePairingKeyRequired',
      cellularVerified: false, iphoneAppVerified: false };
  }
  try {
    return await probeOwnerCellularHost({
      endpoint: env.IGENTIC_CELLULAR_ENDPOINT, sharedKey: key
    });
  } catch (error) {
    return { status: 'unverified',
      reason: safeCodes.has(error?.message) ? error.message : 'ownerHostProbeFailed',
      cellularVerified: false, iphoneAppVerified: false };
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  if (process.argv.length !== 2) {
    console.error('Usage: configure IGENTIC_CELLULAR_ENDPOINT and IGENTIC_CELLULAR_SHARED_KEY_FILE');
    process.exitCode = 2;
  } else {
    checkConfiguredHost().then(report => {
      // Only fixed status codes: never print secrets, URLs, IPs or process data.
      console.log(JSON.stringify(report));
      if (report.status !== 'authenticated-owner-host-readiness')
        process.exitCode = 2;
    }).catch(() => {
      console.log(JSON.stringify({ status:'unverified', reason:'ownerHostProbeFailed',
        cellularVerified:false, iphoneAppVerified:false }));
      process.exitCode = 2;
    });
  }
}
