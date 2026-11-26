import test from 'node:test';
import assert from 'node:assert/strict';
import {projectShortcut,verifiedShortcut} from '../scripts/smoke-system-shortcut-wifi.mjs';
import {evidence,run} from '../scripts/control-center.mjs';

const x={physicalWifi:true,systemAppVerified:true,appGroupVerified:true,nativeShortcutVisible:true,
  baselineKnown:true,inputAttempted:true,freshFinishedJournal:true,
  rawLibraryExported:false,modelCalled:false,permissionDialogAccepted:false};
const id='11111111-1111-4111-8111-111111111111';
const receipt={taskId:id,stage:'finished',evidence:'physical-own-app-journal'};
test('system shortcut projection never exports private fields',()=>{
  assert.deepEqual(projectShortcut({...x,taskId:id,rows:'private'},'shortcut'),x);
  for(const key of ['rawLibraryExported','modelCalled','permissionDialogAccepted'])
    assert.throws(()=>projectShortcut({...x,[key]:true}));
});
test('fresh local status is not a pass without independently matched receipt',()=>{
  assert.equal(verifiedShortcut(x,receipt,id),true);
  assert.equal(verifiedShortcut(x,{...receipt,taskId:'other'},id),false);
  assert.equal(verifiedShortcut(x,{...receipt,stage:'awaitingFinish'},id),false);
  assert.equal(verifiedShortcut({...x,inputAttempted:false},receipt,id),false);
  assert.equal(verifiedShortcut({...x,freshFinishedJournal:false},receipt,id),false);
});
test('runner cannot promote unknown or local model claims to physical success',()=>{
  const report={...x,independentMcpReceipt:true,status:'pass'};
  assert.equal(evidence('systemShortcut',{status:0,stdout:JSON.stringify(report)}).status,'pass');
  assert.equal(evidence('systemShortcut',{status:0,stdout:JSON.stringify({...report,independentMcpReceipt:false})}).status,'blocked');
  assert.equal(evidence('systemShortcut',{status:2,stdout:JSON.stringify({status:'unknown',private:'do not export'})}).status,'unknown');
  assert.equal(evidence('systemShortcut',{status:0,stdout:JSON.stringify({...report,modelCalled:true})}).status,'blocked');
  assert.equal(run('shortcut',()=>{throw Error('must not dispatch')},'linux').steps[0].reason,'macos-required');
});
