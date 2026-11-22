import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdtemp, readdir, readFile, rm } from 'node:fs/promises';
import { tmpdir, homedir } from 'node:os';
import { join, isAbsolute } from 'node:path';
import { z } from 'zod';
const exec = promisify(execFile);
const coordinate=z.number().min(0).max(1);
const identifier=z.string().min(1).max(120);
const target=z.union([z.strictObject({identifier}),z.strictObject({x:coordinate,y:coordinate})]);
export const commandSchema=z.union([
  z.strictObject({action:z.literal('inspect')}),
  z.strictObject({action:z.literal('wait-for'),identifier}),
  z.strictObject({action:z.enum(['tap','double-tap','hold']),target}),
  z.strictObject({action:z.literal('swipe'),direction:z.enum(['up','down','left','right'])}),
  z.strictObject({action:z.literal('drag'),x:coordinate,y:coordinate,toX:coordinate,toY:coordinate}),
  z.strictObject({action:z.literal('type'),identifier,text:z.string().min(1).max(480)})
]);
export function labRunner(device,settings, bundle='org.fieldglass.workbench') {
  if (!settings || !isAbsolute(settings) || !settings.endsWith('.xctestrun') || !/^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$/.test(bundle))
    return null;
  let busy=false;
  return async (command, signal) => {
    if (busy) return {status:'busy'};
    busy=true;
    let folder;
    try {
      folder=await mkdtemp(join(tmpdir(),'fieldglass-lab-'));
      const results=join(folder,'result.xcresult'), exported=join(folder,'reports');
      const commands = Array.isArray(command) ? command : [command];
      const payload=Buffer.from(JSON.stringify(commands.map(({target,...rest}) => ({...rest,...target})))).toString('base64');
      const env={HOME:homedir(),PATH:'/usr/bin:/bin',TMPDIR:tmpdir(),TEST_RUNNER_FIELDGLASS_BUNDLE:bundle,
        TEST_RUNNER_FIELDGLASS_COMMAND:payload};
      await exec('/usr/bin/xcodebuild',['test-without-building','-xctestrun',settings,'-destination','platform=iOS Simulator,id='+device,
        '-parallel-testing-enabled','NO','-only-testing:FieldglassUITests/WorkbenchDriver/testCommand','-resultBundlePath',results],
        {env,signal,timeout:120000,maxBuffer:1024*1024});
      await exec('/usr/bin/xcrun',['xcresulttool','export','attachments','--path',results,'--output-path',exported,'--filter','fieldglass-command*'],
        {env,signal,timeout:10000});
      const matches=(await readdir(exported)).filter(f => f.endsWith('.json') && f !== 'manifest.json');
      if (matches.length !== 1) throw Error('missing report');
      const raw=JSON.parse(await readFile(join(exported,matches[0]),'utf8'));
      const step = z.union([
        z.strictObject({status:z.literal('observed'),identifiers:z.array(z.string().max(120)).max(180),inspected:z.number().int().max(180)}),
        z.strictObject({status:z.enum(['submitted','target-unavailable','target-not-editable','present','invalid-command'])})
      ]);
      const report=z.strictObject({steps:z.array(step).min(1).max(8)}).parse(raw);
      return Array.isArray(command) ? report : report.steps[0];
    } catch {
      return {status:command.action === 'inspect' ? 'observation-unavailable' : 'outcome-unknown'};
    } finally {
      try {if (folder) await rm(folder,{recursive:true,force:true})} finally {busy=false}
    }
  };
}
