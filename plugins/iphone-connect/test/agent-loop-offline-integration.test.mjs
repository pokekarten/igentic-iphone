import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { chmodSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { prepareSignedReadOnlyProposal } from '../src/authenticated-task-envelope.mjs';
import {
  createDurableOwnerProposalAdmission, provisionPrivateReplayLedger
} from '../src/durable-task-admission.mjs';
import { createPrivateDeliveryAttemptMarker } from '../src/delivery-attempt-marker.mjs';
import {
  createTransportNeutralAgentLoop, signReadOnlyDeviceKeyReceipt
} from '../src/agent-loop-protocol.mjs';
import { handleSitesMcp } from '../../igentic-chatgpt-iphone/sites-reference/mcp-handler.mjs';

// A real same-origin MCP handler plus real local persistent modules. Every
// device/transport answer is a synthetic, explicitly named fixture. This
// test never starts a server, contacts an iPhone or calls a model provider.
const NOW = 2_000_000_000;
const VERSION = '2026-07-28';
function setup(t, clock = { value: NOW }) {
  const directory = mkdtempSync(join(tmpdir(), 'igentic-full-offline-loop-'));
  const markerDirectory = join(directory, 'attempts');
  mkdirSync(markerDirectory, { mode: 0o700 });
  const databasePath = join(directory, 'replay.sqlite');
  const ownerKey = randomBytes(32);
  const receiptKey = randomBytes(32);
  const markerKey = randomBytes(32);
  const handles = [];
  provisionPrivateReplayLedger({ key: ownerKey, databasePath });
  const ownerAdmission = () => {
    const handle = createDurableOwnerProposalAdmission({
      key: ownerKey, databasePath, nowSeconds: () => clock.value
    });
    handles.push(handle);
    return handle;
  };
  const marker = () => createPrivateDeliveryAttemptMarker({
    directory: markerDirectory, key: markerKey
  });
  t.after(() => {
    for (const handle of handles) handle.close();
    rmSync(directory, { recursive: true, force: true });
  });
  const proposal = (requestId = randomUUID()) =>
    prepareSignedReadOnlyProposal({ key: ownerKey, requestId, issuedAt: clock.value });
  const loop = () => createTransportNeutralAgentLoop({
    admission: ownerAdmission(), receiptKey,
    nowSeconds: () => clock.value,
    deliveryAttemptMarker: marker()
  });
  return {
    directory, databasePath, markerDirectory, ownerKey, receiptKey,
    markerKey, proposal, loop, marker, clock
  };
}

async function siteCall(name, args) {
  const input = new Request('https://owner-site.invalid/mcp', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'Mcp-Protocol-Version': VERSION,
      'Mcp-Method': 'tools/call',
      'Mcp-Name': name
    },
    body: JSON.stringify({
      jsonrpc: '2.0', id: 42, method: 'tools/call',
      params: {
        _meta: {
          'io.modelcontextprotocol/protocolVersion': VERSION,
          'io.modelcontextprotocol/clientCapabilities': {}
        },
        name, arguments: args
      }
    })
  });
  const result = await handleSitesMcp(input);
  assert.equal(result.status, 200);
  const rpc = await result.json();
  assert.equal(rpc.id, 42);
  assert.equal(rpc.result.resultType, 'complete');
  return rpc.result;
}

