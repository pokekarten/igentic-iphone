// Optional Chrome 146+ real browser smoke for the *experimental* WebMCP API.
// Run from a trusted source checkout; it starts only a temporary loopback
// HTTP server and an isolated headless Chrome profile. It never contacts
// a phone, ChatGPT, personal records or a third-party service.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { dirname, extname, join, resolve } from 'node:path';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(new URL('../plugins/iphone-connect/package.json', import.meta.url));
const { chromium } = require('playwright');
const assets = new Set([
  'plugins/igentic-chatgpt-iphone/sites-reference/webmcp.html',
  'plugins/igentic-chatgpt-iphone/sites-reference/webmcp-init.mjs',
  'plugins/igentic-chatgpt-iphone/sites-reference/webmcp-site.mjs',
  'plugins/igentic-chatgpt-iphone/sites-reference/handoff-site.mjs',
  'plugins/iphone-connect/src/chatgpt-handoff.mjs'
]);
const server = createServer(async (req, res) => {
  res.setHeader('cache-control', 'no-store');
  if (req.method !== 'GET') { res.writeHead(405).end(); return; }
  const path = new URL(req.url, 'http://localhost').pathname.slice(1);
  if (!assets.has(path)) { res.writeHead(404).end(); return; }
  try {
    const buffer = await readFile(join(root, path));
    res.writeHead(200, {
      'content-type': extname(path) === '.html' ? 'text/html; charset=utf-8'
        : 'text/javascript; charset=utf-8'
    }).end(buffer);
  } catch { res.writeHead(404).end(); }
});
await new Promise((resolve, reject) => {
  server.once('error', reject);
  server.listen(0, '127.0.0.1', resolve);
});
let browser;
try {
  browser = await chromium.launch({
    channel: 'chrome', headless: true,
    args: ['--enable-features=WebMCP', '--enable-blink-features=WebMCP',
      '--enable-webmcp-testing', '--no-first-run']
  });
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', () => errors.push('pageError'));
  page.on('request', request => {
    if (new URL(request.url()).hostname !== '127.0.0.1')
      errors.push('unexpectedExternalRequest');
  });
  await page.goto('http://127.0.0.1:' + server.address().port +
    '/plugins/igentic-chatgpt-iphone/sites-reference/webmcp.html', {
    waitUntil: 'networkidle', timeout: 20000
  });
  const result = await page.evaluate(async () => {
    const model = document.modelContext;
    if (!model || typeof model.getTools !== 'function'
        || typeof model.executeTool !== 'function') {
      return { supported: false };
    }
    const tools = await model.getTools();
    if (tools.length !== 1 || tools[0].name !== 'iphone_chatgpt_handoff')
      return { supported: true, toolContractMatches: false };
    const initialURL = location.href;
    const checks = [];
    for (const action of ['diagnostics', 'discovery', 'reminder-draft']) {
      const answer = JSON.parse(await model.executeTool(tools[0], { action }));
      checks.push(answer.launchUrl === 'igentic://handoff/v1/' + action
        && answer.actionExecuted === false
        && answer.requiresOwnerTap === true
        && answer.iPhoneConnected === 'not-checked'
        && answer.dataSentToIPhone === 'none');
    }
    let rejectsUnknown = false;
    try { await model.executeTool(tools[0], { action: 'wipe-iphone' }); }
    catch { rejectsUnknown = true; }
    return {
      supported: true,
      toolContractMatches: true,
      allThreeAllowed: checks.every(Boolean),
      rejectsUnknown,
      noAutomaticNavigation: location.href === initialURL,
      manualLinks: [...document.querySelectorAll('nav a')].map(
        element => element.getAttribute('href'))
    };
  });
  const expected = ['diagnostics', 'discovery', 'reminder-draft']
    .map(x => 'igentic://handoff/v1/' + x);
  const accepted = result.supported === true
    && result.toolContractMatches === true
    && result.allThreeAllowed === true
    && result.rejectsUnknown === true
    && result.noAutomaticNavigation === true
    && JSON.stringify(result.manualLinks) === JSON.stringify(expected)
    && errors.length === 0;
  // Sanitized proof only. Never log device metadata, page content, tokens,
  // generated URL parameters or browser profile data.
  console.log(JSON.stringify({
    transport: 'real-browser-webmcp',
    client: 'isolated-local-headless-chrome',
    nativeWebMcpAvailable: result.supported === true,
    oneReadOnlyTool: result.toolContractMatches === true,
    threeAllowlistedLinksVerified: result.allThreeAllowed === true,
    unknownActionRejected: result.rejectsUnknown === true,
    stayedOnPage: result.noAutomaticNavigation === true,
    noExternalRequestsOrPageErrors: errors.length === 0,
    phoneConnected: false, chatgptPluginInstalled: false,
    success: accepted
  }));
  if (!accepted) process.exitCode = 1;
} finally {
  if (browser) await browser.close();
  await new Promise(resolve => server.close(resolve));
}
