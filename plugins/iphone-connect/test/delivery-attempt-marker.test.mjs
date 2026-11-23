import test from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes, randomUUID} from 'node:crypto';
import {
  mkdtempSync, rmSync, readdirSync, readFileSync, chmodSync, symlinkSync
} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createPrivateDeliveryAttemptMarker}
  from '../src/delivery-attempt-marker.mjs';
import {
  prepareSignedReadOnlyProposal, createOwnerProposalAdmission
} from '../src/authenticated-task-envelope.mjs';
import {createTransportNeutralAgentLoop}
  from '../src/agent-loop-protocol.mjs';

const NOW = 2_000_000_000;
function fixture(t) {
  const directory = mkdtempSync(join(tmpdir(), 'igentic-writeahead-'));
  t.after(() => rmSync(directory, {force:true, recursive:true}));
  const key = randomBytes(32);
  const marker = () => createPrivateDeliveryAttemptMarker({directory,key});
  const ownerKey = randomBytes(32), receiptKey = randomBytes(32);
  const proposal = () => prepareSignedReadOnlyProposal({key:ownerKey,issuedAt:NOW});
  const loop = (guard = marker(), nowSeconds = () => NOW) => createTransportNeutralAgentLoop({
    admission:createOwnerProposalAdmission({key:ownerKey,nowSeconds:()=>NOW}),
    receiptKey,nowSeconds,deliveryAttemptMarker:guard
  });
  return {directory,key,marker,proposal,loop};
}

test('marker fsyncs before delivery payload and recovers unknown after restart',t=>{
  const f=fixture(t), l=f.loop(), envelope=f.proposal();
  const id=envelope.body.requestId;
  l.start({envelope,entryPoint:'chatgpt-site'});
  const prepared=l.prepareDelivery({requestId:id,route:'cellular-foreground'});
  assert.equal(prepared.status,'prepared-not-sent');
  assert.equal(l.snapshot().deliveryAttempted,false);
  assert.equal(prepared.actionExecuted,false);
  const recovered=f.marker().recover({requestId:id});
  assert.equal(recovered.state,'outcome-unknown');
  assert.equal(recovered.actionExecuted,false);
  assert.equal(recovered.automaticRetryAllowed,false);
  assert.equal(recovered.deviceReceipt,'none');
  assert.ok(Object.isFrozen(recovered));
});

test('a second loop after simulated crash cannot prepare the same request',t=>{
  const f=fixture(t), envelope=f.proposal();
  const id=envelope.body.requestId;
  const first=f.loop();
  first.start({envelope,entryPoint:'chatgpt-site'});
  first.prepareDelivery({requestId:id,route:'coredevice-wifi'});
  const restarted=f.loop();
  restarted.start({envelope,entryPoint:'manual-client'});
  assert.throws(()=>restarted.prepareDelivery({requestId:id,route:'coredevice-usb'}),
    /deliveryAlreadyPreparedOrUncertain/);
  assert.equal(restarted.snapshot().state,'awaiting-manual-delivery');
  assert.equal(restarted.snapshot().attemptCount,0);
  assert.equal(restarted.snapshot().actionExecuted,false);
});

test('two independent marker handles reject duplicate reservations',t=>{
  const f=fixture(t), id=randomUUID(), nonce=randomUUID();
  const one=f.marker(), two=f.marker();
  assert.equal(one.markPrepared({requestId:id,receiptNonce:nonce,route:'local-shortcuts'}),true);
  assert.throws(()=>two.markPrepared({
    requestId:id,receiptNonce:randomUUID(),route:'coredevice-usb'
  }),/deliveryAlreadyPreparedOrUncertain/);
});

test('marker filenames and empty bodies reveal no request ID, key or nonce',t=>{
  const f=fixture(t), id=randomUUID(), nonce=randomUUID();
  f.marker().markPrepared({requestId:id,receiptNonce:nonce,route:'local-shortcuts'});
  const files=readdirSync(f.directory);
  assert.equal(files.length,1);
  assert.match(files[0],/^[0-9a-f]{64}\.attempt$/);
  assert.equal(files[0].includes(id),false);
  const body=readFileSync(join(f.directory,files[0]));
  assert.equal(body.length,0);
  assert.equal(body.includes(f.key),false);
  assert.equal(body.includes(Buffer.from(nonce)),false);
});

