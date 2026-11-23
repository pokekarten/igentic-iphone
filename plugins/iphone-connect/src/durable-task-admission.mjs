// Single-host persistent, fail-closed replay protection for owner proposals.
// This module does NOT start a listener, enqueue/execute tasks or grant iOS rights.
import { createHmac, timingSafeEqual } from 'node:crypto';
import { constants, closeSync, lstatSync, openSync } from 'node:fs';
import { dirname, isAbsolute } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { createOwnerProposalAdmission } from './authenticated-task-envelope.mjs';

const REPLAY_DOMAIN = 'igentic-local-replay-ledger-v1\n';
const SEAL_DOMAIN = 'igentic-local-replay-seal-v1\n';
const ROWSET_DOMAIN = 'igentic-local-replay-rowset-v1\n';
const DIGEST_RE = /^[0-9a-f]{64}$/;
const NOFOLLOW = constants.O_NOFOLLOW;

function privateEntry(stat, expected) {
  return (expected === 'directory' ? stat.isDirectory() : stat.isFile())
    && !stat.isSymbolicLink() && (stat.mode & 0o077) === 0
    && (typeof process.getuid !== 'function' || stat.uid === process.getuid());
}
function validatePath(path) {
  if (typeof path !== 'string' || !isAbsolute(path) || path.endsWith('/')
      || !Number.isInteger(NOFOLLOW))
    throw new Error('invalidReplayDatabaseConfig');
  if (!privateEntry(lstatSync(dirname(path)), 'directory'))
    throw new Error('insecureReplayDatabaseDirectory');
}
function existingPrivateFile(path) {
  let stat;
  try { stat = lstatSync(path); }
  catch (e) {
    if (e.code === 'ENOENT') throw new Error('replayDatabaseNotProvisioned');
    throw e;
  }
  if (!privateEntry(stat, 'file')) throw new Error('insecureReplayDatabaseFile');
  return stat;
}
function validateKey(key) {
  if (!Buffer.isBuffer(key) || key.length !== 32
      || key.every(byte => byte === key[0]))
    throw new Error('invalidOwnerRelayKey');
}
function privateSeal(key) {
  return createHmac('sha256', key).update(SEAL_DOMAIN).digest('hex');
}
function sqliteSettings(db) {
  db.exec('PRAGMA journal_mode = DELETE; PRAGMA synchronous = FULL; PRAGMA busy_timeout = 2000;');
}
// The original key seal only proves the database belongs to a particular
// owner key. A separate HMAC over all rows prevents untrusted local edits or
// deletes from resetting a previously accepted request.
function rowsetMAC(db, key) {
  const rows = db.prepare(
    'SELECT request_digest, expires_at FROM admitted ORDER BY request_digest'
  ).all();
  const canonical = rows.map(row => {
    if (typeof row.request_digest !== 'string' || !DIGEST_RE.test(row.request_digest)
        || !Number.isSafeInteger(row.expires_at) || row.expires_at < 0)
      throw new Error('replayDatabaseRowsInvalid');
    return [row.request_digest, row.expires_at];
  });
  return createHmac('sha256', key)
    .update(ROWSET_DOMAIN + JSON.stringify(canonical)).digest('hex');
}
function assertRowsetIntegrity(db, key) {
  const recorded = db.prepare('SELECT rows_mac FROM ledger_seal WHERE slot = 1')
    .get()?.rows_mac;
  if (typeof recorded !== 'string' || !DIGEST_RE.test(recorded))
    throw new Error('replayDatabaseRowsInvalid');
  const actual = Buffer.from(recorded, 'hex');
  const expected = Buffer.from(rowsetMAC(db, key), 'hex');
  if (!timingSafeEqual(actual, expected))
    throw new Error('replayDatabaseRowsInvalid');
}

/**
 * Explicit one-time, offline provisioning. Never call automatically at relay
 * startup: replacing/deleting the SQLite file must halt admission, not reset
 * replay protection. An interrupted bootstrap leaves an unusable database.
 */
export function provisionPrivateReplayLedger({ key, databasePath } = {}) {
  validateKey(key);
  validatePath(databasePath);
  let fd;
  try {
    fd = openSync(databasePath, constants.O_WRONLY | constants.O_CREAT
      | constants.O_EXCL | NOFOLLOW, 0o600);
  } finally { if (fd !== undefined) closeSync(fd); }
  existingPrivateFile(databasePath);
  const db = new DatabaseSync(databasePath);
  try {
    sqliteSettings(db);
    db.exec(`CREATE TABLE ledger_seal (
      slot INTEGER PRIMARY KEY CHECK (slot = 1),
      seal TEXT NOT NULL,
      rows_mac TEXT NOT NULL
    );
    CREATE TABLE admitted (
      request_digest TEXT PRIMARY KEY NOT NULL,
      expires_at INTEGER NOT NULL
    ) WITHOUT ROWID;`);
    db.prepare('INSERT INTO ledger_seal(slot, seal, rows_mac) VALUES (1, ?, ?)')
      .run(privateSeal(key), rowsetMAC(db, key));
  } finally { db.close(); }
}