test('complete offline control-plane fixture never claims real iPhone execution', async t => {
  const f = setup(t);

  // The real Site is not secretly a device controller. A Site tool can only
  // prepare a fixed owner-tapped first-party app navigation link.
  const site = await siteCall('iphone_chatgpt_handoff', { action: 'diagnostics' });
  assert.equal(site.isError, false);
  assert.equal(site.structuredContent.data.launchUrl,
    'igentic://handoff/v1/diagnostics');
  assert.equal(site.structuredContent.data.requiresOwnerTap, true);
  assert.equal(site.structuredContent.data.actionExecuted, false);
  assert.equal(site.structuredContent.data.iPhoneConnected, 'not-checked');
  assert.equal(site.structuredContent.data.dataSentToIPhone, 'none');

  // A separate explicitly trusted owner key is required to originate the
  // future read-only task. Do not derive it from Site tool output.
  const envelope = f.proposal();
  const id = envelope.body.requestId;
  const loop = f.loop();
  const opened = loop.start({ envelope, entryPoint: 'chatgpt-site' });
  assert.equal(opened.state, 'awaiting-manual-delivery');
  assert.equal(opened.actionExecuted, false);
  assert.equal(opened.ownerApproved, false);

  const prepared = loop.prepareDelivery({
    requestId: id, route: 'cellular-foreground'
  });
  assert.equal(prepared.status, 'prepared-not-sent');
  assert.equal(prepared.actionExecuted, false);
  assert.equal(prepared.iPhoneConnected, 'not-checked');
  const markerFiles = readdirSync(f.markerDirectory);
  assert.equal(markerFiles.length, 2);
  const attemptName = markerFiles.find(name => /^[a-f0-9]{64}\.attempt$/.test(name));
  assert.ok(attemptName);
  assert.equal(readFileSync(join(f.markerDirectory, attemptName)).length, 0);
  // A separate private keyed commitment prevents a changed HMAC key from
  // silently reopening an earlier may-have-been-sent task after a restart.
  assert.equal(readFileSync(join(f.markerDirectory, '.key-binding')).length, 32);
  assert.equal(f.marker().recover({ requestId: id }).state, 'outcome-unknown');

  // There is intentionally no network adapter. The fixture simulates a
  // transport uncertainty and a local key-holder proof, not device work.
  const unknown = loop.recordTransport({
    requestId: id, outcome: 'sent-unconfirmed'
  });
  assert.equal(unknown.state, 'outcome-unknown');
  assert.equal(unknown.automaticRetryAllowed, false);
  assert.equal(unknown.actionExecuted, false);

  const fake = signReadOnlyDeviceKeyReceipt({
    key: f.receiptKey, requestId: id, observedAt: f.clock.value,
    nonce: randomUUID()
  });
  assert.throws(() => loop.acceptKeyReceipt(fake), /invalidAgentLoopReceipt/);
  const exact = signReadOnlyDeviceKeyReceipt({
    key: f.receiptKey, requestId: id, observedAt: f.clock.value,
    nonce: prepared.receiptNonce
  });
  const settled = loop.acceptKeyReceipt(exact);
  assert.equal(settled.state, 'receipt-key-authenticated');
  assert.equal(settled.deviceReceipt, 'key-authenticated-not-device-attested');
  assert.equal(settled.actionExecuted, false);
  assert.equal(settled.ownerApproved, false);
  assert.equal(settled.iPhoneConnected, 'not-checked');
  assert.equal(settled.automaticRetryAllowed, false);

  // A fresh verifier / transport-state instance cannot reuse a task after
  // restart, even though its previous in-memory state has been discarded.
  const afterRestart = f.loop();
  assert.throws(() => afterRestart.start({
    envelope, entryPoint: 'chatgpt-site'
  }), /replayedTaskEnvelope/);
  assert.equal(afterRestart.snapshot().state, 'empty');
  assert.equal(f.marker().recover({ requestId: id }).state, 'outcome-unknown');
});

test('fixture refuses model-injected writes, replay and untrusted MCP execution', async t => {
  const f = setup(t);
  const envelope = f.proposal();
  const loop = f.loop();
  assert.throws(() => loop.start({
    envelope: {
      ...envelope, body: { ...envelope.body, capability: 'reminder.create' }
    },
    entryPoint: 'chatgpt-site'
  }), /invalidTaskEnvelope/);
  assert.equal(loop.snapshot().state, 'empty');
  assert.equal(readdirSync(f.markerDirectory).length, 0);
  const unsupported = await siteCall('iphone_execute_action', {
    action: 'delete-contacts'
  });
  assert.equal(unsupported.isError, true);
  assert.doesNotMatch(JSON.stringify(unsupported), /delete-contacts/);
  loop.start({ envelope, entryPoint: 'chatgpt-site' });
  assert.throws(() => loop.start({
    envelope, entryPoint: 'chatgpt-site'
  }), /invalidAgentLoopTransition/);
  const second = f.loop();
  assert.throws(() => second.start({
    envelope, entryPoint: 'manual-client'
  }), /replayedTaskEnvelope/);
});

