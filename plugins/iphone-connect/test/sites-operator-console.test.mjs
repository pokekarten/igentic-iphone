import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { handleSitesMcp } from '../../igentic-chatgpt-iphone/sites-reference/mcp-handler.mjs';

const source = readFileSync(new URL(
  '../../igentic-chatgpt-iphone/sites-reference/operator-console.js.txt',
  import.meta.url
), 'utf8');
const html = readFileSync(new URL(
  '../../igentic-chatgpt-iphone/sites-reference/console.html',
  import.meta.url
), 'utf8');

class FakeElement {
  constructor() {
    this.listeners = new Map();
    this.children = [];
    this.value = '';
    this.hidden = true;
    this.disabled = false;
    this.textContent = '';
  }
  addEventListener(name, handler) { this.listeners.set(name, handler); }
  async click() { return this.listeners.get('click')?.(); }
  replaceChildren(...children) { this.children = children; }
  appendChild(item) { this.children.push(item); }
  removeAttribute(name) { if (name === 'href') delete this.href; }
  set innerHTML(value) { throw Error('unsafeHTMLRendering:' + value); }
}
const names = [
  'show-capabilities', 'verify-site-registry', 'site-registry-status', 'copy-site-check', 'copy-site-status',
  'show-shortcuts', 'prepare-handoff',
  'cancel-mcp-request', 'handoff-action', 'prepared-link', 'status',
  'capability-list', 'shortcuts-list', 'project-chat-status'
];
function initialize(customFetch, timers = {}) {
  const copied = [];
  const elements = new Map(names.map(name => [name, new FakeElement()]));
  elements.get('handoff-action').value = 'diagnostics';
  elements.get('cancel-mcp-request').disabled = true;
  elements.get('copy-site-check').disabled = true;
  const calls = [];
  const listeners = new Map();
  const fetch = async (url, options) => {
    calls.push({ url, options });
    if (customFetch) return customFetch(url, options);
    return handleSitesMcp(new Request('https://owner-site.invalid' + url, options));
  };
  runInNewContext(source, {
    document: {
      getElementById: id => elements.get(id),
      createElement: tag => {
        assert.equal(tag, 'li');
        return new FakeElement();
      }
    },
    window: {
      addEventListener: (name, handler) => listeners.set(name, handler)
    },
    fetch,
    navigator: { clipboard: { async writeText(value) {
      copied.push(value);
      if (timers.rejectClipboard) throw Error('clipboardDenied');
    } } },
    AbortController,
    setTimeout: timers.setTimeout ?? setTimeout,
    clearTimeout: timers.clearTimeout ?? clearTimeout
  }, { timeout: 1000 });
  return {
    get: id => elements.get(id),
    calls,
    copied,
    close: () => listeners.get('pagehide')?.()
  };
}