/**
 * Verifies HMAC before writing a replay record; stores only an opaque digest.
 * A sealed, pre-provisioned local SQLite ledger survives process restarts and
 * serializes same-host competing writers. Not a distributed consensus store.
 */
export function createDurableOwnerProposalAdmission({
  key, databasePath, nowSeconds = () => Math.floor(Date.now() / 1000),
  maxRecords = 256
} = {}) {
  validateKey(key);
  validatePath(databasePath);
  if (typeof nowSeconds !== 'function' || !Number.isSafeInteger(maxRecords)
      || maxRecords < 1 || maxRecords > 1024)
    throw new Error('invalidReplayDatabaseConfig');
  const fileIdentity = existingPrivateFile(databasePath);
  const pinnedKey = Buffer.from(key);
  const verify = createOwnerProposalAdmission({
    key: pinnedKey, nowSeconds, maxInflight: maxRecords
  });
  const db = new DatabaseSync(databasePath);
  let closed = false;
  try {
    sqliteSettings(db);
    const seal = db.prepare('SELECT seal FROM ledger_seal WHERE slot = 1').get()?.seal;
    const expected = Buffer.from(privateSeal(pinnedKey), 'hex');
    if (typeof seal !== 'string' || !/^[0-9a-f]{64}$/.test(seal)
        || !timingSafeEqual(Buffer.from(seal, 'hex'), expected))
      throw new Error('replayDatabaseSealInvalid');
    // Also rejects malformed, truncated, or otherwise structurally corrupt DBs.
    const result = db.prepare('PRAGMA integrity_check').all();
    if (result.length !== 1 || result[0].integrity_check !== 'ok')
      throw new Error('replayDatabaseIntegrityFailed');
    db.prepare('SELECT request_digest, expires_at FROM admitted LIMIT 0').all();
    assertRowsetIntegrity(db, pinnedKey);
  } catch (error) {
    db.close();
    throw error;
  }

  const prune = db.prepare('DELETE FROM admitted WHERE expires_at <= ?');
  const lookup = db.prepare('SELECT 1 AS seen FROM admitted WHERE request_digest = ?');
  const count = db.prepare('SELECT count(*) AS count FROM admitted');
  const insert = db.prepare('INSERT INTO admitted(request_digest, expires_at) VALUES (?, ?)');
  const updateRowset = db.prepare('UPDATE ledger_seal SET rows_mac = ? WHERE slot = 1');

  return Object.freeze({
    admit(envelope) {
      if (closed) throw new Error('replayDatabaseClosed');
      // Reject unlink/replacement of the backing file while a handle is open.
      const current = existingPrivateFile(databasePath);
      if (current.ino !== fileIdentity.ino || current.dev !== fileIdentity.dev)
        throw new Error('replayDatabaseChanged');
      const accepted = verify.admit(envelope);
      const now = nowSeconds();
      if (!Number.isSafeInteger(now) || accepted.expiresAt <= now)
        throw new Error('expiredOrFutureTaskEnvelope');
      const digest = createHmac('sha256', pinnedKey)
        .update(REPLAY_DOMAIN + accepted.requestId).digest('hex');
      // BEGIN IMMEDIATE serializes writers across processes on one disk.
      db.exec('BEGIN IMMEDIATE');
      try {
        // Verify the latest rowset under the write lock. This catches
        // tampering after another verifier handle was opened and avoids
        // staleness when a second legitimate process recently committed.
        assertRowsetIntegrity(db, pinnedKey);
        prune.run(now);
        if (lookup.get(digest)) throw new Error('replayedTaskEnvelope');
        if (count.get().count >= maxRecords)
          throw new Error('ownerRelayCapacityReached');
        insert.run(digest, accepted.expiresAt);
        if (updateRowset.run(rowsetMAC(db, pinnedKey)).changes !== 1)
          throw new Error('replayDatabaseRowsInvalid');
        db.exec('COMMIT');
      } catch (error) {
        try { db.exec('ROLLBACK'); } catch { /* fail closed */ }
        throw error;
      }
      return Object.freeze({
        ...accepted, replayProtection: 'persistent-local-sqlite',
        actionExecuted: false, deviceReceipt: 'none'
      });
    },
    close() {
      if (closed) return;
      closed = true;
      db.close();
    }
  });
}
