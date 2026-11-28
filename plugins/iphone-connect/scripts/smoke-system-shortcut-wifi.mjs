import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { homedir } from 'node:os';
import { isAbsolute, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadConfig } from '../src/backend.mjs';
import { decode, run } from '../src/process.mjs';

const root=resolve(fileURLToPath(new URL('..',import.meta.url)));
const keys=['physicalWifi','systemAppVerified','appGroupVerified','nativeShortcutVisible',
  'baselineKnown','inputAttempted','freshFinishedJournal','rawLibraryExported','modelCalled','permissionDialogAccepted'];
export function projectShortcut(value) {
  if(!value||keys.some(k=>typeof value[k]!=='boolean')||
      value.rawLibraryExported||value.modelCalled||value.permissionDialogAccepted)
    throw Error('untrustedShortcutReport');
  return Object.fromEntries(keys.map(k=>[k,value[k]]));
}
export function verifiedShortcut(report, receipt, taskId) {
  return keys.slice(0,7).every(k=>report[k]===true) &&
    report.rawLibraryExported===false&&report.modelCalled===false&&report.permissionDialogAccepted===false&&
    typeof taskId==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(taskId)&&
    receipt?.taskId===taskId&&receipt?.stage==='finished'&&receipt?.evidence==='physical-own-app-journal';
}
async function main(){
  const python=process.env.IGENTIC_OIU_PYTHON;
  if(process.platform!=='darwin'||process.argv.length!==2||!python||!isAbsolute(python))throw Error('localAdapterNotConfigured');
  const env={...process.env};
  for(const key of Object.keys(env))if(key.startsWith('IGENTIC_IPHONE_')||['NODE_OPTIONS','NODE_PATH'].includes(key))delete env[key];
  const c=await loadConfig(join(homedir(),'Library/Application Support/iGentic/iphone-connect/config.json'));
  if(c.bundleId!=='de.bos.neoagent.igenticdiagnostics')throw Error('wrongApp');
  const client=new Client({name:'igentic-system-shortcut-acceptance',version:'1'});
  let session, dispatched=false;
  const invoke=async(name,args={})=>{const r=await client.callTool({name,arguments:args},undefined,{timeout:30000});if(r.isError)throw Error('toolFailed');return r.structuredContent.data};
  const wifi=async()=>{const r=await invoke('iphone_connection_report');if(r.transport!=='network-coredevice'||r.deviceStatus!=='coredevice-tunnel-observed')throw Error('wifiNotVerified');};
  try{
    await client.connect(new StdioClientTransport({command:process.execPath,args:[join(root,'src/server.mjs')],env,stderr:'ignore'}));
    await wifi();
    session=(await invoke('iphone_start_session',{device:'iphone-1'})).sessionId;
    const status=await invoke('iphone_native_app_status');
    if(status.installed!==true)throw Error('ownAppNotInstalled');
    const policy=decode(await run(c.policyPath,['observe-diagnostics'],{timeout:5000}));
    if(policy.allowed!==true||policy.auditEvents!==1)throw Error('policyDenied');
    // The local operator mode permits only the app-owned built-in read-only intent.
    // AppIntent itself independently enforces local-only policy.
    dispatched=true;
    const value=decode(await run(python,['-I',join(root,'scripts/system-shortcut-probe.py'),c.deviceId],{timeout:110000,maxBytes:65536}));
    const report=projectShortcut(value);
    await wifi();
    let receipt;
    if(report.freshFinishedJournal&&typeof value.taskId==='string')
      receipt=await invoke('iphone_shortcut_result',{taskId:value.taskId});
    const pass=verifiedShortcut(report,receipt,value.taskId);
    console.log(JSON.stringify({...report,independentMcpReceipt:pass,status:pass?'pass':report.inputAttempted?'unknown':'blocked'}));
    if(!pass)process.exitCode=2;
  }catch{
    console.log(JSON.stringify({status:dispatched?'unknown':'blocked',rawLibraryExported:false}));
    process.exitCode=2;
  }finally{if(session)await invoke('iphone_stop_session',{sessionId:session}).catch(()=>{});await client.close();}
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))
  main().catch(()=>{console.error('localSystemShortcutBlocked');process.exitCode=2;});
