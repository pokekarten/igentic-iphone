import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { fileURLToPath } from 'node:url';

test('official client prepares, reads and compares scoped observations', async t => {
  const client = new Client({name:'fieldglass-test',version:'1'});
  t.after(() => client.close());
  await client.connect(new StdioClientTransport({command:process.execPath,env:{FIELDGLASS_CHANNEL:"manual"},
    args:[fileURLToPath(new URL('../src/server.mjs',import.meta.url))]}));
  const call = (name,args) => client.callTool({name,arguments:args});
  assert.equal((await client.listTools()).tools.length,5);
  const {link,experimentId} = (await call('prepare_experiment',{term:'A + B & Öl',region:'top'})).structuredContent;
  assert.equal(new URL(link).searchParams.get('term'),'A + B & Öl');
  assert.equal((await call('prepare_experiment',{term:' ',region:'top'})).isError,true);
  for (const action of ['draft','speak','reminder','status']) {
    const args = {action,text:action === 'status' ? '' : 'Prüfung & Übergabe'};
    const w = await call('prepare_workspace',args);
    assert.equal(new URL(w.structuredContent.link).searchParams.get('text'),args.text);
  }
  assert.equal((await call('prepare_workspace',{action:'reminder',text:''})).isError,true);
  const sample = {version:1,experimentId,region:'top',runtime:'simulator',source:'example',readingId:randomUUID(),outcome:'match'};
  const before = JSON.stringify(sample);
  const after = JSON.stringify({...sample,readingId:randomUUID(),outcome:'no-match'});
  assert.equal((await call('read_result',{experimentId,reading:before})).structuredContent.reportedOutcome,'match');
  assert.equal((await call('compare_results',{before,after})).structuredContent.changed,true);
  for (const bad of [before,'{}',JSON.stringify({...sample,privateText:'example'}),
    JSON.stringify({...sample,experimentId:randomUUID(),readingId:randomUUID()})]) {
    assert.equal((await call('compare_results',{before,after:bad})).isError,true);
  }
});
