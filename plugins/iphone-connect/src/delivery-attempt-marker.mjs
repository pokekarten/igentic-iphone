// Optional offline-only write-ahead safety marker. A marker is persisted and
// fsynced BEFORE prepareDelivery returns data to any possible transport.
// It is not a queue, a receipt, a device command or a proof of delivery.
import { createHmac, timingSafeEqual } from 'node:crypto';
import { constants, closeSync, fstatSync, fsyncSync, lstatSync,
  openSync, readdirSync, readSync, writeSync } from 'node:fs';
import { join, isAbsolute, resolve } from 'node:path';

const DOMAIN = 'igentic-delivery-attempt-v1\n';
const KEY_BINDING_DOMAIN = 'igentic-delivery-attempt-key-binding-v1\n';
const BINDING_FILE = '.key-binding';
const ATTEMPT_NAME = /^[a-f0-9]{64}\.attempt$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const ROUTES = new Set([
  'cellular-foreground', 'coredevice-usb', 'coredevice-wifi', 'local-shortcuts'
]);
const NOFOLLOW = constants.O_NOFOLLOW;

function privateDir(st) {
  return st.isDirectory() && !st.isSymbolicLink()
    && (st.mode & 0o077) === 0
    && (typeof process.getuid !== 'function' || st.uid === process.getuid());
}
function privateFile(st) {
  return st.isFile() && !st.isSymbolicLink()
    && (st.mode & 0o077) === 0
    && (typeof process.getuid !== 'function' || st.uid === process.getuid());
}
function fail() { throw new Error('deliveryMarkerUnavailable'); }
function validateRequest(requestId) {
  if (typeof requestId !== 'string' || !UUID.test(requestId))
    throw new Error('invalidDeliveryMarkerRequest');
}
/**
 * One marker per request, not per transport retry. An unknown/partial
 * send may NEVER automatically reuse this request after process restart.
 * Caller must use a separately authenticated, durable replay-admission store.
 */
export function createPrivateDeliveryAttemptMarker({ directory, key } = {}) {
  if (typeof directory !== 'string' || !isAbsolute(directory)
      || directory !== resolve(directory) || directory.length > 4096
      || !Buffer.isBuffer(key) || key.length !== 32
      || key.every(byte => byte === key[0])
      || !Number.isInteger(NOFOLLOW)) fail();
  const privateKey = Buffer.from(key);
  let identity;
  try {
    identity = lstatSync(directory);
    if (!privateDir(identity)) fail();
  } catch { fail(); }
  const markerPath = requestId => join(directory, createHmac('sha256', privateKey)
    .update(DOMAIN + requestId).digest('hex') + '.attempt');
  function validateDirectory() {
    try {
      const now = lstatSync(directory);
      if (!privateDir(now) || now.dev !== identity.dev || now.ino !== identity.ino)
        fail();
    } catch { fail(); }
  }

  // A fixed filename with a keyed commitment prevents re-enrolling a new
  // local HMAC key in a directory already holding possible sends. Using only
  // a key-dependent marker filename would silently permit a second send
  // after key rotation. This stores no raw key, task ID or task contents.
  const bindingPath = join(directory, BINDING_FILE);
  const expectedBinding = createHmac('sha256', privateKey)
    .update(KEY_BINDING_DOMAIN).digest();

  function verifyBinding({ create }) {
    validateDirectory();
    let names;
    try { names = readdirSync(directory); } catch { fail(); }
    if (!names.includes(BINDING_FILE)) {
      // A missing binding with existing attempts is unsafe to migrate
      // implicitly. Explicit migration must be implemented separately.
      if (names.length !== 0) fail();
      if (!create) return false;
      let fd;
      try {
        // A fixed name + O_EXCL enforces one owner key, even when two
        // independent processes race to provision the same private folder.
        fd = openSync(bindingPath, constants.O_WRONLY | constants.O_CREAT
          | constants.O_EXCL | NOFOLLOW, 0o600);
        if (writeSync(fd, expectedBinding, 0, expectedBinding.length, 0)
            !== expectedBinding.length) fail();
        fsyncSync(fd);
        const directoryFd = openSync(directory,
          constants.O_RDONLY | constants.O_DIRECTORY | NOFOLLOW);
        try { fsyncSync(directoryFd); }
        finally { closeSync(directoryFd); }
      } catch (error) {
        if (error?.code !== 'EEXIST') fail();
      } finally {
        if (fd !== undefined) {
          try { closeSync(fd); } catch { fail(); }
        }
      }
    }
    let fd;
    try {
      fd = openSync(bindingPath, constants.O_RDONLY | NOFOLLOW);
      const st = fstatSync(fd);
      // Hardlinks are regular files: forbid aliases to the key commitment.
      if (!privateFile(st) || st.nlink !== 1
          || st.size !== expectedBinding.length) fail();
      const actual = Buffer.alloc(expectedBinding.length);
      if (readSync(fd, actual, 0, actual.length, 0) !== actual.length
          || !timingSafeEqual(actual, expectedBinding)) fail();
    } catch { fail(); }
    finally {
      if (fd !== undefined) {
        try { closeSync(fd); } catch { fail(); }
      }
    }
    // Fail closed on unexpected/tampered entries rather than clearing a
    // marker or treating an old directory as an empty new key enrollment.
    let refreshed;
    try { refreshed = readdirSync(directory); } catch { fail(); }
    if (!refreshed.includes(BINDING_FILE)
        || refreshed.some(name => name !== BINDING_FILE
          && !ATTEMPT_NAME.test(name))) fail();
    validateDirectory();
    return true;
  }
  return Object.freeze({
    markPrepared({ requestId, receiptNonce, route } = {}) {
      validateRequest(requestId);
      if (typeof receiptNonce !== 'string' || !UUID.test(receiptNonce)
          || !ROUTES.has(route)) throw new Error('invalidDeliveryMarkerRequest');
      verifyBinding({ create: true });
      const path = markerPath(requestId);
      let fd;
      try {
        // O_EXCL makes concurrent attempts on the same local filesystem
        // atomic. The empty marker exposes no task data, signature or key.
        fd = openSync(path, constants.O_WRONLY | constants.O_CREAT
          | constants.O_EXCL | NOFOLLOW, 0o600);
        fsyncSync(fd);
        const directoryFd = openSync(directory,
          constants.O_RDONLY | constants.O_DIRECTORY | NOFOLLOW);
        try { fsyncSync(directoryFd); }
        finally { closeSync(directoryFd); }
        return true;
      } catch (error) {
        if (error?.code === 'EEXIST')
          throw new Error('deliveryAlreadyPreparedOrUncertain');
        // Marker creation or durability failed: do not return a delivery
        // payload. An uncertain on-disk marker is left in place, fail closed.
        fail();
      } finally {
        if (fd !== undefined) closeSync(fd);
      }
    },
    recover({ requestId } = {}) {
      validateRequest(requestId);
      if (!verifyBinding({ create: false })) return null;
      try {
        const st = lstatSync(markerPath(requestId));
        // Recovery must not trust an attempt whose inode has outside aliases.
        if (!privateFile(st) || st.nlink !== 1 || st.size !== 0) fail();
        return Object.freeze({
          state: 'outcome-unknown',
          actionExecuted: false,
          ownerApproved: false,
          iPhoneConnected: 'not-checked',
          deviceReceipt: 'none',
          automaticRetryAllowed: false,
          evidence: 'durable-prepared-marker-not-device-receipt'
        });
      } catch (error) {
        if (error?.code === 'ENOENT') return null;
        fail();
      }
    }
  });
}