test('unsafe directory and symlink alias fail closed',t=>{
  const f=fixture(t);
  const alias=join(f.directory,'..','igentic-alias-'+randomUUID());
  symlinkSync(f.directory,alias);
  t.after(()=>rmSync(alias,{force:true}));
  assert.throws(()=>createPrivateDeliveryAttemptMarker({
    directory:alias,key:f.key
  }),/deliveryMarkerUnavailable/);
  chmodSync(f.directory,0o755);
  assert.throws(()=>f.marker(),/deliveryMarkerUnavailable/);
});

test('unknown or invalid command routes and secret material never create a marker',t=>{
  const f=fixture(t), marker=f.marker(), id=randomUUID(), nonce=randomUUID();
  for (const route of ['shell','reminder.create','other-app','',null]) {
    assert.throws(()=>marker.markPrepared({requestId:id,receiptNonce:nonce,route}),
      /invalidDeliveryMarkerRequest/);
  }
  assert.throws(()=>marker.markPrepared({
    requestId:'unsafe',receiptNonce:nonce,route:'local-shortcuts'
  }),/invalidDeliveryMarkerRequest/);
  assert.throws(()=>marker.markPrepared({
    requestId:id,receiptNonce:'unsafe',route:'local-shortcuts'
  }),/invalidDeliveryMarkerRequest/);
  assert.equal(readdirSync(f.directory).length,0);
  assert.throws(()=>createPrivateDeliveryAttemptMarker({
    directory:f.directory,key:Buffer.alloc(32)
  }),/deliveryMarkerUnavailable/);
});

test('marker failures prevent any prepared or executable delivery payload',t=>{
  const f=fixture(t), envelope=f.proposal(), id=envelope.body.requestId;
  const loop=f.loop({markPrepared(){throw Error('diskUnavailable');}});
  loop.start({envelope,entryPoint:'siri-shortcut'});
  assert.throws(()=>loop.prepareDelivery({
    requestId:id,route:'cellular-foreground'
  }),/diskUnavailable/);
  assert.equal(loop.snapshot().state,'awaiting-manual-delivery');
  assert.equal(loop.snapshot().deliveryAttempted,false);
  assert.equal(loop.snapshot().attemptCount,0);
  assert.equal(loop.snapshot().actionExecuted,false);
});

test('unconfigured or falsifying persistence interfaces fail closed',t=>{
  const f=fixture(t), envelope=f.proposal(), id=envelope.body.requestId;
  assert.throws(()=>f.loop({}),/invalidAgentLoopTransition/);
  const loop=f.loop({markPrepared(){return false;}});
  loop.start({envelope,entryPoint:'manual-client'});
  assert.throws(()=>loop.prepareDelivery({
    requestId:id,route:'local-shortcuts'
  }),/invalidAgentLoopTransition/);
  assert.equal(loop.snapshot().state,'awaiting-manual-delivery');
});


test('an expired prepared payload has unknown delivery, not before-send certainty', t=>{
  const f=fixture(t), envelope=f.proposal(), id=envelope.body.requestId;
  let clock=NOW;
  const loop=f.loop(f.marker(),()=>clock);
  loop.start({envelope,entryPoint:'chatgpt-site'});
  const prepared=loop.prepareDelivery({requestId:id,route:'cellular-foreground'});
  assert.equal(prepared.status,'prepared-not-sent');
  // The prepared payload already escaped to its adapter. The process can
  // crash or fail to record delivery even after the adapter sends it.
  clock=NOW+61;
  const expired=loop.timeout();
  assert.equal(expired.state,'outcome-unknown');
  assert.equal(expired.actionExecuted,false);
  assert.equal(expired.automaticRetryAllowed,false);
  assert.equal(f.marker().recover({requestId:id}).state,'outcome-unknown');
});

test('a prepared payload cannot be cancelled as definitively not sent', t=>{
  const f=fixture(t), envelope=f.proposal(), id=envelope.body.requestId;
  const loop=f.loop();
  loop.start({envelope,entryPoint:'manual-client'});
  loop.prepareDelivery({requestId:id,route:'coredevice-usb'});
  // Cancellation is safe before payload creation, or after a transport
  // explicitly certifies definitely-not-sent, but not in this gap.
  assert.throws(()=>loop.cancel({requestId:id}),/invalidAgentLoopTransition/);
  assert.equal(loop.snapshot().state,'delivery-prepared-not-sent');
  assert.equal(loop.snapshot().automaticRetryAllowed,false);
  loop.recordTransport({requestId:id,outcome:'definitely-not-sent'});
  assert.equal(loop.cancel({requestId:id}).state,'cancelled-local');
});
