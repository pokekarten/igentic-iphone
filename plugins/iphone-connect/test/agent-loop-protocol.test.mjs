import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { createOwnerProposalAdmission, prepareSignedReadOnlyProposal }
  from '../src/authenticated-task-envelope.mjs';
import { createTransportNeutralAgentLoop, signReadOnlyDeviceKeyReceipt }
  from '../src/agent-loop-protocol.mjs';

const time = 2_000_000_000;
const relayKey = randomBytes(32);
const deviceKey = randomBytes(32);
const signed = (issuedAt = time) =>
  prepareSignedReadOnlyProposal({ key: relayKey, issuedAt, requestId: randomUUID() });
const make = (clock = () => time, localKey = deviceKey) => {
  const admission = createOwnerProposalAdmission({ key: relayKey, nowSeconds: clock });
  return createTransportNeutralAgentLoop({ admission, receiptKey: localKey, nowSeconds: clock });
};
const entryPoints = [
  'chatgpt-site', 'shortcuts-chatgpt', 'siri-shortcut',
  'igentic-app', 'local-model', 'manual-client'
];
const routes = ['cellular-foreground', 'coredevice-usb', 'coredevice-wifi', 'local-shortcuts'];

test('six entry points, four routes are capability-bound and never execute', () => {
  for (const entryPoint of entryPoints) for (const route of routes) {
    const loop = make(), envelope = signed();
    const open = loop.start({ envelope, entryPoint });
    assert.equal(open.state, 'awaiting-manual-delivery');
    assert.equal(open.ownerApproved, false);
    assert.equal(open.actionExecuted, false);
    const prepared = loop.prepareDelivery({ requestId: envelope.body.requestId, route });
    assert.equal(prepared.status, 'prepared-not-sent');
    assert.equal(prepared.iPhoneConnected, 'not-checked');
    assert.equal(loop.snapshot().deliveryAttempted, false);
    const result = loop.recordTransport({
      requestId: envelope.body.requestId, outcome: 'definitely-not-sent'
    });
    assert.equal(result.state, 'not-sent');
    assert.equal(result.automaticRetryAllowed, false);
    assert.equal(result.deviceReceipt, 'none');
  }
});

test('successful key possession is not evidence of physical iPhone execution', () => {
  const loop = make(), envelope = signed();
  const id = envelope.body.requestId;
  loop.start({ envelope, entryPoint: 'chatgpt-site' });
  const prepared = loop.prepareDelivery({
    requestId: id, route: 'cellular-foreground'
  });
  loop.recordTransport({ requestId: id, outcome: 'transport-acknowledged' });
  const receipt = signReadOnlyDeviceKeyReceipt({
    key: deviceKey, requestId: id, observedAt: time, nonce: prepared.receiptNonce
  });
  const result = loop.acceptKeyReceipt(receipt);
  assert.equal(result.state, 'receipt-key-authenticated');
  assert.equal(result.receiptKeyAuthenticated, true);
  assert.equal(result.deviceReceipt, 'key-authenticated-not-device-attested');
  assert.equal(result.actionExecuted, false);
  assert.equal(result.ownerApproved, false);
  assert.equal(result.iPhoneConnected, 'not-checked');
  assert.throws(() => loop.acceptKeyReceipt(receipt), /invalidAgentLoopTransition/);
});