test('console HTML is static, same-origin-only and has no arbitrary task inputs', () => {
  assert.match(html, /src="\/console\.js"/);
  assert.match(html, /connect-src 'self'/);
  assert.match(html, /script-src 'self'/);
  assert.match(html, /id="cancel-mcp-request"[^>]*disabled/);
  assert.match(html, /12 Sekunden/);
  assert.match(html, /id="project-chat-status"/);
  assert.match(html, /id="verify-site-registry"/);
  assert.match(html, /id="copy-site-check"[^>]*disabled/);
  assert.match(html, /\[hidden\] \{ display: none !important; \}/);
  assert.doesNotMatch(html, /<form\b|<iframe\b|<textarea\b|http:\/\//i);
  assert.doesNotMatch(source, /localStorage|sessionStorage|document\.cookie|location\.href|window\.open/);
  assert.equal((source.match(/fetch\('\/mcp'/g) ?? []).length, 1);
});

test('three intentional button clicks call only fixed MCP tools and never navigate', async () => {
  const page = initialize();
  assert.equal(page.calls.length, 0);
  assert.equal(page.get('prepared-link').hidden, true);
  await page.get('show-capabilities').click();
  assert.equal(page.get('capability-list').children.length, 3);
  assert.match(page.get('capability-list').children[1].textContent, /hier nicht verfügbar/);
  await page.get('show-shortcuts').click();
  assert.equal(page.get('shortcuts-list').children.length, 5);
  assert.match(page.get('project-chat-status').textContent, /nicht verifiziert/);
  assert.match(page.get('project-chat-status').textContent, /ChatGPT-Projekt/);
  await page.get('prepare-handoff').click();
  assert.equal(page.get('prepared-link').hidden, false);
  assert.equal(page.get('prepared-link').href, 'igentic://handoff/v1/diagnostics');
  assert.match(page.get('status').textContent, /Keine Aktion ausgeführt/);
  assert.equal(page.calls.length, 3);
  assert.deepEqual(page.calls.map(c => JSON.parse(c.options.body).params.name), [
    'igentic_get_capabilities', 'igentic_shortcuts_setup', 'iphone_chatgpt_handoff'
  ]);
  for (const { url, options } of page.calls) {
    assert.equal(url, '/mcp');
    assert.equal(options.method, 'POST');
    assert.equal(options.credentials, 'same-origin');
    assert.equal(options.headers['Mcp-Method'], 'tools/call');
    assert.equal(options.headers['Mcp-Name'],
      JSON.parse(options.body).params.name);
    assert.doesNotMatch(options.body, /password|private-text|ownerApproved|udid/i);
  }
  page.get('handoff-action').value = 'reminder-draft';
  page.get('handoff-action').listeners.get('change')();
  assert.equal(page.get('prepared-link').hidden, true);
  await page.get('prepare-handoff').click();
  assert.equal(page.get('prepared-link').href, 'igentic://handoff/v1/reminder-draft');
  page.close();
  assert.equal(page.get('prepared-link').hidden, true);
  assert.equal(Object.hasOwn(page.get('prepared-link'), 'href'), false);
});

test('unsupported selection never issues a tool call or leaves a stale link', async () => {
  const page = initialize();
  await page.get('prepare-handoff').click();
  assert.equal(page.get('prepared-link').hidden, false);
  page.get('handoff-action').value = 'delete-contacts';
  await page.get('prepare-handoff').click();
  assert.equal(page.calls.length, 1);
  assert.equal(page.get('prepared-link').hidden, true);
  assert.match(page.get('status').textContent, /Keine iPhone-Aktion ausgeführt/);
});

test('tampered tool response, fake approval or mismatched URL fails closed', async () => {
  for (const changes of [
    { launchUrl: 'javascript:alert(1)' },
    { actionExecuted: true },
    { requiresOwnerTap: false },
    { action: 'discovery' },
    { iPhoneConnected: 'connected' },
    { dataSentToIPhone: 'private-data' }
  ]) {
    const page = initialize(async (url, options) => {
      assert.equal(url, '/mcp');
      const request = JSON.parse(options.body);
      const data = {
        schema: 1, actionExecuted: false, iPhoneConnected: 'not-checked',
        action: 'diagnostics', launchUrl: 'igentic://handoff/v1/diagnostics',
        requiresOwnerTap: true, dataSentToIPhone: 'none',
        authorization: 'link-is-navigation-only-not-permission',
        ...changes
      };
      return { ok: true, async json() {
        return { id: request.id, result: {
          resultType: 'complete', isError: false, structuredContent: { data }
        } };
      } };
    });
    await page.get('prepare-handoff').click();
    assert.equal(page.get('prepared-link').hidden, true);
    assert.equal(Object.hasOwn(page.get('prepared-link'), 'href'), false);
    assert.match(page.get('status').textContent, /Antwort ungültig/);
  }
});

test('network errors never show a fake connected state or auto-navigation', async () => {
  const page = initialize(async () => { throw Error('network-offline'); });
  await page.get('show-capabilities').click();
  assert.equal(page.get('capability-list').children.length, 0);
  assert.equal(page.get('prepared-link').hidden, true);
  assert.match(page.get('status').textContent, /Plugin-Abfrage nicht verfügbar/);
});

test('explicit cancel aborts a hanging MCP request and restores controls', async () => {
  const page = initialize((_url, options) => new Promise((_resolve, reject) => {
    options.signal.addEventListener('abort', () => reject(Error('clientCancelled')), { once: true });
  }));
  const pending = page.get('prepare-handoff').click();
  assert.equal(page.get('cancel-mcp-request').disabled, false);
  assert.equal(page.get('prepare-handoff').disabled, true);
  assert.equal(page.get('prepared-link').hidden, true);
  await page.get('cancel-mcp-request').click();
  await pending;
  assert.equal(page.get('cancel-mcp-request').disabled, true);
  assert.equal(page.get('prepare-handoff').disabled, false);
  assert.equal(page.get('prepared-link').hidden, true);
  assert.match(page.get('status').textContent, /abgebrochen/);
});

test('12-second timer aborts the request without opening a handoff', async () => {
  let triggerTimeout, timersCleared = 0;
  const page = initialize((_url, options) => new Promise((_resolve, reject) => {
    options.signal.addEventListener('abort', () => reject(Error('timeout')), { once: true });
  }), {
    setTimeout(callback, ms) {
      assert.equal(ms, 12000);
      triggerTimeout = callback;
      return 7;
    },
    clearTimeout(id) {
      assert.equal(id, 7);
      timersCleared += 1;
    }
  });
  const pending = page.get('prepare-handoff').click();
  assert.equal(typeof triggerTimeout, 'function');
  triggerTimeout();
  await pending;
  assert.equal(timersCleared, 1);
  assert.equal(page.get('prepared-link').hidden, true);
  assert.equal(page.get('prepare-handoff').disabled, false);
  assert.match(page.get('status').textContent, /abgelaufen/);
});

test('cancelled late promise cannot re-enable link even if network ignores abort', async () => {
  let resolveResponse;
  const page = initialize((_url, options) => new Promise(resolve => {
    resolveResponse = () => resolve({
      ok: true,
      async json() {
        return {
          id: JSON.parse(options.body).id,
          result: {
            resultType: 'complete', isError: false,
            structuredContent: { data: {
              schema: 1, action: 'diagnostics',
              actionExecuted: false, iPhoneConnected: 'not-checked',
              dataSentToIPhone: 'none',
              launchUrl: 'igentic://handoff/v1/diagnostics',
              requiresOwnerTap: true,
              authorization: 'link-is-navigation-only-not-permission'
            } }
          }
        };
      }
    });
  }));
  const pending = page.get('prepare-handoff').click();
  await page.get('cancel-mcp-request').click();
  resolveResponse();
  await pending;
  assert.equal(page.get('prepared-link').hidden, true);
  assert.equal(Object.hasOwn(page.get('prepared-link'), 'href'), false);
  assert.equal(page.get('cancel-mcp-request').disabled, true);
});

test('changing destination during a pending response cannot expose stale URL', async () => {
  let releaseResponse;
  const page = initialize((url, options) => new Promise(resolve => {
    releaseResponse = async () => resolve(await handleSitesMcp(
      new Request('https://owner-site.invalid' + url, options)
    ));
  }));
  const pending = page.get('prepare-handoff').click();
  page.get('handoff-action').value = 'discovery';
  page.get('handoff-action').listeners.get('change')();
  await releaseResponse();
  await pending;
  assert.equal(page.get('prepared-link').hidden, true);
  assert.equal(Object.hasOwn(page.get('prepared-link'), 'href'), false);
});


test('forged project-context success is rejected instead of presenting an unverified Shortcut as a project chat', async () => {
  const page = initialize(async (url, options) => {
    assert.equal(url, '/mcp');
    const req = JSON.parse(options.body);
    assert.equal(req.params.name, 'igentic_shortcuts_setup');
    return { ok: true, async json() { return {
      id: req.id,
      result: { resultType: 'complete', isError: false, structuredContent: { data: {
        schema: 1, actionExecuted: false, iPhoneConnected: 'not-checked',
        status: 'owner-manual-setup-instructions', shortcutCreated: false,
        requiresOwnerSetup: true, steps: Array(5).fill('fake step'),
        projectChat: { availableFromThisSite: true,
          shortcutProjectContext: 'verified', requiresSeparateUserConfirmation: false }
      } } }
    }; } };
  });
  await page.get('show-shortcuts').click();
  assert.equal(page.get('shortcuts-list').children.length, 0);
  assert.match(page.get('project-chat-status').textContent, /nicht verifiziert/);
  assert.match(page.get('status').textContent, /Antwort ungültig/);
});

test('Site compatibility button makes exactly two same-origin read-only MCP discovery calls', async () => {
  const page = initialize();
  await page.get('verify-site-registry').click();
  assert.equal(page.calls.length, 2);
  assert.deepEqual(page.calls.map(x => JSON.parse(x.options.body).method),
    ['server/discover', 'tools/list']);
  for (const { url, options } of page.calls) {
    assert.equal(url, '/mcp');
    assert.equal(options.method, 'POST');
    assert.equal(options.credentials, 'same-origin');
    assert.equal(options.headers['Mcp-Name'], undefined);
    assert.equal(options.headers['Mcp-Method'], JSON.parse(options.body).method);
    assert.deepEqual(Object.keys(JSON.parse(options.body).params), ['_meta']);
  }
  assert.match(page.get('site-registry-status').textContent, /v0\.2\.0 bestätigt/);
  assert.match(page.get('site-registry-status').textContent, /iPhone-Verbindung weiterhin nicht geprüft/);
  assert.equal(page.get('prepared-link').hidden, true);
});

test('outdated Site tool listing does not get falsely reported as compatible', async () => {
  const page = initialize(async (url, options) => {
    const req = JSON.parse(options.body);
    const real = await handleSitesMcp(new Request('https://owner-site.invalid' + url, options));
    const rpc = await real.json();
    if (req.method === 'tools/list') rpc.result.tools = rpc.result.tools.slice(0,1);
    return { ok: true, async json() { return rpc; } };
  });
  await page.get('verify-site-registry').click();
  assert.equal(page.calls.length, 2);
  assert.match(page.get('site-registry-status').textContent, /nicht bestätigt/);
  assert.match(page.get('status').textContent, /Keine iPhone-Aktion ausgeführt/);
  assert.equal(page.get('prepared-link').hidden, true);
});

test('forged writable plugin capability fails Site registry inspection', async () => {
  const page = initialize(async (url, options) => {
    const req = JSON.parse(options.body);
    const real = await handleSitesMcp(new Request('https://owner-site.invalid' + url, options));
    const rpc = await real.json();
    if (req.method === 'tools/list')
      rpc.result.tools[0].annotations.destructiveHint = true;
    return { ok: true, async json() { return rpc; } };
  });
  await page.get('verify-site-registry').click();
  assert.match(page.get('site-registry-status').textContent, /nicht bestätigt/);
  assert.equal(page.get('prepared-link').hidden, true);
});

test('failed discovery stops before tool listing', async () => {
  const page = initialize(async (url, options) => {
    const req = JSON.parse(options.body);
    const real = await handleSitesMcp(new Request('https://owner-site.invalid' + url, options));
    const rpc = await real.json();
    if (req.method === 'server/discover') {
      rpc.result.supportedVersions = ['2025-03-26'];
    }
    return { ok: true, async json() { return rpc; } };
  });
  await page.get('verify-site-registry').click();
  assert.equal(page.calls.length, 1);
  assert.match(page.get('site-registry-status').textContent, /nicht bestätigt/);
});


test('sanitized report can only be copied after an exact Site registry check and explicit click', async () => {
  const page = initialize();
  assert.equal(page.get('copy-site-check').disabled, true);
  await page.get('copy-site-check').click();
  assert.deepEqual(page.copied, []);
  await page.get('verify-site-registry').click();
  assert.equal(page.get('copy-site-check').disabled, false);
  assert.deepEqual(page.copied, []);
  await page.get('copy-site-check').click();
  assert.equal(page.copied.length, 1);
  assert.match(page.copied[0], /iGentic Site-MCP Kompatibilitätsprüfung/);
  assert.match(page.copied[0], /iPhone: Verbindung nicht geprüft/);
  assert.match(page.copied[0], /iPhone-Aktion: nicht ausgeführt/);
  assert.match(page.copied[0], /ChatGPT-Projektkontext: nicht verifiziert/);
  assert.doesNotMatch(page.copied[0], /https?:|igentic:\/\/|token|apikey|udid|PRIVATE_SENTINEL/i);
  assert.equal(page.calls.length, 2);
  assert.match(page.get('copy-site-status').textContent, /kopiert/);
  page.close();
  assert.equal(page.get('copy-site-check').disabled, true);
});

test('failed registry recheck revokes prior copy ability without leaking a report', async () => {
  let invalid = false;
  const page = initialize(async (url, options) => {
    const request = JSON.parse(options.body);
    const real = await handleSitesMcp(new Request('https://owner-site.invalid' + url, options));
    const rpc = await real.json();
    if (invalid && request.method === 'tools/list') rpc.result.tools = [];
    return { ok: true, async json() { return rpc; } };
  });
  await page.get('verify-site-registry').click();
  assert.equal(page.get('copy-site-check').disabled, false);
  invalid = true;
  await page.get('verify-site-registry').click();
  assert.equal(page.get('copy-site-check').disabled, true);
  await page.get('copy-site-check').click();
  assert.equal(page.copied.length, 0);
});

test('clipboard permission failures keep copy path manual and non-executing', async () => {
  const page = initialize(undefined, { rejectClipboard: true });
  await page.get('verify-site-registry').click();
  await page.get('copy-site-check').click();
  assert.match(page.get('copy-site-status').textContent, /nicht verfügbar/);
  assert.equal(page.calls.length, 2);
  assert.equal(page.get('prepared-link').hidden, true);
});
