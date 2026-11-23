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
  'show-capabilities', 'show-shortcuts', 'prepare-handoff',
  'handoff-action', 'prepared-link', 'status',
  'capability-list', 'shortcuts-list'
];
function initialize(customFetch) {
  const elements = new Map(names.map(name => [name, new FakeElement()]));
  elements.get('handoff-action').value = 'diagnostics';
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
    AbortController
  }, { timeout: 1000 });
  return {
    get: id => elements.get(id),
    calls,
    close: () => listeners.get('pagehide')?.()
  };
}

test('console HTML is static, same-origin-only and has no arbitrary task inputs', () => {
  assert.match(html, /src="\/console\.js"/);
  assert.match(html, /connect-src 'self'/);
  assert.match(html, /script-src 'self'/);
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
    { iPhoneConnected: 'connected' }
  ]) {
    const page = initialize(async (url, options) => {
      assert.equal(url, '/mcp');
      const request = JSON.parse(options.body);
      const data = {
        schema: 1, actionExecuted: false, iPhoneConnected: 'not-checked',
        action: 'diagnostics', launchUrl: 'igentic://handoff/v1/diagnostics',
        requiresOwnerTap: true,
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
