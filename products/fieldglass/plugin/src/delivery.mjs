import { readPhysicalStatus } from './physical.mjs';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
const run = promisify(execFile);

export function selectedChannel(env = process.env, platform = process.platform) {
  const mode = env.FIELDGLASS_CHANNEL, device = env.FIELDGLASS_TARGET;
  if (!mode && !device) return {mode:'manual'};
  if (platform !== 'darwin' || !['simulator','device'].includes(mode) ||
      typeof device !== 'string' || !/^(?:[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}|[a-f0-9]{8}-[a-f0-9]{16}|[a-f0-9]{40})$/i.test(device)) return {mode:'configuration-error'};
  return {mode,device};
}

export function experimentLink(id, term, region) {
  const params = new URLSearchParams({id,term,region});
  return 'fieldglass://experiment/v1?' + params.toString().replaceAll('+','%20');
}

export async function deliver(channel, link, runner = run, check = readPhysicalStatus) {
  if (!['simulator','device'].includes(channel.mode)) return {status:'manual-handoff',link};
  if (channel.mode === 'device' && !['connected','available'].includes((await check(channel.device)).state)) {
    return {status:'device-unavailable',channel:channel.mode};
  }
  const args = channel.mode === 'simulator'
    ? ['simctl','openurl',channel.device,link]
    : ['devicectl','device','process','launch','--device',channel.device,'--payload-url',link,'org.fieldglass.workbench'];
  try {
    await runner('/usr/bin/xcrun',args,{timeout:12000,maxBuffer:64*1024,
      env:{PATH:'/usr/bin:/bin',HOME:process.env.HOME,TMPDIR:process.env.TMPDIR || '/tmp'}});
    return {status:'submitted',channel:channel.mode};
  } catch {
    return {status:'delivery-unconfirmed',channel:channel.mode};
  }
}
