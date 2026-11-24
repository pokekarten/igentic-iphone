// First-party, read-only Mac readiness report for a *future* physical iPhone
// installation. No Apple account changes, device actions or network requests.
// Output is fixed booleans/codes; never identities, paths, hostnames or keys.
import { readFile, readdir } from 'node:fs/promises';
import { execFile as execFileCb } from 'node:child_process';
import { promisify } from 'node:util';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const execFile = promisify(execFileCb);
const project = fileURLToPath(new URL('../../../app/iGenticDiagnostics/iGenticDiagnostics.xcodeproj/project.pbxproj', import.meta.url));
const doctor = fileURLToPath(new URL('./doctor.mjs', import.meta.url));
const profileDirectories = [
  join(homedir(), 'Library/Developer/Xcode/UserData/Provisioning Profiles'),
  join(homedir(), 'Library/MobileDevice/Provisioning Profiles')
];

export function evaluateSigningProject(text) {
  if (typeof text !== 'string' || !text.includes('iGenticDiagnostics')) {
    return { projectPresent:false, teamConfigured:false, ownBundleConfigured:false };
  }
  const teams = [...text.matchAll(/\bDEVELOPMENT_TEAM\s*=\s*([^;]+);/g)]
    .map(match => match[1].trim().replace(/^"|"$/g, ''));
  const ids = [...text.matchAll(/\bPRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);/g)]
    .map(match => match[1].trim().replace(/^"|"$/g, ''));
  return {
    projectPresent:true,
    teamConfigured: teams.length >= 2 && teams.every(x => x.length > 0 && x !== '$(DEVELOPMENT_TEAM)'),
    ownBundleConfigured: ids.length >= 2 && ids.every(x =>
      x.length > 0 && !x.startsWith('org.example.') && !x.includes('$('))
  };
}

export function classifySigningIdentityOutput(text) {
  const match = /(\d+)\s+valid identities found/.exec(text || '');
  return match ? Number(match[1]) > 0 : false;
}

export function classifyOwnDeviceDoctor(text) {
  try {
    const value = JSON.parse(text);
    return Array.isArray(value.devices) && value.devices.some(d =>
      d.kind === 'physical' && d.available === true &&
      d.connectionState === 'xcode-tunnel-available' &&
      ['network-coredevice', 'usb-coredevice'].includes(d.connectionPath));
  } catch { return false; }
}

export function assessPhysicalPreflight({
  projectPresent=false, teamConfigured=false, ownBundleConfigured=false,
  signingIdentityAvailable=false, localProfileCandidates=false,
  physicalDeviceTunnel=false, ownerHttpsConfigurationProvided=false
}={}) {
  return {
    status: !projectPresent || !teamConfigured || !ownBundleConfigured
      ? 'owner-signing-settings-required'
      : !signingIdentityAvailable || !physicalDeviceTunnel
        ? 'device-signing-prerequisites-unverified'
        : 'physical-install-not-performed',
    projectPresent: Boolean(projectPresent),
    teamConfigured: Boolean(teamConfigured),
    ownBundleConfigured: Boolean(ownBundleConfigured),
    signingIdentityAvailable: Boolean(signingIdentityAvailable),
    localProfileCandidates: Boolean(localProfileCandidates),
    physicalDeviceTunnel: Boolean(physicalDeviceTunnel),
    ownerHttpsConfigurationProvided: Boolean(ownerHttpsConfigurationProvided),
    actualProfileMatchVerified: false,
    physicalAppInstalledVerified: false,
    cellularTransportVerified: false
  };
}

async function hasCandidateProfileFile() {
  for (const dir of profileDirectories) {
    try {
      if ((await readdir(dir)).some(name =>
        name.endsWith('.mobileprovision') || name.endsWith('.provisionprofile')))
        return true;
    } catch { /* Directory may not exist; do not infer enrollment. */ }
  }
  return false;
}
async function fixedCommand(binary, args) {
  try {
    const { stdout }=await execFile(binary,args,{ timeout:12000, maxBuffer:256*1024 });
    return stdout;
  } catch { return ''; }
}
export async function physicalCellularPreflight(env=process.env) {
  let signing;
  try { signing=evaluateSigningProject(await readFile(project,'utf8')); }
  catch { signing=evaluateSigningProject(''); }
  const [identityOutput, ownDoctorOutput, localProfileCandidates]=await Promise.all([
    process.platform==='darwin' ? fixedCommand('security',['find-identity','-v','-p','codesigning']) : Promise.resolve(''),
    fixedCommand(process.execPath,[doctor]),
    hasCandidateProfileFile()
  ]);
  return assessPhysicalPreflight({
    ...signing,
    signingIdentityAvailable:classifySigningIdentityOutput(identityOutput),
    localProfileCandidates,
    physicalDeviceTunnel:classifyOwnDeviceDoctor(ownDoctorOutput),
    ownerHttpsConfigurationProvided: Boolean(
      env.IGENTIC_CELLULAR_ENDPOINT && env.IGENTIC_CELLULAR_SHARED_KEY_FILE
    )
  });
}

if (process.argv[1] && fileURLToPath(import.meta.url)===process.argv[1]) {
  physicalCellularPreflight().then(result => console.log(JSON.stringify(result)))
    .catch(() => console.log(JSON.stringify(assessPhysicalPreflight())));
}
