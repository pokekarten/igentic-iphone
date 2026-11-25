import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { HANDOFF_ACTIONS, prepareChatGPTHandoff } from '../src/chatgpt-handoff.mjs';
import { registerReadOnlyBrowserHandoff } from '../../igentic-chatgpt-iphone/sites-reference/webmcp-site.mjs';

function fakeDocument({ secure = true, framed = false, registerFails = false } = {}) {
  const registered = [];
  const view = { isSecureContext: secure };
  view.top = framed ? {} : view;
  const document = {
    defaultView: view,
    modelContext: {
      registerTool: async (tool, options) => {
        if (registerFails) throw new Error('browserNotReady');
        registered.push({ tool, options });
      }
    }
  };
  return { document, registered };
}

test('browser WebMCP adapter only registers a read-only local exact-link tool', async () => {
  const { document, registered } = fakeDocument();
  const result = await registerReadOnlyBrowserHandoff(document);
  assert.equal(result.available, true);
  assert.equal(registered.length, 1);
  const { tool, options } = registered[0];
  assert.equal(tool.name, 'iphone_chatgpt_handoff');
  assert.deepEqual(tool.inputSchema.properties.action.enum, HANDOFF_ACTIONS);
  assert.equal(tool.inputSchema.additionalProperties, false);
  assert.equal(tool.annotations.readOnlyHint, true);
  assert.equal(tool.annotations.consequentialHint, false);
  for (const action of HANDOFF_ACTIONS) {
    const output = await tool.execute({ action });
    assert.deepEqual(output, prepareChatGPTHandoff(action));
    assert.equal(output.actionExecuted, false);
    assert.equal(output.iPhoneConnected, 'not-checked');
  }
  for (const bad of [
    { action: 'settings' }, { action: 'discovery', text: 'secret' },
    { action: 'shortcuts://run-shortcut' }, {}, null, []
  ]) await assert.rejects(tool.execute(bad));
  assert.equal(options.signal.aborted, false);
  result.close();
  assert.equal(options.signal.aborted, true);
});

test('WebMCP adapter declines insecure and embedded browser contexts', async () => {
  for (const document of [
    undefined,
    {},
    { defaultView: { isSecureContext: false } },
    fakeDocument({ secure: false }).document,
    fakeDocument({ framed: true }).document,
    { defaultView: { isSecureContext: true, top: null }, modelContext: null }
  ]) {
    const result = await registerReadOnlyBrowserHandoff(document);
    assert.equal(result.available, false);
    assert.doesNotThrow(() => result.close());
  }
  const failure = fakeDocument({ registerFails: true });
  assert.equal((await registerReadOnlyBrowserHandoff(failure.document)).available, false);
  assert.equal(failure.registered.length, 0);
});

test('WebMCP tool respects aborted calls and never navigates from execute', async () => {
  const { document, registered } = fakeDocument();
  const handle = await registerReadOnlyBrowserHandoff(document);
  const { tool } = registered[0];
  const cancellation = new AbortController();
  cancellation.abort();
  await assert.rejects(tool.execute({ action: 'diagnostics' },
    { signal: cancellation.signal }), /browserToolCancelled/);
  handle.close();
});

test('WebMCP page preserves CSP, exact links and a single same-origin script', () => {
  const html = readFileSync(new URL('../../igentic-chatgpt-iphone/sites-reference/webmcp.html',
    import.meta.url), 'utf8');
  const links = [...html.matchAll(/href="([^"]+)"/g)].map(x => x[1]);
  assert.deepEqual(links.sort(), HANDOFF_ACTIONS.map(a => 'igentic://handoff/v1/' + a).sort());
  assert.match(html, /script-src 'self'/);
  assert.match(html, /connect-src 'none'/);
  const scripts = [...html.matchAll(/src="([^"]+)"/g)].map(x => x[1]);
  assert.deepEqual(scripts, ['./webmcp-init.mjs']);
  assert.doesNotMatch(html, /<form|<iframe|<img|http:\/\/|https:\/\//i);
  const init = readFileSync(new URL('../../igentic-chatgpt-iphone/sites-reference/webmcp-init.mjs',
    import.meta.url), 'utf8');
  assert.match(init, /registerReadOnlyBrowserHandoff/);
  assert.match(init, /pagehide/);
});
