import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { join } from 'node:path';
import { build } from 'esbuild';
import { chromium } from 'playwright';
import { ROOT } from '../src/server.mjs';

const chrome = process.env.CHROME_BIN ?? ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome', '/usr/bin/chromium'].find(existsSync);
test('MCP Apps browser handshake, refresh and stop controls', { skip: !chrome }, async t => {
  const source = `import {AppBridge,PostMessageTransport} from '@modelcontextprotocol/ext-apps/app-bridge';
    const frame=document.querySelector('iframe'); window.calls=[];
    const bridge=new AppBridge(null,{name:'acceptance-host',version:'1.0.0'},{serverTools:{}});window.testBridge=bridge;
    bridge.oncalltool=async p=>{window.calls.push(p.name);return {content:[],structuredContent:{data:
      p.name==='iphone_stop_session'?{stopped:true}:p.name==='iphone_connection_report'
      ?{backend:'fixture',deviceStatus:'synthetic-only',actionReadiness:'not-verified',
        routes:[{id:'usb-c',state:'not-verified'},{id:'wifi',state:'not-verified'},
          {id:'cellular',state:'companion-not-implemented'},
          {id:'on-device',state:'separate-native-app'},{id:'simulator',state:'fixture-only'}]}
      :{backend:'fixture',markers:['Explore']}}};};
    bridge.oninitialized=async()=>{
      await bridge.sendToolInput({arguments:{sessionId:'10000000-0000-4000-8000-000000000001'}});
      await bridge.sendToolResult({content:[],structuredContent:{data:{backend:'fixture',mode:'diagnostics-only',
        sessionId:'10000000-0000-4000-8000-000000000001'}}});
    };
    await bridge.connect(new PostMessageTransport(frame.contentWindow,frame.contentWindow));
    frame.src='/dashboard';`;
  const bundle = await build({ stdin: { contents: source, resolveDir: ROOT }, bundle: true,
    platform: 'browser', format: 'esm', write: false });
  const dashboard = await readFile(join(ROOT, 'ui/dashboard.html'));
  const server = createServer((req, res) => {
    if (req.url === '/host.js') { res.setHeader('Content-Type', 'text/javascript'); res.end(bundle.outputFiles[0].text); }
    else if (req.url === '/dashboard') { res.setHeader('Content-Type', 'text/html'); res.end(dashboard); }
    else { res.setHeader('Content-Type', 'text/html'); res.end('<iframe title="iPhone card" style="width:720px;height:400px;border:0"></iframe><script type="module" src="/host.js"></script>'); }
  });
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  const browser = await chromium.launch({ executablePath: chrome, headless: true });
  t.after(async () => { await browser.close(); await new Promise(r => server.close(r)); });
  const page = await browser.newPage({ viewport: { width: 800, height: 500 } });
  const errors = []; page.on('pageerror', e => errors.push(e.message));
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  const frame = page.frameLocator('iframe');
  await frame.getByRole('button', { name: 'Refresh status' }).waitFor();
  await page.waitForFunction(() => document.querySelector('iframe').contentDocument.querySelector('#observe').disabled === false);
  await frame.getByRole('button', { name: 'Check connections' }).click();
  await frame.getByText('Connection report · synthetic-only', { exact: true }).waitFor();
  await frame.getByText('usb-c: not-verified', { exact: false }).waitFor();
  await frame.getByRole('button', { name: 'Refresh status' }).click();
  await frame.getByText('Explore', { exact: true }).waitFor();
  await page.screenshot({ path: '/tmp/igentic-plugin-dashboard.png' });
  await frame.getByRole('button', { name: 'Stop session' }).click();
  await frame.getByText('Session stopped', { exact: true }).waitFor();
  assert.deepEqual(await page.evaluate(() => window.calls),
    ['iphone_connection_report', 'iphone_observe', 'iphone_stop_session']);
  await frame.getByRole('button', { name: 'Check connections' }).click();
  await frame.getByText('Connection report · synthetic-only', { exact: true }).waitFor();
  assert.equal(await frame.getByRole('button', { name: 'Stop session' }).isDisabled(), true);
  assert.equal(await frame.getByRole('button', { name: 'Stop session' }).isDisabled(), true);
  // A physical backend's configuration is not a successfully connected phone.
  await page.evaluate(async () => window.testBridge.sendToolResult({ content: [],
    structuredContent: { data: { backend: 'physical', mode: 'diagnostics-only' } } }));
  await frame.getByText('iPhone connection not verified · diagnostics-only', { exact: true }).waitFor();
  // Only sanitized, observed diagnostic markers justify the observed-state label.
  await page.evaluate(async () => window.testBridge.sendToolResult({ content: [],
    structuredContent: { data: { backend: 'physical', markers: ['Explore'] } } }));
  await frame.getByText('iPhone diagnostics observed · Availability unknown', { exact: true }).waitFor();
  assert.deepEqual(errors, []);
});
