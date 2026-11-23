import test from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes, randomUUID} from 'node:crypto';
import {
  mkdtempSync, rmSync, readdirSync, statSync, unlinkSync,
  writeFileSync, symlinkSync
} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createPrivateDeliveryAttemptMarker}
  from '../src/delivery-attempt-marker.mjs';

const SEAL = '.delivery-key-seal';
function workspace(t) {
  const directory = mkdtempSync(join(tmpdir(), 'igentic-marker-seal-'));
  t.after(() => rmSync(directory, {force:true, recursive:true}));
  const key = randomBytes(32);
  const open = (withKey = key) => createPrivateDeliveryAttemptMarker({
    directory, key: withKey
  });
  const id = randomUUID();
  const reserve = (m) => m.markPrepared({
    requestId:id, receiptNonce:randomUUID(), route:'local-shortcuts'
  });
  return {directory,key,id,open,reserve};
}

test('a rotated filename key may not silently erase an existing prepared attempt',t=>{
  const w=workspace(t), first=w.open();
  w.reserve(first);
  assert.equal(first.recover({requestId:w.id}).state,'outcome-unknown');
  assert.throws(()=>w.open(randomBytes(32)),/deliveryMarkerUnavailable/);
  assert.equal(w.open().recover({requestId:w.id}).automaticRetryAllowed,false);
});

test('a stored key seal exists before any marker can be created',t=>{
  const w=workspace(t), initial=w.open();
  const sealPath=join(w.directory,SEAL);
  assert.equal(statSync(sealPath).mode & 0o077,0);
  assert.equal(statSync(sealPath).size,64);
  w.reserve(initial);
  assert.ok(readdirSync(w.directory).includes(SEAL));
});

test('deleting a key seal blocks both future preparations and recovery',t=>{
  const w=workspace(t), marker=w.open();
  w.reserve(marker);
  unlinkSync(join(w.directory,SEAL));
  assert.throws(()=>marker.recover({requestId:w.id}),/deliveryMarkerUnavailable/);
  assert.throws(()=>marker.markPrepared({
    requestId:randomUUID(),receiptNonce:randomUUID(),route:'local-shortcuts'
  }),/deliveryMarkerUnavailable/);
  assert.throws(()=>w.open(),/deliveryMarkerUnavailable/);
});

test('modifying a key seal fails closed even for an existing marker instance',t=>{
  const w=workspace(t), marker=w.open();
  writeFileSync(join(w.directory,SEAL),'0'.repeat(64),{mode:0o600});
  assert.throws(()=>marker.markPrepared({
    requestId:w.id,receiptNonce:randomUUID(),route:'local-shortcuts'
  }),/deliveryMarkerUnavailable/);
  assert.throws(()=>w.open(),/deliveryMarkerUnavailable/);
});

test('an unsealed nonempty directory cannot be automatically re-provisioned',t=>{
  const w=workspace(t);
  writeFileSync(join(w.directory,'old.attempt'),'',{mode:0o600});
  assert.throws(()=>w.open(),/deliveryMarkerUnavailable/);
});

test('seal symlinks and foreign storage are not trusted',t=>{
  const w=workspace(t), target=join(w.directory,'target');
  writeFileSync(target,'0'.repeat(64),{mode:0o600});
  symlinkSync(target,join(w.directory,SEAL));
  assert.throws(()=>w.open(),/deliveryMarkerUnavailable/);
});
