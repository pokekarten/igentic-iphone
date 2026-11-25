import test from 'node:test';
import assert from 'node:assert/strict';
import { optionalToolCatalog, prepareLocalTask } from '../src/optional-core.mjs';

test('provider tools are never mandatory or claimed installed', () => {
  const catalog = optionalToolCatalog();
  assert.equal(catalog.policy, 'all-optional-no-implicit-provider-fallback');
  for (const id of ['chatgpt', 'fieldglass', 'mobilecli', 'pymobiledevice3',
    'libimobiledevice', 'tailscale', 'remote-desktop', 'playwright-xctest',
    'mlx-swift-lm', 'llama-cpp', 'apple-foundation-models']) {
    const provider = catalog.optionalProviders.find(p => p.id === id);
    assert.ok(provider, id);
    assert.equal(provider.installed, 'not-checked');
    assert.equal(provider.enabled, 'not-checked');
    assert.ok(provider.firstPartyFallback);
  }
  assert.ok(catalog.offlineCore.every(x => x.noMacRequired));
  assert.equal(JSON.stringify(catalog).includes('connected":true'), false);
});

test('every local task plans a manual on-device action, never execution', () => {
  for (const task of ['diagnostics', 'discovery', 'text-draft',
    'speak-text', 'read-image-text', 'reminder']) {
    const plan = prepareLocalTask(task);
    assert.equal(plan.task, task);
    assert.equal(plan.status, 'manual-handoff-only');
    assert.equal(plan.deviceActionExecuted, false);
    assert.equal(plan.providerRequired, false);
    assert.equal(plan.networkRequired, false);
    assert.equal(plan.macRequired, false);
    assert.equal(plan.appInstalled, 'not-checked');
    assert.ok(plan.steps.length > 0);
  }
});

test('text is opt-in, stays copyable and never goes in an executable URL', () => {
  const draft = prepareLocalTask('text-draft', 'Notiz für heute');
  assert.equal(draft.copyableDraft, 'Notiz für heute');
  assert.equal(draft.deviceActionExecuted, false);
  assert.equal(JSON.stringify(draft).includes('://'), false);
  const reminder = prepareLocalTask('reminder', 'Morgen Milch holen');
  assert.equal(reminder.approval, 'explicit-on-device-before-write');
  assert.equal(reminder.copyableDraft, 'Morgen Milch holen');
  assert.ok(!Object.hasOwn(prepareLocalTask('diagnostics'), 'copyableDraft'));
});

test('reject invalid task, text on unsupported tasks, and control or oversized text', () => {
  assert.throws(() => prepareLocalTask('arbitrary-shell', 'pwd'), /invalidOfflineTask/);
  assert.throws(() => prepareLocalTask('diagnostics', 'private text'), /textNotSupportedForTask/);
  assert.throws(() => prepareLocalTask('text-draft', '\u0000secret'), /invalidOfflineText/);
  assert.throws(() => prepareLocalTask('speak-text', 'x'.repeat(801)), /invalidOfflineText/);
  assert.throws(() => prepareLocalTask('speak-text', '😸'.repeat(500)), /invalidOfflineText/);
});
