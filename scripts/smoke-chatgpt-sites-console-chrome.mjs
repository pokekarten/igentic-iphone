// Optional real-browser acceptance for the owner-private read-only Site MCP console.
// Loopback only, isolated Chrome context, no phone, no external API.
import { createRequire } from 'node:module';
import { createServer } from 'node:http';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
const require = createRequire(new URL('../plugins/iphone-connect/package.json', import.meta.url));
const { build } = require('esbuild');
const { chromium } = require('playwright');
const output = await build({
  entryPoints: [fileURLToPath(new URL('../plugins/igentic-chatgpt-iphone/sites-reference/worker.mjs', import.meta.url))],
  bundle: true, write: false, format: 'esm', platform: 'browser',
  loader: { '.html': 'text', '.txt': 'text' }
});
const worker = (await import('data:text/javascript;base64,'
  + Buffer.from(output.outputFiles[0].text).toString('base64'))).default;
const server = createServer(async (incoming, outgoing) => {
  const chunks = [];
  for await (const chunk of incoming) chunks.push(chunk);
  const base = 'http://127.0.0.1:' + server.address().port;
  const request = new Request(base + incoming.url, {
    method: incoming.method, headers: incoming.headers,
    ...(incoming.method === 'POST' ? { body: Buffer.concat(chunks) } : {})
  });
  const response = await worker.fetch(request);
  outgoing.writeHead(response.status, Object.fromEntries(response.headers));
  outgoing.end(Buffer.from(await response.arrayBuffer()));
});
await new Promise((resolve, reject) => {
  server.once('error', reject);
  server.listen(0, '127.0.0.1', resolve);
});
let browser;
try {
  browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage();
  const errors = [];
  const mcpCalls = [];
  page.on('pageerror', () => errors.push('browserPageError'));
  page.on('request', req => {
    const url = new URL(req.url());
    if (url.hostname !== '127.0.0.1') errors.push('externalNetworkRequest');
    if (url.pathname === '/mcp') {
      const request = req.postDataJSON();
      mcpCalls.push({ method: request.method, tool: request.params?.name ?? null });
    }
  });
  const pageUrl = 'http://127.0.0.1:' + server.address().port + '/console';
  await page.context().grantPermissions(['clipboard-read','clipboard-write'], { origin: new URL(pageUrl).origin });
  await page.goto(pageUrl, { waitUntil: 'networkidle', timeout: 20000 });
  assert.equal(await page.locator('#prepared-link').isVisible(), false);
  assert.equal(await page.locator('#copy-site-check').isDisabled(), true);
  await page.locator('#verify-site-registry').click();
  await page.waitForFunction(() =>
    document.querySelector('#site-registry-status')?.textContent?.includes('v0.2.0 bestätigt'),
    { timeout: 20000 }
  );
  assert.match(await page.locator('#site-registry-status').innerText(), /iPhone-Verbindung weiterhin nicht geprüft/);
  assert.equal(await page.locator('#copy-site-check').isEnabled(), true);
  await page.locator('#copy-site-check').click();
  const copied = await page.evaluate(() => navigator.clipboard.readText());
  assert.match(copied, /iPhone-Aktion: nicht ausgeführt/);
  assert.match(copied, /ChatGPT-Projektkontext: nicht verifiziert/);
  assert.doesNotMatch(copied, /https?:|igentic:\/\/|apikey|udid|PRIVATE_SENTINEL/i);
  await page.locator('#show-capabilities').click();
  await page.locator('#capability-list li').first().waitFor({ state: 'visible', timeout: 20000 });
  assert.equal(await page.locator('#capability-list li').count(), 3);
  await page.locator('#show-shortcuts').click();
  await page.locator('#shortcuts-list li').first().waitFor({ state: 'visible', timeout: 20000 });
  assert.equal(await page.locator('#shortcuts-list li').count(), 5);
  await page.locator('#handoff-action').selectOption('reminder-draft');
  await page.locator('#prepare-handoff').click();
  const link = page.locator('#prepared-link');
  // MCP tool calls are async: wait for actual visible result, not click return.
  await link.waitFor({ state: 'visible', timeout: 20000 });
  assert.equal(await link.getAttribute('href'), 'igentic://handoff/v1/reminder-draft');
  assert.equal(await link.isVisible(), true);
  assert.equal(page.url(), pageUrl);
  assert.match(await page.locator('#status').innerText(), /Keine Aktion ausgeführt/);
  assert.deepEqual(mcpCalls, [
    { method: 'server/discover', tool: null },
    { method: 'tools/list', tool: null },
    { method: 'tools/call', tool: 'igentic_get_capabilities' },
    { method: 'tools/call', tool: 'igentic_shortcuts_setup' },
    { method: 'tools/call', tool: 'iphone_chatgpt_handoff' }
  ]);
  assert.deepEqual(errors, []);
  console.log(JSON.stringify({
    realBrowser: true, sameOriginMcpCalls: mcpCalls.length, siteRegistryVerified: true, sanitizedReportCopied: true,
    capabilityEntries: 3, shortcutSteps: 5,
    manualLinkValidated: true, noAutoNavigation: true,
    noExternalRequests: true, deviceExecuted: false, success: true
  }));
} finally {
  if (browser) await browser.close();
  await new Promise(resolve => server.close(resolve));
}
