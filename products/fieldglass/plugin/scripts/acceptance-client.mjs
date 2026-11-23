import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { readFile } from 'node:fs/promises';
import { getDefaultEnvironment } from '@modelcontextprotocol/sdk/client/stdio.js';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const client = new Client({name:'fieldglass-simulator-acceptance',version:'1'});
try {
  await client.connect(new StdioClientTransport({command:process.execPath,env:{...getDefaultEnvironment(), ...(process.env.FIELDGLASS_SMOKE_TARGET ? {
    FIELDGLASS_CHANNEL:'simulator',FIELDGLASS_TARGET:process.env.FIELDGLASS_SMOKE_TARGET, FIELDGLASS_CAPTURE:'local', ...(process.env.FIELDGLASS_XCTESTRUN ? {FIELDGLASS_XCTESTRUN:process.env.FIELDGLASS_XCTESTRUN} : {})
  } : {})},args:[fileURLToPath(new URL('../src/server.mjs',import.meta.url))]}));
  async function invoke(name,args) {
    const response = await client.callTool({name,arguments:args},undefined,{timeout:135000});
    assert.ok(!response.isError, name);
    return response.structuredContent;
  }
  if (process.argv[2] === 'prepare') {
    console.log((await invoke('prepare_experiment',{term:'ORBIT',region:'top'})).link);
  } else if (process.argv[2] === 'lab') {
    const response=await invoke('simulator_workflow',{commands:[
      {action:'inspect'},{action:'tap',target:{identifier:'run'}},{action:'wait-for',identifier:'reading-ready'}]});
    assert.ok(response.steps?.[0]?.identifiers.includes('run'),JSON.stringify(response));
    assert.deepEqual(response.steps.slice(1).map(x=>x.status),['submitted','present']);
    console.log('Own XCTest driver verified inspect → tap → observed result.');
  } else if (process.argv[2] === 'lab-inputs') {
    const commands = [
      {action:'inspect'}, {action:'double-tap',target:{x:0.5,y:0.4}}, {action:'hold',target:{x:0.5,y:0.4}},
      {action:'drag',x:0.6,y:0.6,toX:0.6,toY:0.45}, {action:'swipe',direction:'down'},
      {action:'type',identifier:'term',text:'XYZ\n'}, {action:'wait-for',identifier:'reading-ready'}
    ];
    const result = await invoke('simulator_workflow',{commands});
    assert.deepEqual(result.steps?.map(step => step.status),
      ['observed','submitted','submitted','submitted','submitted','submitted','present']);
    const stopped = await invoke('simulator_workflow',{commands:[
      {action:'wait-for',identifier:'missing-fieldglass-test-target'}, {action:'tap',target:{identifier:'run'}}
    ]});
    assert.deepEqual(stopped.steps,[{status:'target-unavailable'}]);
    console.log('Simulator inputs reached an OCR result. A missing element stopped further input.');
  } else if (process.argv[2] === 'submit') {
    const {experimentId} = await invoke('prepare_experiment',{term:'HAFEN',region:'bottom'});
    const result = await invoke('deliver_experiment',{experimentId,term:'HAFEN',region:'bottom'});
    assert.ok(['submitted','delivery-unconfirmed'].includes(result?.status), JSON.stringify(result));
    assert.equal(result?.channel,'simulator');
    assert.equal((await invoke('simulator_status',{})).state,'Booted');
    if (process.env.FIELDGLASS_TEST_CAPTURE === '1') {
      for (const [name,args] of [['simulator_screenshot',{}],['simulator_record_clip',{seconds:2}]]) {
        const saved=await invoke(name,args);
        assert.equal(saved.status,'saved-locally',name);
        console.log(name, saved.file, saved.bytes);
      }
    }
    console.log('Configured simulator accepted the experiment link.');
  } else {
    const [link,beforePath,afterPath] = process.argv.slice(3);
    const experimentId = new URL(link).searchParams.get('id');
    const before = await readFile(beforePath,'utf8'), after = await readFile(afterPath,'utf8');
    for (const reading of [before, after]) {
      const r = await invoke('read_result',{experimentId,reading});
      assert.equal(r.runtime,'simulator'); assert.equal(r.source,'example'); assert.equal(r.region,'top');
    }
    const comparison = await invoke('compare_results',{before,after});
    assert.deepEqual([comparison.before,comparison.after,comparison.changed],['match','no-match',true]);
    console.log('MCP → simulator OCR → MCP: match → no-match, verified');
  }
} finally { await client.close(); }
