import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {mkdtemp, readFile, rm, stat} from 'node:fs/promises';
import {tmpdir,homedir} from 'node:os';
import {join} from 'node:path';
const exec=promisify(execFile);

export function physicalStatus(inventory, target) {
  const devices=inventory?.result?.devices;
  if (!Array.isArray(devices)) return {state:'unknown'};
  const match=devices.find(d => {
    const h=d?.hardwareProperties;
    return h?.platform === 'iOS' && h?.reality === 'physical' && h?.deviceType === 'iPhone' &&
      [d.identifier,h.udid].some(id => typeof id === 'string' && id.toLowerCase() === target.toLowerCase());
  });
  if (!match) return {state:'missing'};
  const connection=match.connectionProperties;
  if (connection?.pairingState !== 'paired') return {state:'unavailable'};
  if (connection.tunnelState === 'connected') return {state:'connected'};
  return {state:connection.tunnelState === 'available' ? 'available' : 'unavailable'};
}
export async function readPhysicalStatus(target) {
  let folder;
  try {
    folder=await mkdtemp(join(tmpdir(),'fieldglass-device-'));
    const path=join(folder,'inventory.json');
    await exec('/usr/bin/xcrun',['devicectl','list','devices','--json-output',path],
      {timeout:12000,maxBuffer:1024*1024,env:{HOME:homedir(),TMPDIR:tmpdir(),PATH:'/usr/bin:/bin'}});
    if ((await stat(path)).size > 4*1024*1024) return {state:'unknown'};
    return physicalStatus(JSON.parse(await readFile(path,'utf8')),target);
  } catch {return {state:'unknown'}}
  finally {if (folder) await rm(folder,{recursive:true,force:true})}
}
