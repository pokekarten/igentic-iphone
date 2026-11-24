// One-time setup for the iGentic-owned cellular readiness pairing secret.
// Creates a single 0600 random key on the host; never prints it by default.
import { randomBytes } from 'node:crypto';
import { mkdir, open, readFile, lstat } from 'node:fs/promises';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

export async function initCellularSecret({ root = join(homedir(), 'Library/Application Support/iGentic/iphone-cellular') } = {}) {
  await mkdir(root, { recursive: true, mode: 0o700 });
  const info = await lstat(root);
  if (!info.isDirectory() || (info.mode & 0o077) !== 0)
    throw Error('cellularDirectoryMustBePrivate');
  const path = join(root, 'readiness.key');
  const file = await open(path, 'wx', 0o600);
  try {
    await file.writeFile(randomBytes(32).toString('base64') + '\n');
  } finally { await file.close(); }
  return path;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const root = join(homedir(), 'Library/Application Support/iGentic/iphone-cellular');
  const keyFile = join(root, 'readiness.key');
  if (process.argv.length === 3 && process.argv[2] === '--show-key' && process.stdout.isTTY) {
    try {
      const info = await lstat(keyFile);
      if (!info.isFile() || (info.mode & 0o077) !== 0) throw Error('insecureSecretFile');
      process.stdout.write(await readFile(keyFile, 'utf8'));
    } catch {
      console.error('localKeyUnavailable');
      process.exitCode = 1;
    }
  } else if (process.argv.length === 2) {
    initCellularSecret({ root }).then(() => console.log('Cellular private pairing key created; never printed.'))
      .catch(() => { console.error('cellularKeyAlreadyExistsOrPermissionDenied'); process.exitCode = 1; });
  } else {
    console.error('Usage: node scripts/init-cellular.mjs [--show-key in a private interactive terminal]');
    process.exitCode = 2;
  }
}
