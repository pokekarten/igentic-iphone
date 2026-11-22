import test from 'node:test';
import assert from 'node:assert/strict';
import {selectedChannel,experimentLink,deliver} from '../src/delivery.mjs';
test('explicit targets and one bounded delivery attempt',async () => {
  assert.equal(selectedChannel({},'darwin').mode,'manual');
  assert.equal(selectedChannel({FIELDGLASS_TARGET:'booted',FIELDGLASS_CHANNEL:'simulator'},'darwin').mode,'configuration-error');
  const device='12345678-1111-4444-8888-123456789abc';
  const link=experimentLink(device,'Öl & +','top');
  const channel=selectedChannel({FIELDGLASS_TARGET:device,FIELDGLASS_CHANNEL:'device'},'darwin');
  let attempts=0;
  const result=await deliver(channel,link,async (cmd,args) => {
    attempts++;
    assert.equal(cmd,'/usr/bin/xcrun');
    assert.deepEqual(args,['devicectl','device','process','launch','--device',device,'--payload-url',link,'org.fieldglass.workbench']);
    throw Error('interrupted');
  }, async () => ({state:'connected'}));
  assert.equal(attempts,1);
  assert.equal(result.status,'delivery-unconfirmed');
});

test('a simulator or stale record cannot authorize physical delivery', async () => {
  const {physicalStatus}=await import('../src/physical.mjs');
  const target='12345678-1111-4444-8888-123456789abc';
  const device={identifier:target,hardwareProperties:{platform:'iOS',reality:'simulated',deviceType:'iPhone'},connectionProperties:{tunnelState:'connected'}};
  const inventory={result:{devices:[device]}};
  assert.equal(physicalStatus(inventory,target).state,'missing');
  device.hardwareProperties.reality='physical';
  assert.equal(physicalStatus(inventory,target).state,'unavailable');
  device.connectionProperties.pairingState='paired';
  device.connectionProperties.tunnelState='available';
  assert.equal(physicalStatus(inventory,target).state,'available');
  device.connectionProperties.tunnelState='connected';
  assert.equal(physicalStatus(inventory,target).state,'connected');
  device.connectionProperties.tunnelState='disconnected';
  let attempts=0;
  const result=await deliver({mode:'device',device:target},'unused',async()=>{attempts++},async()=>physicalStatus(inventory,target));
  assert.equal(result.status,'device-unavailable'); assert.equal(attempts,0);
});
