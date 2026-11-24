import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { mkdtempSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createOwnerDeviceRelay } from '../src/owner-device-relay.mjs';
import { provisionPrivateReplayLedger } from '../src/durable-task-admission.mjs';
import { signReadOnlyDeviceKeyReceipt } from '../src/agent-loop-protocol.mjs';

const NOW = 2_000_000_000;
function fixture(t) {
  const root = mkdtempSync(join(tmpdir(),'igentic-relay-test-'));
  const databasePath=join(root,'replay.sqlite'), markerDirectory=join(root,'attempts');
  mkdirSync(markerDirectory,{mode:0o700});
  const [ownerAccessKey,deviceAccessKey,proposalKey,receiptKey,markerKey] =
    Array.from({length:5},()=>randomBytes(32));
  let current=NOW;
  const config={ownerAccessKey,deviceAccessKey,proposalKey,receiptKey,markerKey,
    databasePath,markerDirectory,nowSeconds:()=>current};
  provisionPrivateReplayLedger({key:proposalKey,databasePath});
  const handles=[];
  const open=()=>{const relay=createOwnerDeviceRelay(config);handles.push(relay);return relay;};
  t.after(()=>{for(const relay of handles) {try{relay.close(ownerAccessKey);}catch{}}rmSync(root,{recursive:true,force:true});});
  return {config,open,ownerAccessKey,deviceAccessKey,receiptKey,setTime:t=>current=t};
}
test('separate roles, one claim, exact receipt and no execution claim',t=>{
  const f=fixture(t), relay=f.open(), id=randomUUID();
  const o=f.ownerAccessKey,d=f.deviceAccessKey;
  assert.throws(()=>relay.submit(d,id),/relayAccessDenied/);
  assert.throws(()=>relay.status(d),/relayAccessDenied/);
  assert.equal(relay.claim(d),null);
  assert.equal(relay.submit(o,id).state,'awaiting-manual-delivery');
  assert.throws(()=>relay.claim(o),/relayAccessDenied/);
  assert.equal(relay.status(o).receiptNonce,undefined);
  const delivery=relay.claim(d);
  assert.equal(JSON.parse(delivery.canonicalWire).body.requestId,id);
  assert.equal(relay.claim(d),null);
  assert.equal(relay.status(o).state,'outcome-unknown');
  const sign=nonce=>signReadOnlyDeviceKeyReceipt({key:f.receiptKey,requestId:id,nonce,observedAt:NOW});
  assert.throws(()=>relay.acceptReceipt(o,sign(delivery.receiptNonce)),/relayAccessDenied/);
  assert.throws(()=>relay.acceptReceipt(d,sign(randomUUID())),/invalidAgentLoopReceipt/);
  const result=relay.acceptReceipt(d,sign(delivery.receiptNonce));
  assert.equal(result.receiptKeyAuthenticated,true);
  assert.equal(result.actionExecuted,false);
  assert.equal(result.ownerApproved,false);
  assert.equal(result.iPhoneConnected,'not-checked');
  assert.equal(relay.status(o).state,'receipt-key-authenticated');
  assert.equal(relay.status(o).receiptKeyAuthenticated,true);
  assert.throws(()=>relay.acceptReceipt(d,sign(delivery.receiptNonce)),/invalidAgentLoopTransition/);
});
test('lost claim and restart recover only uncertainty; same task cannot be reissued',t=>{
  const f=fixture(t), o=f.ownerAccessKey,d=f.deviceAccessKey,id=randomUUID();
  const first=f.open();first.submit(o,id);first.claim(d);first.close(o);
  const next=f.open();
  assert.equal(next.result(o,id),null);
  assert.equal(next.recover(o,id).state,'outcome-unknown');
  assert.equal(next.recover(o,id).automaticRetryAllowed,false);
  assert.throws(()=>next.submit(o,id),/relayDeliveryAlreadyUncertain/);
  f.setTime(NOW+120);
  assert.throws(()=>next.submit(o,id),/relayDeliveryAlreadyUncertain/);
  assert.equal(next.claim(d),null);
});
test('expired or cancelled tasks never release a delivery',t=>{
  const f=fixture(t),o=f.ownerAccessKey,d=f.deviceAccessKey;
  const first=f.open(), id=randomUUID();first.submit(o,id);
  f.setTime(NOW+60);assert.equal(first.claim(d),null);
  assert.equal(first.status(o).state,'expired-before-send');
  const second=f.open(), next=randomUUID();second.submit(o,next);
  second.cancel(o,next);assert.equal(second.claim(d),null);
});
test('key reuse and caller mutation cannot expand relay authority',t=>{
  const f=fixture(t);
  assert.throws(()=>createOwnerDeviceRelay({...f.config,deviceAccessKey:f.ownerAccessKey}),/invalidRelayConfig/);
  const relay=f.open(), old=Buffer.from(f.ownerAccessKey);
  f.ownerAccessKey.fill(0);
  assert.throws(()=>relay.status(f.ownerAccessKey),/relayAccessDenied/);
  assert.equal(relay.status(old).state,'empty');
  relay.close(old);
  assert.throws(()=>relay.status(old),/relayAccessDenied/);
});


test('expiry after delivery preparation prevents payload and receipt even after rollback',t=>{
  const f=fixture(t),o=f.ownerAccessKey,d=f.deviceAccessKey,id=randomUUID();
  let armed=false,reads=0;
  const relay=createOwnerDeviceRelay({...f.config,nowSeconds:()=>armed&&++reads===6?NOW+60:NOW});
  t.after(()=>relay.close(o));
  relay.submit(o,id);
  armed=true;
  assert.equal(relay.claim(d),null);
  assert.equal(relay.status(o).state,'outcome-unknown');
  assert.equal(relay.claim(d),null);
  assert.throws(()=>relay.acceptReceipt(d,{}),/invalidAgentLoopTransition/);
  assert.throws(()=>relay.cancel(o,id),/invalidAgentLoopTransition/);
});

test('a device cannot claim after the clock moves before task issuance', t => {
  const f = fixture(t), relay = f.open(), id = randomUUID();
  relay.submit(f.ownerAccessKey, id);
  f.setTime(NOW - 1);
  assert.equal(relay.claim(f.deviceAccessKey), null);
  f.setTime(NOW);
  assert.equal(relay.claim(f.deviceAccessKey), null);
  assert.equal(relay.status(f.ownerAccessKey).state, 'expired-before-send');
});

test('receipt accepted before a clock rollback remains visible to its owner', t => {
  const f = fixture(t), relay = f.open(), id = randomUUID();
  relay.submit(f.ownerAccessKey, id);
  const delivery = relay.claim(f.deviceAccessKey);
  const receipt = signReadOnlyDeviceKeyReceipt({
    key: f.receiptKey, requestId: id, nonce: delivery.receiptNonce, observedAt: NOW
  });
  relay.acceptReceipt(f.deviceAccessKey, receipt);
  f.setTime(NOW - 1);
  assert.equal(relay.status(f.ownerAccessKey).state, 'receipt-key-authenticated');
});
