import { spawn } from 'node:child_process';

export class PluginError extends Error {
  constructor(code) { super(code); this.code = code; }
}

// Never use a shell or return subprocess output/errors to the model. Device
// names, pairing diagnostics and arbitrary screen content can appear there.
export function run(file, args, { signal, timeout = 30000, maxBytes = 4 * 1024 * 1024, cwd } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(file, args, { cwd, shell: false, stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env, MOBILEMCP_DISABLE_TELEMETRY: '1' } });
    let size = 0, chunks = [], failure, forceTimer;
    const stop = code => {
      failure ??= new PluginError(code); child.kill('SIGTERM');
      forceTimer ??= setTimeout(() => child.kill('SIGKILL'), 1000);
    };
    const timer = setTimeout(() => stop('backendTimeout'), timeout);
    const abort = () => stop('cancelled');
    signal?.addEventListener('abort', abort, { once: true });
    if (signal?.aborted) abort();
    child.stdout.on('data', b => {
      size += b.length;
      if (size > maxBytes) stop('backendOutputLimit'); else chunks.push(b);
    });
    child.stderr.on('data', () => {});
    child.once('error', () => { failure ??= new PluginError('backendUnavailable'); });
    child.once('close', code => {
      clearTimeout(timer); signal?.removeEventListener('abort', abort);
      clearTimeout(forceTimer);
      if (failure) reject(failure);
      else if (code !== 0) reject(new PluginError('backendFailed'));
      else resolve(Buffer.concat(chunks).toString('utf8'));
    });
  });
}

export function decode(text) {
  try { return JSON.parse(text); } catch { throw new PluginError('invalidBackendResponse'); }
}
