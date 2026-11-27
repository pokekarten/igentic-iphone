import test from 'node:test';
import assert from 'node:assert/strict';
import { evidence, parseMode, run } from '../scripts/control-center.mjs';
const result = x => ({ status: 0, stdout: JSON.stringify(x) });
test('explicit modes only', () => {
  for (const args of [[], ['wifi','--other'], ['arbitrary'], ['__proto__']]) assert.throws(() => parseMode(args));
  assert.equal(parseMode(['plan']), 'plan');
});
test('plan never invokes commands', () => {
  assert.deepEqual(run('plan', () => { throw Error('side effect'); }).steps, []);
});
test('fixture cannot count as physical Wi-Fi or UI', () => {
  const x = result({ backend:'fixture', action:'verified', receipt:'verified', privateContentReturned:false });
  assert.equal(evidence('fixtureRoundtrip', x).status, 'pass');
  assert.equal(evidence('legacyUi', x).status, 'blocked');
  assert.equal(evidence('nativeWifi', x).status, 'blocked');
});
test('timeout stops physical sequence and exposes no subprocess output', () => {
  const seen = [];
  const report = run('wifi', n => { seen.push(n); return {error:{code:'ETIMEDOUT'}, stdout:'secret'}; }, 'darwin');
  assert.deepEqual(seen, ['nativeWifi']);
  assert.equal(report.steps[0].status, 'unknown');
  assert.equal(JSON.stringify(report).includes('secret'), false);
});
test('missing wireless discovery stops legacy UI', () => {
  const seen = [];
  const report = run('wifi-ui', n => { seen.push(n); return result({wireless_discovery_candidate:false}); }, 'darwin');
  assert.deepEqual(seen,['wirelessReadiness']);
  assert.equal(report.steps[0].status,'blocked');
});
test('app process is not UI or ChatGPT evidence', () => {
  const report = run('wifi', n => n==='nativeWifi' ? result({backend:'physical',transport:'network-coredevice',installed:true,independentProcessVerification:true,privateContentReturned:false}) : result({}), 'darwin');
  assert.equal(report.steps[0].scope,'physical-app-process-not-ui');
  assert.equal(report.chatGPTAccountRoundtripVerified,false);
});
test('preview requires structured physical evidence, not successful exit alone', () => {
  assert.equal(evidence('nativePreview', result({})).status, 'blocked');
  assert.equal(evidence('nativePreview', result({
    backend:'physical', transport:'network-coredevice', mcpClient:'local-sdk-test-client',
    ownAppInstalled:true, mcpHandoffToolInvoked:true, distinctFreshPreviewReceipts:true,
    freshComparedWithPriorRun:true, invalidOwnAppRouteIgnored:true, reminderCreationAttempted:false,
    manualApprovalBypassed:false, crossAppControl:false, privateContentReturned:false
  })).status,'pass');
});
test('doctor reads device discovery even when a lease notice follows', () => {
  assert.equal(evidence('nativeDoctor',{status:0,stdout:'{"configured":true,"devices":[{"kind":"physical","available":true}]}\n{"lease":"active"}'}).status,'pass');
});

test('screen acceptance requires physical evidence and no exported image or touch claim', () => {
  const x = {physicalWifi:true,ownAppReceipt:true,screenshotCaptured:true,width:1260,height:2736,rawImageExported:false,touchTested:false,visibleAppVerified:false,streamVerified:false};
  assert.equal(evidence('nativeScreen',result(x)).status,'pass');
  for (const change of [{physicalWifi:false},{ownAppReceipt:false},{width:0},{rawImageExported:true},{touchTested:true},{visibleAppVerified:true},{streamVerified:true}])
    assert.equal(evidence('nativeScreen',result({...x,...change})).status,'blocked');
  assert.equal(run('screen',()=>result(x),'linux').steps[0].reason,'macos-required');
});