test('a signed receipt with an arbitrary nonce cannot complete this delivery', () => {
  const loop = make(), envelope = signed();
  const requestId = envelope.body.requestId;
  loop.start({ envelope, entryPoint: 'chatgpt-site' });
  const preparation = loop.prepareDelivery({
    requestId, route: 'coredevice-wifi'
  });
  assert.match(preparation.receiptNonce,
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  assert.equal(Object.hasOwn(loop.snapshot(), 'receiptNonce'), false);
  loop.recordTransport({ requestId, outcome: 'transport-acknowledged' });

  const forgedNonce = signReadOnlyDeviceKeyReceipt({
    key: deviceKey, requestId, nonce: randomUUID(), observedAt: time
  });
  assert.throws(() => loop.acceptKeyReceipt(forgedNonce),
    /invalidAgentLoopReceipt/);
  assert.equal(loop.snapshot().state, 'awaiting-key-authenticated-receipt');
  assert.equal(loop.snapshot().receiptKeyAuthenticated, false);

  const exact = signReadOnlyDeviceKeyReceipt({
    key: deviceKey, requestId, nonce: preparation.receiptNonce, observedAt: time
  });
  const result = loop.acceptKeyReceipt(exact);
  assert.equal(result.state, 'receipt-key-authenticated');
  assert.equal(result.actionExecuted, false);
  assert.equal(result.iPhoneConnected, 'not-checked');
});

test('separate task preparations cannot share the same receipt challenge', () => {
  const a = make(), b = make();
  const first = signed(), second = signed();
  a.start({ envelope: first, entryPoint: 'manual-client' });
  b.start({ envelope: second, entryPoint: 'manual-client' });
  const one = a.prepareDelivery({
    requestId: first.body.requestId, route: 'coredevice-usb'
  });
  const two = b.prepareDelivery({
    requestId: second.body.requestId, route: 'coredevice-usb'
  });
  assert.notEqual(one.receiptNonce, two.receiptNonce);
  assert.throws(() => a.prepareDelivery({
    requestId: first.body.requestId, route: 'coredevice-usb'
  }), /invalidAgentLoopTransition/);
});

test('model text, spoofed action or forged owner approval cannot enter a loop', () => {
  for (const entryPoint of ['system-shell', 'open-messages', '', null]) {
    const loop = make();
    assert.throws(() => loop.start({ envelope: signed(), entryPoint }),
      /invalidAgentLoopTransition/);
  }
  const loop = make(), envelope = signed();
  assert.throws(() => loop.start({ envelope: { ...envelope,
    body: { ...envelope.body, capability: 'reminder.create' } },
    entryPoint: 'chatgpt-site' }), /invalidTaskEnvelope/);
  assert.equal(loop.snapshot().state, 'empty');
});

test('wrong request, routes, and untrusted transport statuses are rejected', () => {
  const loop = make(), envelope = signed(), requestId = envelope.body.requestId;
  loop.start({ envelope, entryPoint: 'siri-shortcut' });
  for (const route of ['remote-shell', 'other-app', null]) {
    assert.throws(() => loop.prepareDelivery({ requestId, route }),
      /invalidAgentLoopTransition/);
  }
  assert.throws(() => loop.prepareDelivery({
    requestId: randomUUID(), route: 'cellular-foreground'
  }), /invalidAgentLoopTransition/);
  loop.prepareDelivery({ requestId, route: 'cellular-foreground' });
  assert.throws(() => loop.recordTransport({
    requestId, outcome: 'executed-on-iphone'
  }), /invalidAgentLoopTransition/);
  assert.equal(loop.snapshot().state, 'delivery-prepared-not-sent');
});

test('ambiguous delivery and timeout prohibit automatic retry and success', () => {
  const loop = make(), envelope = signed(), requestId = envelope.body.requestId;
  loop.start({ envelope, entryPoint: 'igentic-app' });
  loop.prepareDelivery({ requestId, route: 'cellular-foreground' });
  const snap = loop.recordTransport({ requestId, outcome: 'sent-unconfirmed' });
  assert.equal(snap.state, 'outcome-unknown');
  assert.equal(snap.automaticRetryAllowed, false);
  assert.equal(snap.actionExecuted, false);
  assert.throws(() => loop.prepareDelivery({
    requestId, route: 'cellular-foreground'
  }), /invalidAgentLoopTransition/);
  assert.throws(() => loop.cancel({ requestId }), /invalidAgentLoopTransition/);
});

test('timeout before sending and after transport observation differ', () => {
  let t = time;
  const loop = make(() => t), envelope = signed();
  const id = envelope.body.requestId;
  loop.start({ envelope, entryPoint: 'chatgpt-site' });
  t += 61;
  assert.equal(loop.timeout().state, 'expired-before-send');
  assert.equal(loop.timeout().actionExecuted, false);

  t = time;
  const second = make(() => t), next = signed();
  second.start({ envelope: next, entryPoint: 'chatgpt-site' });
  second.prepareDelivery({ requestId: next.body.requestId, route: 'coredevice-usb' });
  second.recordTransport({ requestId: next.body.requestId, outcome: 'transport-acknowledged' });
  t += 61;
  assert.equal(second.timeout().state, 'outcome-unknown');
});

test('wrong key, wrong task, future receipt, unexpected fields fail closed', () => {
  const loop = make(), envelope = signed(), requestId = envelope.body.requestId;
  loop.start({ envelope, entryPoint: 'shortcuts-chatgpt' });
  const prepared = loop.prepareDelivery({
    requestId, route: 'local-shortcuts'
  });
  loop.recordTransport({ requestId, outcome: 'transport-acknowledged' });
  const base = signReadOnlyDeviceKeyReceipt({
    key: deviceKey, requestId, observedAt: time, nonce: prepared.receiptNonce
  });
  const rejected = [
    { ...base, signature: '0'.repeat(64) },
    { ...base, body: { ...base.body, ownerApproved: true } },
    { ...base, body: { ...base.body, requestId: randomUUID() } },
    { ...base, body: { ...base.body, observedAt: time + 10 } },
    signReadOnlyDeviceKeyReceipt({
      key: randomBytes(32), requestId, observedAt: time,
      nonce: prepared.receiptNonce
    }),
    signReadOnlyDeviceKeyReceipt({
      key: deviceKey, requestId, observedAt: time, nonce: randomUUID()
    }),
    { ...base, actionExecuted: true },
    { ...base, signature: 'ABC' }
  ];
  for (const altered of rejected) {
    assert.throws(() => loop.acceptKeyReceipt(altered), /invalidAgentLoopReceipt/);
    assert.equal(loop.snapshot().state, 'awaiting-key-authenticated-receipt');
  }
  assert.equal(loop.acceptKeyReceipt(base).actionExecuted, false);
});

test('cancel is local only and cannot claim remote cancellation', () => {
  const loop = make(), envelope = signed(), requestId = envelope.body.requestId;
  loop.start({ envelope, entryPoint: 'local-model' });
  const cancelled = loop.cancel({ requestId });
  assert.equal(cancelled.state, 'cancelled-local');
  assert.equal(cancelled.iPhoneConnected, 'not-checked');
  assert.equal(cancelled.actionExecuted, false);
  assert.throws(() => loop.prepareDelivery({
    requestId, route: 'coredevice-wifi'
  }), /invalidAgentLoopTransition/);
});

test('forged admission status cannot start device work', () => {
  const e = signed();
  const fake = { admit() { return {
    state: 'authenticated-proposal-only', requestId: e.body.requestId,
    capability: 'igentic.own_app.status.read', expiresAt: time + 60,
    actionExecuted: true, ownerApproved: true, iPhoneConnected: 'yes',
    deviceReceipt: 'verified'
  }; } };
  const loop = createTransportNeutralAgentLoop({
    admission: fake, receiptKey: deviceKey, nowSeconds: () => time
  });
  assert.throws(() => loop.start({ envelope: e, entryPoint: 'chatgpt-site' }),
    /invalidAgentLoopTransition/);
});

test('real sealed durable owner admission feeds protocol, replay survives restart', async t => {
  const { mkdtempSync, rmSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  const { provisionPrivateReplayLedger, createDurableOwnerProposalAdmission } =
    await import('../src/durable-task-admission.mjs');
  const dir = mkdtempSync(join(tmpdir(), 'igentic-agent-flow-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const databasePath = join(dir, 'ledger.sqlite');
  const localOwnerKey = randomBytes(32);
  const localDeviceKey = randomBytes(32);
  provisionPrivateReplayLedger({ key: localOwnerKey, databasePath });
  const signedTask = prepareSignedReadOnlyProposal({
    key: localOwnerKey, issuedAt: time
  });
  const verifier = createDurableOwnerProposalAdmission({
    key: localOwnerKey, databasePath, nowSeconds: () => time
  });
  const loop = createTransportNeutralAgentLoop({
    admission: verifier, receiptKey: localDeviceKey, nowSeconds: () => time
  });
  assert.equal(loop.start({
    envelope: signedTask, entryPoint: 'chatgpt-site'
  }).state, 'awaiting-manual-delivery');
  const prepared = loop.prepareDelivery({
    requestId: signedTask.body.requestId, route: 'cellular-foreground'
  });
  assert.equal(prepared.status, 'prepared-not-sent');
  assert.equal(loop.recordTransport({
    requestId: signedTask.body.requestId,
    outcome: 'transport-acknowledged'
  }).state, 'awaiting-key-authenticated-receipt');
  const signedReceipt = signReadOnlyDeviceKeyReceipt({
    key: localDeviceKey, requestId: signedTask.body.requestId,
    nonce: prepared.receiptNonce, observedAt: time
  });
  const status = loop.acceptKeyReceipt(signedReceipt);
  assert.equal(status.receiptKeyAuthenticated, true);
  assert.equal(status.actionExecuted, false);
  assert.equal(status.iPhoneConnected, 'not-checked');
  verifier.close();
  const restarted = createDurableOwnerProposalAdmission({
    key: localOwnerKey, databasePath, nowSeconds: () => time
  });
  t.after(() => restarted.close());
  const second = createTransportNeutralAgentLoop({
    admission: restarted, receiptKey: localDeviceKey, nowSeconds: () => time
  });
  assert.throws(() => second.start({
    envelope: signedTask, entryPoint: 'chatgpt-site'
  }), /replayedTaskEnvelope/);
  assert.equal(second.snapshot().state, 'empty');
});

test('real Site tools are static manual navigation, not an agent action', async () => {
  const { SITES_TOOLS, callSitesTool } = await import(
    '../../igentic-chatgpt-iphone/sites-reference/handoff-site.mjs'
  );
  assert.deepEqual(SITES_TOOLS.map(x => x.name), [
    'iphone_chatgpt_handoff', 'igentic_get_capabilities', 'igentic_shortcuts_setup'
  ]);
  for (const t of SITES_TOOLS) {
    assert.equal(t.annotations.readOnlyHint, true);
    assert.equal(t.annotations.destructiveHint, false);
  }
  const capabilities = callSitesTool('igentic_get_capabilities', {});
  assert.equal(capabilities.iPhoneConnected, 'not-checked');
  assert.equal(capabilities.actionExecuted, false);
  const handoff = callSitesTool('iphone_chatgpt_handoff', { action: 'diagnostics' });
  assert.equal(handoff.actionExecuted, false);
  assert.equal(handoff.requiresOwnerTap, true);
  assert.throws(() => callSitesTool('iphone_execute_iphone', {
    action: 'tap'
  }), /unsupportedSiteToolCall/);
});

test('no network, Apple access or subprocess launcher in protocol module', async () => {
  const { readFile } = await import('node:fs/promises');
  const code = await readFile(new URL('../src/agent-loop-protocol.mjs', import.meta.url), 'utf8');
  assert.doesNotMatch(code, /from ['"]node:(?:http|https|net|child_process)['"]/);
  assert.doesNotMatch(code, /fetch[(]|\\.listen[(]|execFile|process\\.env/);
});
