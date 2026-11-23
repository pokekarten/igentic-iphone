// Optional offline-only durable nonce admission for the owner-task proposal.
// No HTTP server, iPhone execution, owner consent or personal task text.
// The database stores only opaque request UUIDs and Unix expiry seconds.
// SQLite's BEGIN IMMEDIATE + PRIMARY KEY makes duplicate use fail closed
// across separate local processes sharing this single trusted database.
import { DatabaseSync } from 'node:sqlite';
import { closeSync, lstatSync, openSync } from 'node:fs';
import { dirname, isAbsolute, resolve } from 'node:path';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const DOMAIN_ERRORS = new Set(['replayedTaskEnvelope', 'ownerRelayCapacityReached']);

function checkPrivateFile(path) {
  const st = lstatSync(path);
  if (!st.isFile() || (st.mode & 0o077) !== 0
      || (typeof process.getuid === 'function' && st.uid !== process.getuid()))
    throw Error('invalidReplayStorePath');
}

function checkPath(filePath) {
  if (typeof filePath !== 'string' || !isAbsolute(filePath)
      || filePath !== resolve(filePath) || filePath.includes('\0')
      || filePath.length > 4096) throw Error('invalidReplayStorePath');
  // Require an already provisioned private directory, never create a
  // world-searchable location or silently follow a symlink as the final dir.
  const parent = lstatSync(dirname(filePath));
  if (!parent.isDirectory() || (parent.mode & 0o077) !== 0
      || (typeof process.getuid === 'function' && parent.uid !== process.getuid()))
    throw Error('invalidReplayStorePath');
  try {
    const fd = openSync(filePath, 'wx', 0o600);
    closeSync(fd);
  } catch (error) {
    if (error.code !== 'EEXIST') throw error;
  }
  checkPrivateFile(filePath);
}

/**
 * Opt-in, local owner-operated replay defense.
 * Never put this DB on an untrusted or shared filesystem; never use in a
 * public endpoint without account/device enrollment and audited isolation.
 */
export function createDurableTaskReplayStore({ filePath } = {}) {
  let db;
  try {
    checkPath(filePath);
    db = new DatabaseSync(filePath, { timeout: 2500 });
    db.exec('PRAGMA journal_mode=DELETE; PRAGMA synchronous=FULL;');
    db.exec('CREATE TABLE IF NOT EXISTS consumed_tasks (' +
      'request_id TEXT PRIMARY KEY NOT NULL, expires_at INTEGER NOT NULL)');
    const deleteExpired = db.prepare('DELETE FROM consumed_tasks WHERE expires_at <= ?');
    const exists = db.prepare('SELECT 1 FROM consumed_tasks WHERE request_id = ?');
    const count = db.prepare('SELECT COUNT(*) AS total FROM consumed_tasks');
    const insert = db.prepare(
      'INSERT INTO consumed_tasks (request_id, expires_at) VALUES (?, ?)');
    let closed = false;
    return Object.freeze({
      reserve({ requestId, expiresAt, now, maxEntries }) {
        if (closed) throw Error('ownerReplayStoreUnavailable');
        if (typeof requestId !== 'string' || !UUID.test(requestId)
            || !Number.isSafeInteger(now) || now < 0
            || !Number.isSafeInteger(expiresAt) || expiresAt <= now
            || !Number.isSafeInteger(maxEntries)
            || maxEntries < 1 || maxEntries > 1024)
          throw Error('invalidReplayReservation');
        let began = false;
        try {
          db.exec('BEGIN IMMEDIATE');
          began = true;
          deleteExpired.run(now);
          if (exists.get(requestId)) throw Error('replayedTaskEnvelope');
          if (count.get().total >= maxEntries) throw Error('ownerRelayCapacityReached');
          insert.run(requestId, expiresAt);
          db.exec('COMMIT');
          began = false;
          return true;
        } catch (error) {
          if (began) {
            try { db.exec('ROLLBACK'); } catch { /* keep fail-closed */ }
          }
          if (DOMAIN_ERRORS.has(error?.message)) throw error;
          throw Error('ownerReplayStoreUnavailable');
        }
      },
      close() {
        if (closed) return;
        closed = true;
        db.close();
      }
    });
  } catch {
    try { db?.close(); } catch { /* no live verifier left */ }
    throw Error('ownerReplayStoreUnavailable');
  }
}
