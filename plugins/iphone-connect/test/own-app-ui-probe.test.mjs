import test from 'node:test';
import assert from 'node:assert/strict';
import {projectUiProbe, ownProcessId} from '../scripts/smoke-ui-wifi.mjs';
const x={physicalWifi:true,ownAppPidVerified:true,screenBefore:false,accessibilityBefore:true,targetUnique:true,
  hidAuthorized:false,inputAttempted:false,screenAfter:false,navigationVerified:false,rawContentExported:false};
test('AX output is a closed boolean projection',()=>{
  assert.deepEqual(projectUiProbe({...x,rows:'private'},'ax'),x);
  assert.throws(()=>projectUiProbe({...x,rawContentExported:true},'ax'));
  assert.throws(()=>projectUiProbe({...x,inputAttempted:true},'ax'));
  assert.throws(()=>projectUiProbe({...x,targetUnique:'true'},'ax'));
});

test('process identity requires unique exact installed executable',()=>{
  const apps=[{bundleIdentifier:'de.bos.neoagent.igenticdiagnostics',url:'file:///example/iGentic.app/'}];
  const p={executable:'file:///example/iGentic.app/iGenticDiagnostics',processIdentifier:123};
  assert.equal(ownProcessId(apps,[p]),123);
  assert.throws(()=>ownProcessId(apps,[{...p,executable:'file:///other/iGenticDiagnostics'}]));
  assert.throws(()=>ownProcessId(apps,[p,p]));
  assert.throws(()=>ownProcessId(apps,[{...p,processIdentifier:'123'}]));
});
