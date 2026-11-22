import {parseArgs} from 'node:util';
import {randomUUID} from 'node:crypto';
import {dirname} from 'node:path';
import {mkdir,rename,stat,writeFile,rm} from 'node:fs/promises';
import {configPath,schema} from '../src/config.mjs';
import {selectedChannel} from '../src/delivery.mjs';
const {values} = parseArgs({options:{mode:{type:'string'},target:{type:'string'},driver:{type:'string'},capture:{type:'boolean'}}});
const parsed=schema.safeParse(values);
if (!parsed.success || (values.mode !== 'manual' && selectedChannel({FIELDGLASS_CHANNEL:values.mode,FIELDGLASS_TARGET:values.target}).mode !== values.mode)) {
  console.error('Usage: node scripts/configure.mjs --mode manual | --mode simulator|device --target ID [--capture] [--driver ABSOLUTE_XCTESTRUN]'); process.exit(2);
}
if (values.driver && !(await stat(values.driver)).isFile()) throw Error('Missing XCTest build.');
await mkdir(dirname(configPath),{recursive:true,mode:0o700});
const pending=configPath+'.'+randomUUID();
try {
  await writeFile(pending,JSON.stringify(parsed.data),{mode:0o600,flag:'wx'});
  await rename(pending,configPath);
} finally {await rm(pending,{force:true})}
console.log('Fieldglass channel: '+values.mode+'. Restart the plugin session to apply.');
