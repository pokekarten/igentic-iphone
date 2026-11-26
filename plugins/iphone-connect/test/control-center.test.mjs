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
    assert.equal(evidence('nativeTouch',result({...x,[key]:false})).status,'blocked');
  assert.equal(evidence('nativeTouch',{status:2,stdout:JSON.stringify({status:'unknown',private:'not returned'})}).status,'unknown');
  assert.equal(evidence('nativeAx',result({...x,mode:'ax'})).status,'blocked');
});
