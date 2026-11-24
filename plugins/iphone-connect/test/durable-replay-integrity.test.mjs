import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import {
  provisionPrivateReplayLedger, createDurableOwnerProposalAdmission
} from '../src/durable-task-admission.mjs';
import { prepareSignedReadOnlyProposal }
  from '../src/authenticated-task-envelope.mjs';

const NOW = 2_000_000_000;
function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), 'igentic-integrity-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const key = randomBytes(32);
  const databasePath = join(dir, 'admission.sqlite');
  provisionPrivateReplayLedger({key, databasePath});
  const open = () => createDurableOwnerProposalAdmission({
    key, databasePath, nowSeconds: () => NOW
  });
  const proposal = () => prepareSignedReadOnlyProposal({key, issuedAt:NOW});
  return { open, proposal, databasePath, key };
}

test('deleting an admitted row with ordinary SQLite must fail closed after restart', t => {
  const f = fixture(t);
  const original = f.proposal();
  const first = f.open();
  assert.equal(first.admit(original).actionExecuted, false);
  first.close();

  const attacker = new DatabaseSync(f.databasePath);
  attacker.exec('DELETE FROM admitted');
  attacker.close();

  assert.throws(() => f.open(), /replayDatabase.*Invalid|replayDatabase.*Failed/);
});

test('changing an admitted expiry must not bypass the replay window', t => {
  const f = fixture(t);
  const verifier = f.open();
  verifier.admit(f.proposal());
  verifier.close();

  const attacker = new DatabaseSync(f.databasePath);
  attacker.exec('UPDATE admitted SET expires_at = expires_at - 1');
  attacker.close();

  assert.throws(() => f.open(), /replayDatabase.*Invalid|replayDatabase.*Failed/);
});

test('tampering between two proposals must invalidate an already open verifier', t => {
  const f = fixture(t);
  const verifier = f.open();
  verifier.admit(f.proposal());

  const attacker = new DatabaseSync(f.databasePath);
  attacker.exec('DELETE FROM admitted');
  attacker.close();

  assert.throws(() => verifier.admit(f.proposal()),
    /replayDatabase.*Invalid|replayDatabase.*Failed/);
  verifier.close();
});

test('ordinary admissions from two valid handles keep the integrity seal in sync', t => {
  const f = fixture(t);
  const first = f.open();
  const second = f.open();
  assert.equal(first.admit(f.proposal()).actionExecuted, false);
  assert.equal(second.admit(f.proposal()).actionExecuted, false);
  first.close();
  second.close();
  const restarted = f.open();
  assert.equal(restarted.admit(f.proposal()).actionExecuted, false);
  restarted.close();
});
