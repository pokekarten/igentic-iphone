import { execFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdir, mkdtemp, stat, rm, chmod } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join, basename } from 'node:path';

const exec = promisify(execFile);
const childEnv = () => ({PATH:'/usr/bin:/bin',HOME:homedir(),TMPDIR:process.env.TMPDIR || '/tmp'});
const storage = () => join(homedir(),'Library','Application Support','Fieldglass','Captures');

async function sim(args, maxBuffer=65536) {
  return exec('/usr/bin/xcrun',['simctl',...args],{env:childEnv(),timeout:12000,maxBuffer});
}
export async function simulatorInfo(device) {
  const {stdout} = await sim(['list','devices','--json'],2*1024*1024);
  for (const [runtime,devices] of Object.entries(JSON.parse(stdout).devices)) {
    const found=devices.find(d => d.udid.toLowerCase() === device.toLowerCase());
    if (found) return {runtime:runtime.split('.').pop(),state:found.state,available:found.isAvailable === true};
  }
  return {state:'missing',available:false};
}
export async function lifecycle(device, action) {
  await sim([action,device,'org.fieldglass.workbench']);
  return {status:'submitted',action};
}

// End recording with SIGINT so simctl finalizes the movie. A separate deadline
// bounds startup on an unavailable display. Keep an incomplete movie private.
function clip(device, file, seconds, signal) {
  return new Promise((resolve,reject) => {
    const child = spawn('/usr/bin/xcrun',['simctl','io',device,'recordVideo','--codec=h264',file],
      {env:childEnv(),stdio:['ignore','ignore','pipe']});
    let stopTimer, started=false, tail='';
    const abort = () => child.kill('SIGKILL');
    const deadline = setTimeout(abort,(seconds+15)*1000);
    signal?.addEventListener('abort',abort,{once:true});
    if (signal?.aborted) abort();
    child.stderr.on('data', data => {
      tail=(tail+String(data)).slice(-2048);
      if (!started && /recording started/i.test(tail)) {
        started=true; stopTimer=setTimeout(() => child.kill('SIGINT'),seconds*1000);
      }
    });
    function cleanup() {
      clearTimeout(deadline); clearTimeout(stopTimer);
      signal?.removeEventListener('abort',abort);
    }
    child.once('error',err => {cleanup();reject(err)});
    child.once('close',(code,sig) => {
      cleanup();
      if (started && !signal?.aborted && (code === 0 || sig === 'SIGINT')) resolve();
      else reject(new Error('recording_failed'));
    });
  });
}
export function captureService(device) {
  let busy=false;
  return async (kind,seconds,signal) => {
    if (busy) return {status:'capture-busy'};
    busy=true;
    let folder;
    try {
      await mkdir(storage(),{recursive:true,mode:0o700});
      folder=await mkdtemp(join(storage(),'run-'));
      const filename=kind === 'screenshot' ? 'screen.png' : 'clip.mov';
      const file=join(folder,filename);
      if (kind === 'screenshot') await sim(['io',device,'screenshot','--type=png',file]);
      else await clip(device,file,seconds,signal);
      const bytes=(await stat(file)).size;
      if (!bytes || signal?.aborted) throw new Error('incomplete');
      await chmod(file,0o600);
      return {status:'saved-locally',file:'~/Library/Application Support/Fieldglass/Captures/'+basename(folder)+'/'+filename,bytes};
    } catch {
      if (folder) await rm(folder,{recursive:true,force:true});
      return {status:'capture-unavailable'};
    } finally {busy=false}
  };
}
