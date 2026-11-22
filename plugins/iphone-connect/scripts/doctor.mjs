import { homedir } from 'node:os';
import { join } from 'node:path';
import { readFile } from 'node:fs/promises';
import { loadConfig, MobileBackend } from '../src/backend.mjs';
const root = join(homedir(), 'Library/Application Support/iGentic/iphone-connect');
try {
  const c = await loadConfig(process.env.IGENTIC_IPHONE_CONFIG ?? join(root, 'config.json'));
  const backend = new MobileBackend(c);
  console.log(JSON.stringify({ configured: true, devices: await backend.list() }));
  try {
    const lease = JSON.parse(await readFile(join(root, 'device.lease'), 'utf8'));
    let running = true; try { process.kill(lease.pid, 0); } catch { running = false; }
    console.log(JSON.stringify({ lease: running ? 'active' : 'stale',
      next: running ? 'Stop the session in its owning client.' : 'Inspect the device, then remove only device.lease locally to recover.' }));
  } catch (e) { if (e.code !== 'ENOENT') throw e; }
} catch (e) { console.error(e.code === 'ENOENT' ? 'notConfigured: run setup first' : e.code ?? 'doctorFailed'); process.exitCode = 1; }
