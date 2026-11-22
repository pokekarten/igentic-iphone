import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {existsSync} from 'node:fs';
import {createServer} from 'node:http';
import {fileURLToPath} from 'node:url';
import test from 'node:test';
import {Client} from '@modelcontextprotocol/sdk/client/index.js';
import {StdioClientTransport,getDefaultEnvironment} from '@modelcontextprotocol/sdk/client/stdio.js';
import {build} from 'esbuild';
import {chromium} from 'playwright';

const chrome = process.env.CHROME_BIN ?? ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome','/usr/bin/google-chrome','/usr/bin/chromium'].find(existsSync);
const pluginRoot = fileURLToPath(new URL('../',import.meta.url));
const hostSource = `
import {AppBridge,PostMessageTransport} from '@modelcontextprotocol/ext-apps/app-bridge';
const frame = document.querySelector('iframe');
const host = new AppBridge(null,{name:'Fieldglass test host',version:'1'},{serverTools:{}});
host.oncalltool = params => window.callPlugin(params);
host.oninitialized = async () => {
  const result = await window.callPlugin({name:'get_channels',arguments:{}});
  await host.sendToolResult(result);
};
await host.connect(new PostMessageTransport(frame.contentWindow,frame.contentWindow));
frame.src = '/card';
`;

test('chat workbench prepares an editable experiment and compares receipts through the real MCP server', {skip:!chrome}, async t => {
  const target = process.env.FIELDGLASS_UI_TARGET;
  const client = new Client({name:'fieldglass-card-test',version:'1'});
  t.after(() => client.close());
  await client.connect(new StdioClientTransport({command:process.execPath,args:[pluginRoot+'src/server.mjs'],
    env:{...getDefaultEnvironment(),FIELDGLASS_CHANNEL:target ? 'simulator' : 'manual',...(target && {FIELDGLASS_TARGET:target})}}));
  const descriptor = (await client.listTools()).tools.find(tool => tool.name === 'get_channels');
  const card = (await client.readResource({uri:descriptor._meta.ui.resourceUri})).contents[0];
  assert.equal(card.mimeType,'text/html;profile=mcp-app');
  assert.deepEqual(card._meta.ui.csp,{connectDomains:[],resourceDomains:[]});

  const bundle = await build({stdin:{contents:hostSource,resolveDir:pluginRoot},platform:'browser',format:'esm',bundle:true,write:false});
  const server = createServer((req,res) => {
    if (req.url === '/host.js') {res.setHeader('Content-Type','text/javascript'); res.end(bundle.outputFiles[0].text);}
    else if (req.url === '/card') {res.setHeader('Content-Type','text/html; charset=utf-8'); res.end(card.text);}
    else {res.setHeader('Content-Type','text/html'); res.end('<iframe title="Fieldglass"></iframe><script type="module" src="/host.js"></script>');}
  });
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  t.after(()=>new Promise(resolve=>{server.close(resolve); server.closeAllConnections();}));
  const browser = await chromium.launch({executablePath:chrome,headless:true});
  t.after(()=>browser.close());
  const page = await browser.newPage();
  page.setDefaultTimeout(10000);
  const errors = [];
  page.on('pageerror',err=>errors.push(err.message));
  await page.exposeFunction('callPlugin', params => client.callTool(params));
  await page.goto('http://127.0.0.1:'+server.address().port);
  const frame = page.frameLocator('iframe');
  await frame.getByText(target ? 'iOS-Simulator' : 'Manuelle Übergabe',{exact:true}).waitFor();
  await frame.getByLabel('Suchtext').fill('Öl + B');
  await frame.getByLabel('Bildbereich').selectOption('bottom');
  await frame.getByRole('button',{name:'Auftrag erstellen'}).click();
  await frame.getByText('Auftrag bereit.',{exact:true}).waitFor();
  const link = new URL(await frame.getByLabel('In Fieldglass unter').inputValue());
  assert.equal(link.searchParams.get('term'),'Öl + B');
  assert.equal(link.searchParams.get('region'),'bottom');
  const delivery = frame.getByRole('button',{name:'Auftrag übergeben'});
  if (target) {
    await delivery.click();
    await frame.getByText('Übergabe angenommen. Prüfung in Fieldglass starten.',{exact:true}).waitFor();
    assert.ok(await delivery.isDisabled());
  } else {assert.equal(await delivery.count(),0);}
  await frame.getByText('Zwei Ergebnisse vergleichen',{exact:true}).click();
  const receipt = {experimentId:link.searchParams.get('id'),readingId:randomUUID(),region:'bottom',
    runtime:'simulator',source:'example',version:1,outcome:'match'};
  await frame.getByLabel('Erster JSON-Bericht').fill(JSON.stringify(receipt));
  await frame.getByLabel('Zweiter JSON-Bericht').fill(JSON.stringify({...receipt,readingId:randomUUID(),outcome:'no-match'}));
  await frame.getByRole('button',{name:'Berichte vergleichen'}).click();
  await frame.getByText('Treffer → Kein Treffer · Ergebnis geändert.',{exact:true}).waitFor();
  await frame.getByLabel('Zweiter JSON-Bericht').fill('{}');
  await frame.getByRole('button',{name:'Berichte vergleichen'}).click();
  await frame.getByText(/Vergleich fehlgeschlagen/).waitFor();
  await frame.getByLabel('Suchtext').fill('NORD');
  assert.equal(await frame.getByLabel('In Fieldglass unter').isVisible(),false);
  assert.deepEqual(errors,[]);
});
