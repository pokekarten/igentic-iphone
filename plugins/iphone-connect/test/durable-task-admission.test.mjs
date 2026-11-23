import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomBytes } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import {
  chmodSync, closeSync, existsSync, lstatSync, mkdtempSync, openSync,
  readFileSync, rmSync, symlinkSync
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createDurableOwnerProposalAdmission, provisionPrivateReplayLedger }
  from '../src/durable-task-admission.mjs';
import { prepareSignedReadOnlyProposal } from '../src/authenticated-task-envelope.mjs';

const NOW = 2_000_000_000;
function fixture({ provisioned = true } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'igentic-private-replay-'));
  const f = { dir, databasePath: join(dir, 'admissions.sqlite'),
    key: randomBytes(32), cleanup() { rmSync(dir, { recursive: true, force: true }); } };
  if (provisioned) provisionPrivateReplayLedger(f);
  return f;
}
const proposal = (key, issuedAt = NOW, options = {}) =>
  prepareSignedReadOnlyProposal({ key, issuedAt, ...options });
const admission = (f, nowSeconds = () => NOW, maxRecords = 256) =>
  createDurableOwnerProposalAdmission({ key: f.key, databasePath: f.databasePath,
    nowSeconds, maxRecords });

test('obviously predictable owner relay keys cannot provision or open the ledger', () => {
  const f = fixture({ provisioned: false });
  try {
    for (const weakKey of [Buffer.alloc(32), Buffer.alloc(32, 0xff)]) {
      assert.throws(() => provisionPrivateReplayLedger({
        key: weakKey, databasePath: f.databasePath
      }), /invalidOwnerRelayKey/);
      assert.equal(existsSync(f.databasePath), false);
    }
    provisionPrivateReplayLedger(f);
    assert.throws(() => createDurableOwnerProposalAdmission({
      key: Buffer.alloc(32), databasePath: f.databasePath
    }), /invalidOwnerRelayKey/);
  } finally { f.cleanup(); }
});

test('a signed read-only proposal persists but is never executed', () => {
  const f = fixture();
  try {
    const verifier = admission(f);
    const signed = proposal(f.key);
    const result = verifier.admit(signed);
    assert.equal(result.state, 'authenticated-proposal-only');
    assert.equal(result.replayProtection, 'persistent-local-sqlite');
    assert.equal(result.actionExecuted, false);
    assert.equal(result.ownerApproved, false);
    assert.equal(result.deviceReceipt, 'none');
    assert.equal(result.iPhoneConnected, 'not-checked');
    assert.equal(lstatSync(f.databasePath).mode & 0o077, 0);
    // A request digest, not the raw UUID, signature, or secret, is on disk.
    const raw = readFileSync(f.databasePath);
    assert.equal(raw.includes(Buffer.from(signed.body.requestId)), false);
    assert.equal(raw.includes(Buffer.from(signed.signature)), false);
    assert.equal(raw.includes(f.key), false);
    verifier.close();
    assert.throws(() => verifier.admit(signed), /replayDatabaseClosed/);
    verifier.close();
  } finally { f.cleanup(); }
});

test('same ID cannot be replayed after admission process restarts', () => {
  const f = fixture();
  try {
    const signed = proposal(f.key);
    const first = admission(f);
    first.admit(signed);
    first.close();
    const restarted = admission(f);
    assert.throws(() => restarted.admit(signed), /replayedTaskEnvelope/);
    restarted.close();
  } finally { f.cleanup(); }
});

test('independent database connections serialize duplicate claims', () => {
  const f = fixture();
  try {
    const a = admission(f), b = admission(f);
    const signed = proposal(f.key);
    assert.equal(a.admit(signed).actionExecuted, false);
    assert.throws(() => b.admit(signed), /replayedTaskEnvelope/);
    a.close();
    b.close();
  } finally { f.cleanup(); }
});

test('replay persists across separate OS processes', () => {
  const f = fixture();
  try {
    const signed = proposal(f.key);
    const subprogram = `
      import { createDurableOwnerProposalAdmission } from '${new URL('../src/durable-task-admission.mjs', import.meta.url).href}';
      import { readFileSync } from 'node:fs';
      const input = JSON.parse(readFileSync(0, 'utf8'));
      const verifier = createDurableOwnerProposalAdmission({
        key: Buffer.from(input.key, 'hex'), databasePath: input.path,
        nowSeconds: () => input.now
      });
      try { verifier.admit(input.signed); console.log('ACCEPT'); }
      catch (error) { console.log(error.message); }
      verifier.close();
    `;
    // Synthetic test-only key is passed on stdin, never through argv or env.
    const input = JSON.stringify({
      key: f.key.toString('hex'), path: f.databasePath, now: NOW, signed
    });
    function run() {
      const child = spawnSync(process.execPath,
        ['--input-type=module', '-e', subprogram], { input, encoding: 'utf8' });
      assert.equal(child.status, 0, child.stderr);
      return child.stdout.trim();
    }
    assert.equal(run(), 'ACCEPT');
    assert.equal(run(), 'replayedTaskEnvelope');
  } finally { f.cleanup(); }
});