test('an interrupted prepared delivery cannot claim definitively unsent', t => {
  const f = setup(t);
  const envelope = f.proposal();
  const id = envelope.body.requestId;
  const first = f.loop();
  first.start({ envelope, entryPoint: 'shortcuts-chatgpt' });
  first.prepareDelivery({ requestId: id, route: 'local-shortcuts' });

  // Simulate restart and lost in-memory transport information: the empty
  // durable marker intentionally conveys only may-have-been-sent.
  const recovered = f.marker().recover({ requestId: id });
  assert.equal(recovered.state, 'outcome-unknown');
  assert.equal(recovered.automaticRetryAllowed, false);
  assert.equal(recovered.deviceReceipt, 'none');
  assert.equal(recovered.actionExecuted, false);
  assert.throws(() => f.loop().start({
    envelope, entryPoint: 'shortcuts-chatgpt'
  }), /replayedTaskEnvelope/);
  assert.throws(() => first.cancel({ requestId: id }),
    /invalidAgentLoopTransition/);
  assert.equal(first.snapshot().state, 'delivery-prepared-not-sent');
  assert.equal(first.snapshot().automaticRetryAllowed, false);
});

test('expired or wrong-key acknowledgement cannot restore success or retry', t => {
  const f = setup(t);
  const envelope = f.proposal();
  const id = envelope.body.requestId;
  const loop = f.loop();
  loop.start({ envelope, entryPoint: 'igentic-app' });
  const prepared = loop.prepareDelivery({
    requestId: id, route: 'coredevice-wifi'
  });
  loop.recordTransport({ requestId: id, outcome: 'sent-unconfirmed' });
  const wrong = signReadOnlyDeviceKeyReceipt({
    key: randomBytes(32), requestId: id, observedAt: NOW,
    nonce: prepared.receiptNonce
  });
  assert.throws(() => loop.acceptKeyReceipt(wrong), /invalidAgentLoopReceipt/);
  f.clock.value += 61;
  assert.equal(loop.timeout().state, 'outcome-unknown');
  assert.throws(() => loop.acceptKeyReceipt(signReadOnlyDeviceKeyReceipt({
    key: f.receiptKey, requestId: id, observedAt: NOW,
    nonce: prepared.receiptNonce
  })), /invalidAgentLoopTransition/);
  assert.equal(loop.snapshot().automaticRetryAllowed, false);
  assert.equal(loop.snapshot().actionExecuted, false);
  assert.equal(f.marker().recover({ requestId: id }).state, 'outcome-unknown');
});

test('degraded marker directory blocks delivery despite valid admission', t => {
  const f = setup(t);
  const envelope = f.proposal();
  const id = envelope.body.requestId;
  const loop = f.loop();
  loop.start({ envelope, entryPoint: 'manual-client' });
  // A formerly private directory becomes group-readable after the
  // marker was opened. prepareDelivery MUST re-check it before returning.
  chmodSync(f.markerDirectory, 0o750);
  try {
    assert.throws(() => loop.prepareDelivery({
      requestId: id, route: 'coredevice-usb'
    }), /deliveryMarkerUnavailable/);
    assert.equal(loop.snapshot().state, 'awaiting-manual-delivery');
    assert.equal(loop.snapshot().attemptCount, 0);
    assert.equal(loop.snapshot().actionExecuted, false);
    assert.equal(readdirSync(f.markerDirectory).length, 0);
    assert.throws(() => f.loop(), /deliveryMarkerUnavailable/);
  } finally {
    chmodSync(f.markerDirectory, 0o700);
  }
  // Authenticated admission remains consumed: no speculative resend.
  assert.throws(() => f.loop().start({
    envelope, entryPoint: 'manual-client'
  }), /replayedTaskEnvelope/);
});
