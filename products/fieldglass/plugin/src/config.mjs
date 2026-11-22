import {lstat,readFile} from 'node:fs/promises';
import {homedir} from 'node:os';
import {join,isAbsolute} from 'node:path';
import {z} from 'zod';
import {selectedChannel} from './delivery.mjs';
export const configPath=join(homedir(),'Library','Application Support','Fieldglass','channel.json');
export const schema=z.strictObject({
  mode:z.enum(['manual','simulator','device']), target:z.string().optional(),
  capture:z.boolean().optional(), driver:z.string().refine(p=>isAbsolute(p)&&p.endsWith('.xctestrun')).optional()
}).refine(c => c.mode === 'manual' ? Object.keys(c).length === 1 :
  !!c.target && (c.mode === 'simulator' || (!c.capture && !c.driver)));
export async function localSettings(env=process.env,path=configPath) {
  if (env.FIELDGLASS_CHANNEL === 'manual') return {channel:{mode:'manual'}};
  if (env.FIELDGLASS_CHANNEL || env.FIELDGLASS_TARGET)
    return {channel:selectedChannel(env),capture:env.FIELDGLASS_CAPTURE === 'local',driver:env.FIELDGLASS_XCTESTRUN,bundle:env.FIELDGLASS_LAB_BUNDLE};
  try {
    const info=await lstat(path);
    if (!info.isFile() || info.size>4096 || (info.mode&0o077) || info.uid !== process.getuid()) throw Error();
    const c=schema.parse(JSON.parse(await readFile(path,'utf8')));
    return {channel:c.mode === 'manual' ? {mode:'manual'} : selectedChannel({FIELDGLASS_CHANNEL:c.mode,FIELDGLASS_TARGET:c.target}),
      capture:c.capture,driver:c.driver};
  } catch (e) {return {channel:{mode:e.code === 'ENOENT' ? 'manual' : 'configuration-error'}}}
}
