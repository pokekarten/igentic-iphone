import test from 'node:test';
import assert from 'node:assert/strict';
import { SITES_TOOLS, callSitesTool } from '../../igentic-chatgpt-iphone/sites-reference/handoff-site.mjs';
import { handleSitesMcp } from '../../igentic-chatgpt-iphone/sites-reference/mcp-handler.mjs';

const names = ['iphone_chatgpt_handoff', 'igentic_get_capabilities', 'igentic_shortcuts_setup'];
const meta = {
  'io.modelcontextprotocol/protocolVersion': '2026-07-28',
  'io.modelcontextprotocol/clientCapabilities': {}
};
async function call(name, args = {}) {
  const request = new Request('https://owner-site.invalid/mcp', {
    method: 'POST',
    headers: {
      'content-type': 'application/json', 'mcp-protocol-version': '2026-07-28',
      'mcp-method': 'tools/call', 'mcp-name': name
    },
    body: JSON.stringify({
      jsonrpc: '2.0', id: 1, method: 'tools/call',
      params: { _meta: meta, name, arguments: args }
    })
  });
  return (await handleSitesMcp(request)).json();
}

test('owner-private Site source advertises only three read-only discovery and handoff tools', () => {
  assert.deepEqual(SITES_TOOLS.map(x => x.name), names);
  for (const t of SITES_TOOLS) {
    assert.equal(t.annotations.readOnlyHint, true);
    assert.equal(t.annotations.destructiveHint, false);
    assert.equal(t.annotations.openWorldHint, false);
    assert.equal(t.inputSchema.additionalProperties, false);
  }
});

test('capability discovery never claims remote phone availability or execution', async () => {
  const expected = callSitesTool('igentic_get_capabilities', {});
  assert.equal(expected.iPhoneConnected, 'not-checked');
  assert.equal(expected.actionExecuted, false);
  assert.equal(expected.status, 'static-documentation-only');
  assert.equal(expected.capabilities.length, 3);
  assert.equal(expected.capabilities[0].supportedByThisSite, true);
  assert.equal(expected.capabilities[1].supportedByThisSite, false);
  assert.equal(expected.capabilities[2].supportedByThisSite, false);
  const rpc = await call('igentic_get_capabilities');
  assert.equal(rpc.result.isError, false);
  assert.deepEqual(rpc.result.structuredContent.data, expected);
  assert.deepEqual(JSON.parse(rpc.result.content[0].text), expected);
});

test('Shortcut guide describes real owner-controlled action names without constructing or executing a shortcut', async () => {
  const guide = callSitesTool('igentic_shortcuts_setup', {});
  assert.equal(guide.shortcutName, 'iGentic KI Loop');
  assert.equal(guide.requiresOwnerSetup, true);
  assert.equal(guide.shortcutCreated, false);
  assert.equal(guide.actionExecuted, false);
  assert.equal(guide.iPhoneConnected, 'not-checked');
  assert.equal(guide.steps.length, 5);
  assert.equal(guide.requiresChatGPTExtension, false);
  assert.match(guide.steps[0], /KI-Auftragspaket lesen/);
  assert.match(guide.steps[1], /taskId und prompt aus demselben Wörterbuch/);
  assert.match(guide.steps[2], /ausschließlich dem Feldwert prompt/);
  assert.match(guide.steps[3], /unveränderte taskId aus Schritt 2/);
  assert.doesNotMatch(guide.steps.join(' '), /KI-Auftrags-ID lesen|KI-Prompt lesen/);
  assert.match(guide.steps.join(' '), /Modell verwenden|Use Model/);
  assert.match(guide.steps.join(' '), /KI-Antwort übernehmen/);
  assert.match(guide.steps.join(' '), /Starte|Nutze|Öffne/);
  assert.deepEqual({
    availableFromThisSite: guide.projectChat.availableFromThisSite,
    shortcutProjectContext: guide.projectChat.shortcutProjectContext,
    requiresSeparateUserConfirmation: guide.projectChat.requiresSeparateUserConfirmation
  }, {
    availableFromThisSite: false,
    shortcutProjectContext: 'not-verified',
    requiresSeparateUserConfirmation: true
  });
  assert.match(guide.projectChat.note, /Projektwahl|Projekt/);
  const rpc = await call('igentic_shortcuts_setup');
  assert.equal(rpc.result.isError, false);
  assert.deepEqual(rpc.result.structuredContent.data, guide);
});

test('capability and setup tools reject all arguments, model injections and action forgery', async () => {
  for (const name of names.slice(1)) {
    for (const args of [null, [], { approved: true }, { action: 'reminder.create' },
      { text: 'PRIVATE_SYNTHETIC_SENTINEL' }, { device: 'user-phone' }]) {
      assert.throws(() => callSitesTool(name, args), /unsupportedSiteToolCall/);
      const result = await call(name, args);
      assert.equal(result.result.isError, true);
      assert.doesNotMatch(JSON.stringify(result), /PRIVATE_SYNTHETIC_SENTINEL|user-phone/);
    }
  }
  assert.throws(() => callSitesTool('igentic_execute', {}), /unsupportedSiteToolCall/);
  assert.equal((await call('igentic_execute', {})).result.isError, true);
});
