import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { chmodSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { createDurableTaskReplayStore } from '../src/durable-task-replay-store.mjs';
import { createOwnerProposalAdmission, prepareSignedReadOnlyProposal }
  from '../src/authenticated-task-envelope.mjs';

function fixture(t) {
  const directory = mkdtempSync(join(tmpdir(), 'igentic-replay-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  return { directory, filePath: join(directory, 'one-owner.sqlite') };
}
const issuedAt = 2_000_000_000;
const key = randomBytes(32);
const envelope = (id = randomUUID(), at = issuedAt, secret = key) =>
  prepareSignedReadOnlyProposal({key: secret, issuedAt: at, requestId: id});

test('a signed proposal cannot be admitted twice after close/reopen', t => {
  const { filePath } = fixture(t);
  const req = envelope();
  const store = createDurableTaskReplayStore({ filePath });
  const a = createOwnerProposalAdmission({key, nowSeconds: () => issuedAt, replayStore: store});
  assert.equal(a.admit(req).actionExecuted, false);
  assert.throws(() => a.admit(req), /replayedTaskEnvelope/);
  store.close();
  const reopened = createDurableTaskReplayStore({ filePath });
  t.after(() => reopened.close());
  const b = createOwnerProposalAdmission({key, nowSeconds: () => issuedAt, replayStore: reopened});
  assert.throws(() => b.admit(req), /replayedTaskEnvelope/);
  assert.equal(b.admit(envelope()).state, 'authenticated-proposal-only');
});
 
test('two simultaneous connections share one atomic replay boundary', t => {
  const { filePath } = fixture(t);
  const one = createDurableTaskReplayStore({ filePath });
  const two = createDurableTaskReplayStore({ filePath });
  t.after(() => { one.close(); two.close(); });
  const opts = {key, nowSeconds: () => issuedAt};
  const a = createOwnerProposalAdmission({...opts, replayStore: one});
  const b = createOwnerProposalAdmission({...opts, replayStore: two});
  const req = envelope();
  assert.equal(a.admit(req).ownerApproved, false);
  assert.throws(() => b.admit(req), /replayedTaskEnvelope/);
  assert.equal(b.admit(envelope()).actionExecuted, false);
});

test('invalid MAC is never recorded; expiry and capacity stay bounded', t => {
  const { filePath } = fixture(t);
  const store = createDurableTaskReplayStore({ filePath });
  t.after(() => store.close());
  let now = issuedAt;
  const admission = createOwnerProposalAdmission({
    key, replayStore: store, nowSeconds: () => now, maxInflight: 1
  });
  const id = randomUUID();
  assert.throws(() => admission.admit(envelope(id, issuedAt, randomBytes(32))),
    /unauthenticatedTaskEnvelope/);
  assert.equal(admission.admit(envelope(id)).state, 'authenticated-proposal-only');
  assert.throws(() => admission.admit(envelope()), /ownerRelayCapacityReached/);
  now += 61;
  assert.equal(admission.admit(envelope(randomUUID(), now)).actionExecuted, false);
  assert.throws(() => admission.admit(envelope(id, now)), /ownerRelayCapacityReached/);
});

test('a second OS process cannot reuse one persisted request', t => {
  const { filePath } = fixture(t);
  const requestId = randomUUID();
  const moduleURL = new URL('../src/durable-task-replay-store.mjs', import.meta.url).href;
  const child = [
    'import { createDurableTaskReplayStore } from ' + JSON.stringify(moduleURL) + ';',
    'const [filePath, id, t] = process.argv.slice(1);',
    'const db = createDurableTaskReplayStore({ filePath });',
    'try { db.reserve({ requestId:id, now:Number(t),',
    'expiresAt:Number(t)+60, maxEntries:4 }); console.log("admitted"); }',
    'catch (e) { console.error(e.message); process.exitCode=2; }',
    'finally { db.close(); }'
  ].join('\n');
  const run = () => spawnSync(process.execPath, [
    '--input-type=module', '-e', child, '--', filePath, requestId, String(issuedAt)
  ], { encoding:'utf8', timeout:8000 });
  const first=run();
  assert.equal(first.status,0,first.stderr);
  assert.match(first.stdout,/admitted/);
  const second=run();
  assert.equal(second.status,2);
  assert.match(second.stderr,/replayedTaskEnvelope/);
});

test('replay file has private permissions and never stores owner key or action', t => {
  const {filePath}=fixture(t);
  const store=createDurableTaskReplayStore({filePath});
  const admission=createOwnerProposalAdmission({
    key, nowSeconds:()=>issuedAt, replayStore:store
  });
  admission.admit(envelope());
  store.close();
  assert.equal(lstatSync(filePath).mode & 0o077,0);
  const bytes=readFileSync(filePath);
  assert.equal(bytes.includes(key),false);
  assert.equal(bytes.includes(Buffer.from('igentic.own_app.status.read')),false);
});

test('invalid file, link and directory privileges fail closed before opening', t => {
  const { directory, filePath } = fixture(t);
  assert.throws(() => createDurableTaskReplayStore({filePath: ':memory:'}),
    /ownerReplayStoreUnavailable/);
  const unsafeDir = join(directory, 'unsafe');
  mkdirSync(unsafeDir, { mode: 0o777 });
  chmodSync(unsafeDir, 0o777);
  assert.throws(()=>createDurableTaskReplayStore({filePath:join(unsafeDir,'db.sqlite')}),
    /ownerReplayStoreUnavailable/);
  writeFileSync(filePath, 'bad', {mode:0o600});
  chmodSync(filePath, 0o644);
  assert.throws(()=>createDurableTaskReplayStore({filePath}),
    /ownerReplayStoreUnavailable/);
  const other = join(directory, 'other.sqlite');
  writeFileSync(other, 'not sqlite', {mode:0o600});
  const alias = join(directory,'alias.sqlite');
  symlinkSync(other,alias);
  assert.throws(()=>createDurableTaskReplayStore({filePath:alias}),
    /ownerReplayStoreUnavailable/);
  assert.equal(lstatSync(alias).isSymbolicLink(), true);
});

test('admission refuses an unusable persistent store and never claims execution', t => {
  const { filePath } = fixture(t);
  const store = createDurableTaskReplayStore({ filePath });
  const admission = createOwnerProposalAdmission({
    key, nowSeconds: () => issuedAt, replayStore: store
  });
  store.close();
  assert.throws(() => admission.admit(envelope()), /ownerReplayStoreUnavailable/);
  assert.throws(() => createOwnerProposalAdmission({key, replayStore: {}}),
    /invalidOwnerRelayConfig/);
});