test('unsigned, forged, unsafe and expired proposals cannot mutate the ledger', () => {
  const f = fixture();
  try {
    const verifier = admission(f);
    const signed = proposal(f.key);
    assert.throws(() => verifier.admit({
      ...signed, signature: '0'.repeat(64)
    }), /unauthenticatedTaskEnvelope/);
    assert.throws(() => verifier.admit({
      ...signed, body: { ...signed.body, capability: 'reminder.create' }
    }), /invalidTaskEnvelope/);
    assert.throws(() => verifier.admit({
      ...signed, body: { ...signed.body, ownerApproved: true }
    }), /invalidTaskEnvelope/);
    assert.throws(() => verifier.admit(proposal(f.key, NOW - 61)),
      /expiredOrFutureTaskEnvelope/);
    // Invalid attempts did not claim a nonce in the durable ledger.
    assert.equal(verifier.admit(signed).actionExecuted, false);
    verifier.close();
  } finally { f.cleanup(); }
});

test('expired records can be pruned safely and storage capacity fails closed', () => {
  const f = fixture();
  try {
    let now = NOW;
    const verifier = admission(f, () => now, 1);
    verifier.admit(proposal(f.key, now, { ttlSeconds: 2 }));
    assert.throws(() => verifier.admit(proposal(f.key, now)),
      /ownerRelayCapacityReached/);
    now += 3;
    assert.equal(verifier.admit(proposal(f.key, now)).actionExecuted, false);
    verifier.close();
  } finally { f.cleanup(); }
});

test('private directory, regular database file, and absolute path are mandatory', () => {
  const f = fixture();
  const target = join(f.dir, 'elsewhere.sqlite');
  try {
    const relative = () => createDurableOwnerProposalAdmission({
      key: f.key, databasePath: './admissions.sqlite'
    });
    assert.throws(relative, /invalidReplayDatabaseConfig/);
    chmodSync(f.dir, 0o755);
    assert.throws(() => admission(f), /insecureReplayDatabaseDirectory/);
    chmodSync(f.dir, 0o700);
    rmSync(f.databasePath);
    symlinkSync(target, f.databasePath);
    assert.throws(() => admission(f), /insecureReplayDatabaseFile/);
    rmSync(f.databasePath);
    const fd = openSync(f.databasePath, 'w', 0o644);
    closeSync(fd);
    assert.throws(() => admission(f), /insecureReplayDatabaseFile/);
  } finally { f.cleanup(); }
});

test('filesystem corruption fails closed; no fallback to volatile replay protection', () => {
  const f = fixture();
  try {
    const verifier = admission(f);
    verifier.admit(proposal(f.key));
    verifier.close();
    // Corrupt the on-disk state after a successful admission.
    const fd = openSync(f.databasePath, 'w', 0o600);
    closeSync(fd);
    assert.throws(() => admission(f));
  } finally { f.cleanup(); }
});

test('neither task delivery nor remote device access is included in this ledger', () => {
  const src = readFileSync(new URL('../src/durable-task-admission.mjs',
    import.meta.url), 'utf8');
  assert.doesNotMatch(src, /from ['"]node:(?:http|https|net|child_process)['"]/);
  assert.doesNotMatch(src, /\bfetch\s*\(|\bspawn\s*\(|createServer\s*\(/);
});

test('missing database cannot be silently recreated; explicit provisioning is one-time', () => {
  const f = fixture({ provisioned: false });
  try {
    assert.equal(existsSync(f.databasePath), false);
    assert.throws(() => admission(f), /replayDatabaseNotProvisioned/);
    assert.equal(existsSync(f.databasePath), false);
    provisionPrivateReplayLedger(f);
    const verifier = admission(f);
    assert.equal(verifier.admit(proposal(f.key)).actionExecuted, false);
    verifier.close();
    assert.throws(() => provisionPrivateReplayLedger(f), /EEXIST/);
    rmSync(f.databasePath);
    assert.throws(() => admission(f), /replayDatabaseNotProvisioned/);
  } finally { f.cleanup(); }
});

test('sealed database rejects wrong owner key and a still-open removed database', () => {
  const f = fixture();
  try {
    assert.throws(() => createDurableOwnerProposalAdmission({
      key: randomBytes(32), databasePath: f.databasePath
    }), /replayDatabaseSealInvalid/);
    const verifier = admission(f);
    rmSync(f.databasePath);
    assert.throws(() => verifier.admit(proposal(f.key)),
      /replayDatabaseNotProvisioned/);
    verifier.close();
  } finally { f.cleanup(); }
});
