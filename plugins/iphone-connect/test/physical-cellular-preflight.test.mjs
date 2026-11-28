import test from 'node:test';
import assert from 'node:assert/strict';
import {
  evaluateSigningProject, classifySigningIdentityOutput,
  classifyOwnDeviceDoctor, assessPhysicalPreflight
} from '../scripts/physical-cellular-preflight.mjs';

const project = (team='',bundle='org.example.iGenticDiagnostics') =>
  'iGenticDiagnostics; DEVELOPMENT_TEAM = "'+team+'"; ' +
  'DEVELOPMENT_TEAM = "'+team+'"; ' +
  'PRODUCT_BUNDLE_IDENTIFIER = '+bundle+'; ' +
  'PRODUCT_BUNDLE_IDENTIFIER = '+bundle+'.Tests;';

test('project and signing check recognizes missing team/placeholder without leaking IDs', () => {
  assert.deepEqual(evaluateSigningProject(project()),{
    projectPresent:true,teamConfigured:false,ownBundleConfigured:false
  });
  assert.deepEqual(evaluateSigningProject(project('TEAMVALUE','com.owner.private')),{
    projectPresent:true,teamConfigured:true,ownBundleConfigured:true
  });
  assert.equal(evaluateSigningProject('not a project').projectPresent,false);
  assert.equal(evaluateSigningProject(project('TEAMVALUE','org.example.placeholder'))
    .ownBundleConfigured,false);
});

test('signing identities are reported only as a boolean',()=>{
  assert.equal(classifySigningIdentityOutput('     1 valid identities found'),true);
  assert.equal(classifySigningIdentityOutput('     0 valid identities found'),false);
  assert.equal(classifySigningIdentityOutput('error: unavailable'),false);
});

test('simulator-only, absent or vague doctor entries are not a physical tunnel',()=>{
  const data=x=>JSON.stringify({configured:true,devices:x});
  assert.equal(classifyOwnDeviceDoctor('untrusted output'),false);
  assert.equal(classifyOwnDeviceDoctor(data([{kind:'simulator',available:true,
    connectionState:'xcode-tunnel-available',connectionPath:'network-coredevice'}])),false);
  assert.equal(classifyOwnDeviceDoctor(data([{kind:'physical',available:true,
    connectionState:'not-running',connectionPath:'network-coredevice'}])),false);
  assert.equal(classifyOwnDeviceDoctor(data([{kind:'physical',available:true,
    connectionState:'xcode-tunnel-available',connectionPath:'network-coredevice'}])),true);
});

test('preflight never claims installation, cellular transport or matching profiles',()=>{
  const report=assessPhysicalPreflight({
    projectPresent:true,teamConfigured:true,ownBundleConfigured:true,
    signingIdentityAvailable:true,localProfileCandidates:true,
    physicalDeviceTunnel:true,ownerHttpsConfigurationProvided:true
  });
  assert.equal(report.status,'physical-install-not-performed');
  assert.equal(report.actualProfileMatchVerified,false);
  assert.equal(report.physicalAppInstalledVerified,false);
  assert.equal(report.cellularTransportVerified,false);
  assert.equal(assessPhysicalPreflight({
    projectPresent:true,teamConfigured:false,ownBundleConfigured:false,
    signingIdentityAvailable:true,physicalDeviceTunnel:true
  }).status,'owner-signing-settings-required');
  // The sanitized report deliberately has no paths, identities or secrets.
  const forbidden=/bundleIdentifier|teamIdentifier|deviceIdentifier|secret|hostname|udid|ecid/i;
  for(const key of Object.keys(report)) assert.equal(forbidden.test(key),false,key);
});
