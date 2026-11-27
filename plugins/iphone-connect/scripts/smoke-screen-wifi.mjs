import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { mkdtemp, open, rm, stat } from 'node:fs/promises';
import { homedir, tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadConfig } from '../src/backend.mjs';
import { run } from '../src/process.mjs';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const bundle = 'de.bos.neoagent.igenticdiagnostics';
const maxBytes = 32 * 1024 * 1024;
export function pngDimensions(header, size) {
  if (!Buffer.isBuffer(header) || header.length < 24 || size < 45 || size > maxBytes ||
      !header.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])) ||
      header.readUInt32BE(8) !== 13 || header.toString('ascii',12,16) !== 'IHDR')
    throw new Error('invalidPngHeader');
  const width = header.readUInt32BE(16), height = header.readUInt32BE(20);
  if (!width || !height || width > 16384 || height > 16384) throw new Error('invalidPngDimensions');
  return { width, height };
}

async function main() {
  // Explicit local operator acceptance only. Never expose a screenshot tool
  // through MCP, accept an arbitrary bundle, or return the screenshot bytes.
  if (process.platform !== 'darwin' || process.argv.length !== 2) throw Error('localMacOnly');
  const env = { ...process.env };
  for (const k of Object.keys(env))
    if (k.startsWith('IGENTIC_IPHONE_') || ['NODE_OPTIONS','NODE_PATH'].includes(k)) delete env[k];
  const config = await loadConfig(join(homedir(),'Library/Application Support/iGentic/iphone-connect/config.json'));
  if (config.bundleId !== bundle) throw Error('wrongApp');
  const client = new Client({name:'igentic-local-screen-acceptance',version:'1'});
  let session;
  const dir = await mkdtemp(join(tmpdir(),'igentic-screen-local-'));
  const invoke = async (name,args={}) => {
    const reply = await client.callTool({name,arguments:args},undefined,{timeout:30000});
    if (reply.isError) throw Error('toolFailed');
    return reply.structuredContent.data;
  };
  const requireWifi = async () => {
    const report = await invoke('iphone_connection_report');
    if (report.transport !== 'network-coredevice' || report.deviceStatus !== 'coredevice-tunnel-observed')
      throw Error('wifiNotVerified');
  };
  try {
    await client.connect(new StdioClientTransport({command:process.execPath,args:[join(root,'src/server.mjs')],env,stderr:'ignore'}));
    await requireWifi();
    session = (await invoke('iphone_start_session',{device:'iphone-1'})).sessionId;
    const before = await invoke('iphone_open_diagnostics',{sessionId:session});
    if (!before.markers?.includes('iGentic Diagnostics')) throw Error('ownAppReceiptMissing');
    const path = join(dir,'screen.png');
    await run('/usr/bin/xcrun',['devicectl','device','capture','screenshot','--device',config.deviceId,'--destination',path,'--timeout','15'],{timeout:20000});
    const info = await stat(path);
    if (!info.isFile() || info.size > maxBytes) throw Error('invalidScreenFile');
    const fd = await open(path,'r');
    let dimensions;
    try {
      const header = Buffer.alloc(24);
      const result = await fd.read(header,0,24,0);
      if (result.bytesRead !== 24) throw Error('invalidScreenFile');
      dimensions = pngDimensions(header, info.size);
    } finally { await fd.close(); }
    const after = await invoke('iphone_observe',{sessionId:session});
    if (!after.markers?.includes('iGentic Diagnostics')) throw Error('ownAppReceiptMissingAfterCapture');
    await requireWifi();
    // Metadata only; a valid PNG is not proof of what app was visible.
    console.log(JSON.stringify({physicalWifi:true,ownAppReceipt:true,screenshotCaptured:true,...dimensions,
      rawImageExported:false,touchTested:false,visibleAppVerified:false,streamVerified:false}));
  } finally {
    try { await rm(dir,{recursive:true,force:true}); }
    finally {
      if (session) await invoke('iphone_stop_session',{sessionId:session}).catch(()=>{});
      await client.close();
    }
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(()=>{console.error('localScreenAcceptanceBlocked');process.exitCode=2;});
}
