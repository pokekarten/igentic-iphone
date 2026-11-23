import { cp, mkdir, mkdtemp, readFile, writeFile, rm, copyFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { createHash } from 'node:crypto';
import { ROOT } from '../src/server.mjs';
import { run } from '../src/process.mjs';

const stage = await mkdtemp(join(tmpdir(), 'igentic-package-'));
try {
  const folder = join(stage, 'igentic-iphone-connect'); await mkdir(folder);
  for (const file of ['src', 'ui', 'skills', 'scripts', 'plugin.json', 'mcp.json', 'package.json',
    'package-lock.json', 'README.md', 'PORTABLE_MCP.md', 'FIRST_PARTY_COREDEVICE.md', 'CELLULAR_COMPANION.md', 'PRIVACY.md', 'THIRD_PARTY_NOTICES.md']) {
    await cp(join(ROOT, file), join(folder, file), { recursive: true });
  }
  await copyFile(resolve(ROOT, '../../LICENSE'), join(folder, 'LICENSE'));
  await copyFile(resolve(ROOT, '../../docs/reports/chatgpt-iphone-plugin-2026-11-22.md'), join(folder, 'EVIDENCE.md'));
  const readmePath = join(folder, 'README.md');
  await writeFile(readmePath, (await readFile(readmePath, 'utf8')).replace(
    '../../docs/reports/chatgpt-iphone-plugin-2026-11-22.md', 'EVIDENCE.md'));
  const policy = process.env.IGENTIC_POLICY_TEST_PATH;
  if (policy) { await mkdir(join(folder, 'bin')); await copyFile(policy, join(folder, 'bin/iGenticPluginPolicy')); }
  await run(process.platform === 'win32' ? 'npm.cmd' : 'npm', ['ci', '--omit=dev',
    '--ignore-scripts', '--no-audit', '--no-fund'], { timeout: 120000, cwd: folder });
  const dest = join(ROOT, 'dist'); await mkdir(dest, { recursive: true });
  const archive = join(dest, `igentic-iphone-connect-0.1.0-${process.platform}-${process.arch}.tar.gz`);
  await run('/usr/bin/tar', [...(process.platform === 'darwin' ? ['--disable-copyfile'] : []),
    '-czf', archive, '-C', stage, 'igentic-iphone-connect'], { timeout: 60000 });
  const hash = createHash('sha256').update(await readFile(archive)).digest('hex');
  await writeFile(`${archive}.sha256`, `${hash}  ${archive.split('/').at(-1)}\n`);
  console.log(JSON.stringify({ archive, sha256: hash, policyHelperIncluded: Boolean(policy),
    mobilecliBundled: false, privateConfigBundled: false }));
} finally { await rm(stage, { recursive: true, force: true }); }
