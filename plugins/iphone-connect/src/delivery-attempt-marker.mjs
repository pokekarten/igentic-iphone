// Optional offline-only write-ahead safety marker. A marker is persisted and
// fsynced BEFORE prepareDelivery returns data to any possible transport.
// It is not a queue, a receipt, a device command or a proof of delivery.
import { createHmac, timingSafeEqual } from 'node:crypto';
import {
  constants, closeSync, fstatSync, fsyncSync, lstatSync, openSync,
  readFileSync, readdirSync, writeSync
} from 'node:fs';
import { join, isAbsolute, resolve } from 'node:path';

const DOMAIN = 'igentic-delivery-attempt-v1\n';
const SEAL_DOMAIN = 'igentic-delivery-marker-directory-key-v1\n';
const SEAL_NAME = '.delivery-key-seal';
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
  // Bind all attempt filenames in this directory to one persistent key. A
  // changed key must never make old attempts disappear after process restart.
  const sealDigest = Buffer.from(createHmac('sha256', privateKey)
    .update(SEAL_DOMAIN).digest('hex'), 'ascii');
  const sealPath = join(directory, SEAL_NAME);
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
  function validateSeal() {
    validateDirectory();
    let fd;
    try {
      fd = openSync(sealPath, constants.O_RDONLY | NOFOLLOW);
      const metadata = fstatSync(fd);
      if (!privateFile(metadata) || metadata.nlink !== 1
          || metadata.size !== sealDigest.length) fail();
      const stored = readFileSync(fd);
      if (stored.length !== sealDigest.length
          || !timingSafeEqual(stored, sealDigest)) fail();
    } catch { fail(); }
    finally { if (fd !== undefined) closeSync(fd); }
  }
  function initializeSeal() {
    validateDirectory();
    let missing = false;
    try { lstatSync(sealPath); }
    catch (error) {
      if (error?.code !== 'ENOENT') fail();
      missing = true;
    }
    if (missing) {
      // Never silently rotate the key for existing markers (or for an
      // unrecognized, possibly rolled-back directory).
      try {
        if (readdirSync(directory).length !== 0) fail();
        let fd;
        try {
          fd = openSync(sealPath, constants.O_WRONLY | constants.O_CREAT
            | constants.O_EXCL | NOFOLLOW, 0o600);
          if (writeSync(fd, sealDigest) !== sealDigest.length) fail();
          fsyncSync(fd);
        } finally { if (fd !== undefined) closeSync(fd); }
        const directoryFd = openSync(directory,
          constants.O_RDONLY | constants.O_DIRECTORY | NOFOLLOW);
        try { fsyncSync(directoryFd); }
        finally { closeSync(directoryFd); }
      } catch { fail(); }
    }
    validateSeal();
  }
  // The initial provisioning is permitted only in a completely empty
  // owner-private directory; subsequent opens and operations fail closed.
  initializeSeal();
  return Object.freeze({
    markPrepared({ requestId, receiptNonce, route } = {}) {
      validateRequest(requestId);
      if (typeof receiptNonce !== 'string' || !UUID.test(receiptNonce)
          || !ROUTES.has(route)) throw new Error('invalidDeliveryMarkerRequest');
      validateSeal();
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
      validateSeal();
      try {
        const st = lstatSync(markerPath(requestId));
        if (!privateFile(st) || st.size !== 0) fail();
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
