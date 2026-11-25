import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { decodeSharedKey } from '../src/cellular-gateway.mjs';
import { initCellularSecret } from '../scripts/init-cellular.mjs';

test('first-party pairing secret is random, private and never overwritten', async t => {
  const parent=await mkdtemp(join(tmpdir(),'igentic-cellular-pairing-test-'));
  t.after(()=>rm(parent,{recursive:true,force:true}));
  const root=join(parent,'private-cellular');
  const filename=await initCellularSecret({root});
  const content=(await readFile(filename,'utf8')).trim();
  assert.equal(decodeSharedKey(content).length,32);
  assert.equal((await stat(root)).mode & 0o077,0);
  assert.equal((await stat(filename)).mode & 0o077,0);
  await assert.rejects(initCellularSecret({root}),{code:'EEXIST'});
  assert.equal((await readFile(filename,'utf8')).trim(),content);
});

test('pairing keys are independently random and not derived from device IDs',async t=>{
  const parent=await mkdtemp(join(tmpdir(),'igentic-independent-pairing-'));
  t.after(()=>rm(parent,{recursive:true,force:true}));
  const a=(await readFile(await initCellularSecret({root:join(parent,'a')}),'utf8')).trim();
  const b=(await readFile(await initCellularSecret({root:join(parent,'b')}),'utf8')).trim();
  assert.notEqual(a,b);
});
