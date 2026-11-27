import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { homedir } from 'node:os';
import { isAbsolute, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadConfig } from '../src/backend.mjs';
import { decode, run } from '../src/process.mjs';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const bundle = 'de.bos.neoagent.igenticdiagnostics';
const flags = ['physicalWifi','ownAppPidVerified','screenBefore','accessibilityBefore','targetUnique',
  'hidAuthorized','inputAttempted','screenAfter','navigationVerified','rawContentExported'];

export function projectUiProbe(value, mode) {
  if (!value || flags.some(key=>typeof value[key]!=='boolean') || value.rawContentExported)
    throw Error('untrustedProbe');
  const result = Object.fromEntries(flags.map(key=>[key,value[key]]));
  if (mode === 'ax' && (result.inputAttempted || result.hidAuthorized || result.navigationVerified))
    throw Error('unexpectedAxInput');
  return result;
}

export function ownProcessId(apps, processes) {
  const matching=apps.filter(x=>x?.bundleIdentifier===bundle);
  if(matching.length!==1||typeof matching[0].url!=='string'||!matching[0].url.startsWith('file:')||!matching[0].url.endsWith('.app/'))throw Error('ownAppIdentityUnverified');
  const exact=processes.filter(p=>p?.executable===matching[0].url+'iGenticDiagnostics');
  if(exact.length!==1||!Number.isSafeInteger(exact[0].processIdentifier)||exact[0].processIdentifier<=0)throw Error('ownAppIdentityUnverified');
  return exact[0].processIdentifier;
}

async function main() {
  const mode = process.argv[2], python = process.env.IGENTIC_OIU_PYTHON;
  if (process.platform !== 'darwin' || process.argv.length !== 3 ||
      !['ax','touch'].includes(mode) || !python || !isAbsolute(python))
    throw Error('localAdapterNotConfigured');
  const env = {...process.env};
  for (const key of Object.keys(env))
    if (key.startsWith('IGENTIC_IPHONE_') || ['NODE_OPTIONS','NODE_PATH'].includes(key)) delete env[key];
  const config = await loadConfig(join(homedir(),'Library/Application Support/iGentic/iphone-connect/config.json'));
  if (config.bundleId !== bundle) throw Error('wrongApp');
  const client = new Client({name:'igentic-local-ui-acceptance',version:'1'});
  let session, dispatched=false, report;
  const invoke = async (name,args={})=>{
    const reply=await client.callTool({name,arguments:args},undefined,{timeout:30000});
    if (reply.isError) throw Error('toolFailed');
    return reply.structuredContent.data;
  };
  const requireWifi = async ()=>{
    const r=await invoke('iphone_connection_report');
    if(r.transport!=='network-coredevice'||r.deviceStatus!=='coredevice-tunnel-observed')throw Error('wifiNotVerified');
  };
  try {
    await client.connect(new StdioClientTransport({command:process.execPath,args:[join(root,'src/server.mjs')],env,stderr:'ignore'}));
    await requireWifi();
    session=(await invoke('iphone_start_session',{device:'iphone-1'})).sessionId;
    const before=await invoke('iphone_open_diagnostics',{sessionId:session});
    if(!before.markers?.includes('iGentic Diagnostics'))throw Error('ownAppReceiptMissing');
    for(const action of mode==='touch'?['observe-diagnostics','open-discovery']:['observe-diagnostics']){
      const p=decode(await run(config.policyPath,[action],{timeout:5000}));
      if(p.allowed!==true||p.auditEvents!==1)throw Error('policyDenied');
    }
    const core=async args=>decode(await run('/usr/bin/xcrun',['devicectl','device','info',...args,'--device',config.deviceId,'--json-output','-','--timeout','15'],{timeout:20000})).result;
    const apps=await core(['apps','--bundle-id',bundle]);
    const processes=await core(['processes','--search','iGentic']);
    const pid=ownProcessId(apps.apps,processes.runningProcesses);
    dispatched=mode==='touch';
    const raw=await run(python,['-I',join(root,'scripts/own-app-ui-probe.py'),mode,config.deviceId,String(pid)],{timeout:65000,maxBytes:65536});
    report=projectUiProbe(decode(raw),mode);
    await requireWifi();
    const pass=report.physicalWifi&&report.ownAppPidVerified&&report.accessibilityBefore&&report.targetUnique&&
      (mode==='ax'||(report.screenBefore&&report.hidAuthorized&&report.inputAttempted&&report.screenAfter&&report.navigationVerified));
    console.log(JSON.stringify({...report,mode,ownAppReceipt:true,
      status:pass?'pass':report.inputAttempted?'unknown':'blocked'}));
    if(!pass)process.exitCode=2;
  } catch {
    // A timed-out/malformed touch subprocess may already have sent input.
    console.log(JSON.stringify({mode,status:dispatched?'unknown':'blocked',rawContentExported:false}));
    process.exitCode=2;
  } finally {
    if(session)await invoke('iphone_stop_session',{sessionId:session}).catch(()=>{});
    await client.close();
  }
}

if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))
  main().catch(()=>{console.error('localAdapterNotConfigured');process.exitCode=2;});
