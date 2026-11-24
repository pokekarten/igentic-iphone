// Manual Mac-side acceptance step for an owner-operated HTTPS readiness host.
// No network access until the owner explicitly sets both configuration values.
// NEVER an iPhone / LTE / 5G transport acceptance test.
import { constants } from 'node:fs';
import { open as openAsync } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { decodeSharedKey } from '../src/cellular-gateway.mjs';
import { probeOwnerCellularHost } from '../src/cellular-host-probe.mjs';

const safeCodes = new Set([
  'invalidOwnerEndpoint', 'invalidOwnerPairingKey', 'invalidProbeTimeout',
  'ownerHostRejected', 'ownerHostResponseMalformed', 'ownerHostResponseTooLarge',
  'ownerHostProofInvalid', 'ownerHostTimeout', 'ownerHostNetworkOrTLSFailed'
]);

// Open with O_NOFOLLOW and inspect/read through the SAME file descriptor.
// This prevents a symlink-swap between a path lstat() and later readFile().
export async function readPrivatePairingKey(keyPath) {
  if (typeof keyPath !== 'string' || keyPath.length === 0)
    throw Error('privatePairingKeyRequired');
  // Nonblocking open also prevents a substituted FIFO from hanging the probe.
  const file = await openAsync(keyPath, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
  const valid = st => st.isFile() && st.nlink === 1 && (st.mode & 0o077) === 0 &&
    (typeof process.getuid !== 'function' || st.uid === process.getuid()) &&
    (st.size === 44 || st.size === 45);
  try {
    const st = await file.stat();
    if (!valid(st)) throw Error('privatePairingKeyRequired');
    // Read at most one byte beyond the maximum accepted size, even if the
    // file grows after fstat. Never allocate based on a mutable file size.
    const buffer = Buffer.alloc(46);
    let length = 0;
    while (length < buffer.length) {
      const { bytesRead } = await file.read(buffer, length, buffer.length - length, length);
      if (bytesRead === 0) break;
      length += bytesRead;
    }
    const after = await file.stat();
    if (length !== st.size || !valid(after) || after.size !== st.size ||
        after.mtimeMs !== st.mtimeMs || after.ctimeMs !== st.ctimeMs)
      throw Error('privatePairingKeyRequired');
    return decodeSharedKey(buffer.subarray(0, length).toString('utf8'));
  } finally {
    await file.close();
  }
}

export async function checkConfiguredHost(env = process.env) {
  if (!env.IGENTIC_CELLULAR_ENDPOINT || !env.IGENTIC_CELLULAR_SHARED_KEY_FILE) {
    return { status: 'blocked', reason: 'ownerHostConfigurationMissing',
      cellularVerified: false, iphoneAppVerified: false };
  }
  let key;
  try {
    key = await readPrivatePairingKey(env.IGENTIC_CELLULAR_SHARED_KEY_FILE);
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