test('touch proof cannot be inferred from AX, screenshot, or uncertain input', () => {
  const x={mode:'touch',status:'pass',physicalWifi:true,ownAppReceipt:true,
    ownAppPidVerified:true,accessibilityBefore:true,targetUnique:true,rawContentExported:false,screenBefore:true,
    hidAuthorized:true,inputAttempted:true,screenAfter:true,navigationVerified:true};
  assert.equal(evidence('nativeTouch',result(x)).status,'pass');
  for(const key of ['ownAppPidVerified','screenBefore','hidAuthorized','inputAttempted','screenAfter','navigationVerified','targetUnique'])
    assert.equal(evidence('nativeTouch',result({...x,[key]:false})).status,'unknown');
  assert.equal(evidence('nativeTouch',{status:2,stdout:JSON.stringify({status:'unknown',private:'not returned'})}).status,'unknown');
  assert.equal(evidence('nativeAx',result({...x,mode:'ax'})).status,'blocked');
});

test('physical input missing or malformed final report is unknown, never retried', () => {
  for (const name of ['nativeTouch','systemShortcut']) {
    for (const report of [
      {status:0,stdout:''}, {status:0,stdout:'not JSON'}, {status:0,stdout:'null'},
      {status:0,stdout:'{}'}, {status:2,stdout:'unrelated stdout'},
      {status:2,stdout:JSON.stringify({status:'blocked'})},
      {status:2,stdout:JSON.stringify({status:'blocked',inputAttempted:false})},
      {status:0,stdout:JSON.stringify({status:'unknown',inputAttempted:true})},
      {status:2,stdout:JSON.stringify({status:'blocked',inputAttempted:true})}
    ]) {
      let calls=0;
      const mode=name==='nativeTouch'?'touch':'shortcut';
      const r=run(mode,()=>{calls++;return report},'darwin');
      assert.equal(r.steps[0].status,'unknown');
      assert.equal(calls,1);
      assert.equal(r.chatGPTAccountRoundtripVerified,false);
    }
  }
});
test('only full consistent pre-input block report is blocked', () => {
  const x={mode:'touch',status:'blocked',physicalWifi:true,ownAppReceipt:true,
    ownAppPidVerified:true,accessibilityBefore:false,targetUnique:false,rawContentExported:false,
    screenBefore:false,hidAuthorized:false,inputAttempted:false,screenAfter:false,navigationVerified:false};
  const y={status:'blocked',physicalWifi:true,systemAppVerified:true,appGroupVerified:false,
    nativeShortcutVisible:false,baselineKnown:false,inputAttempted:false,freshFinishedJournal:false,
    rawLibraryExported:false,modelCalled:false,permissionDialogAccepted:false,independentMcpReceipt:false};
  for (const [name,r] of [['nativeTouch',x],['systemShortcut',y]]) {
    assert.equal(evidence(name,{status:2,stdout:JSON.stringify(r)}).status,'blocked');
    assert.equal(evidence(name,{status:2,stdout:JSON.stringify({...r,inputAttempted:true})}).status,'unknown');
    assert.equal(evidence(name,{status:0,stdout:JSON.stringify(r)}).status,'unknown');
  }
});
test('verified shortcut passes only with complete evidence and final report', () => {
  const r={status:'pass',physicalWifi:true,systemAppVerified:true,appGroupVerified:true,
    nativeShortcutVisible:true,baselineKnown:true,inputAttempted:true,freshFinishedJournal:true,
    rawLibraryExported:false,modelCalled:false,permissionDialogAccepted:false,independentMcpReceipt:true};
  assert.equal(evidence('systemShortcut',result(r)).status,'pass');
  assert.equal(evidence('systemShortcut',{status:0,stdout:JSON.stringify(r)+'\nunrelated final line'}).status,'unknown');
  assert.equal(evidence('systemShortcut',{status:2,stdout:JSON.stringify(r)}).status,'unknown');
});
