import { mkdir, copyFile, chmod, writeFile, stat } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join, isAbsolute, resolve } from 'node:path';
import { ROOT } from '../src/server.mjs';
import { run, decode } from '../src/process.mjs';
import { loadConfig } from '../src/backend.mjs';

// Local operator setup only; not exposed as an MCP tool. No signing, install,
// credential read, remote service or device mutation.
const option = name => { const n = process.argv.indexOf(name); return n < 0 ? undefined : process.argv[n + 1]; };
try {
  const mobilecliPath = option('--mobilecli');
  if (!isAbsolute(mobilecliPath ?? '') || !(await stat(mobilecliPath)).isFile())
    throw new Error('Pass --mobilecli with the absolute path of your separately installed MobileCLI.');
  const json = decode(await run('/usr/bin/xcrun', ['devicectl', 'list', 'devices', '--json-output', '-']));
  const devices = (json.result?.devices ?? []).filter(d => d.hardwareProperties?.reality === 'physical');
  const selected = option('--device');
  const d = selected ? devices.find(d => d.hardwareProperties?.udid === selected || d.identifier === selected)
    : devices.length === 1 ? devices[0] : null;
  if (!d) throw new Error('Select exactly one paired physical iPhone with --device in your local terminal.');
  const root = join(homedir(), 'Library/Application Support/iGentic/iphone-connect');
  await mkdir(root, { recursive: true, mode: 0o700 }); await chmod(root, 0o700);
  let compiled = option('--policy');
  if (!compiled) {
    const embedded = join(ROOT, 'bin/iGenticPluginPolicy');
    try { if ((await stat(embedded)).isFile()) compiled = embedded; } catch {}
  }
  let policySource = compiled;
  if (!compiled) {
    const repo = resolve(ROOT, '../..');
    const scratch = join(root, 'build');
    await run('/usr/bin/xcrun', ['swift', 'build', '--package-path', join(repo, 'ios'), '--product',
      'iGenticPluginPolicy', '--scratch-path', scratch, '-j', '1'], { timeout: 120000 });
    policySource = join(scratch, 'debug/iGenticPluginPolicy');
  }
  if (!isAbsolute(policySource ?? '')) throw new Error('Policy helper path must be absolute.');
  const policyPath = join(root, 'iGenticPluginPolicy');
  await copyFile(policySource, policyPath); await chmod(policyPath, 0o700);
  const configPath = join(root, 'config.json');
  const config = { deviceId: d.hardwareProperties.udid, bundleId: 'de.bos.neoagent.igenticdiagnostics', mobilecliPath, policyPath };
  await writeFile(configPath, JSON.stringify(config), { mode: 0o600 }); await chmod(configPath, 0o600);
  await loadConfig(configPath);
  console.log('Local physical iPhone configured. Private identifiers remain in the local 0600 config.');
} catch (e) { console.error(e.code ?? (e.message?.includes('path') ? e.message : 'setupFailed')); process.exitCode = 1; }
