import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setTimeout } from 'node:timers/promises';
import { PhoneService } from '../src/service.mjs';
import { FixtureBackend } from '../src/backend.mjs';

test('idle session expires and releases the cross-process lease without another request', async t => {
  const stateDir = await mkdtemp(join(tmpdir(), 'igentic-expiry-'));
  const service = new PhoneService({ backend: new FixtureBackend(), stateDir, sessionMs: 20 });
  t.after(async () => { await service.close(); await rm(stateDir, { recursive: true, force: true }); });
  const s = await service.start('iphone-1');
  await setTimeout(80);
  assert.throws(() => service.session(s.sessionId), /invalidSession/);
  await assert.rejects(readFile(join(stateDir, 'device.lease')), e => e.code === 'ENOENT');
});
