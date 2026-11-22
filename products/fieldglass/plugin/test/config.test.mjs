import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,writeFile,chmod,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {localSettings} from '../src/config.mjs';

test('private config, invalid permissions and explicit manual override',async t=>{
  const folder=await mkdtemp(join(tmpdir(),'fieldglass-config-'));
  t.after(()=>rm(folder,{recursive:true,force:true}));
  const path=join(folder,'settings');
  assert.equal((await localSettings({},path)).channel.mode,'manual');
  await writeFile(path,'{"mode":"manual"}',{mode:0o600});
  assert.equal((await localSettings({},path)).channel.mode,'manual');
  await chmod(path,0o644);
  assert.equal((await localSettings({},path)).channel.mode,'configuration-error');
  assert.equal((await localSettings({FIELDGLASS_CHANNEL:'manual'},path)).channel.mode,'manual');
});
