import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { HANDOFF_ACTIONS, prepareChatGPTHandoff } from '../src/chatgpt-handoff.mjs';
import { SITES_HANDOFF_TOOL, callSitesHandoffTool } from '../../igentic-chatgpt-iphone/sites-reference/handoff-site.mjs';

test('Sites tool uses the canonical read-only handoff contract', () => {
  assert.equal(SITES_HANDOFF_TOOL.name, 'iphone_chatgpt_handoff');
  assert.equal(SITES_HANDOFF_TOOL.annotations.readOnlyHint, true);
  assert.equal(SITES_HANDOFF_TOOL.annotations.destructiveHint, false);
  assert.equal(SITES_HANDOFF_TOOL.inputSchema.additionalProperties, false);
  assert.deepEqual(SITES_HANDOFF_TOOL.inputSchema.required, ['action']);
  assert.deepEqual(SITES_HANDOFF_TOOL.inputSchema.properties.action.enum, HANDOFF_ACTIONS);
  for (const action of HANDOFF_ACTIONS) {
    const output = callSitesHandoffTool(SITES_HANDOFF_TOOL.name, { action });
    assert.deepEqual(output, prepareChatGPTHandoff(action));
    assert.equal(output.actionExecuted, false);
    assert.equal(output.requiresOwnerTap, true);
    assert.equal(output.iPhoneConnected, 'not-checked');
    assert.equal(output.dataSentToIPhone, 'none');
  }
});

test('Sites tool rejects invalid actions, arbitrary URLs, extra properties and write tools', () => {
  for (const args of [
    null, [], {}, { action: 'diagnostics', approved: true },
    { action: 'discovery', text: 'private text' },
    { action: 'settings' }, { action: 'diagnostics?approved=true' },
    { action: 'shortcuts://run-shortcut' },
    { action: '' }, { action: 1 }, { action: null }
  ]) assert.throws(() => callSitesHandoffTool('iphone_chatgpt_handoff', args));
  assert.throws(() => callSitesHandoffTool('iphone_execute_action', { action: 'diagnostics' }));
});

test('Sites page advertises only own-app links without network or script access', () => {
  const html = readFileSync(new URL('../../igentic-chatgpt-iphone/sites-reference/index.html',
    import.meta.url), 'utf8');
  const hrefs = [...html.matchAll(/href="([^"]+)"/g)].map(x => x[1]);
  assert.deepEqual(hrefs.sort(), [...HANDOFF_ACTIONS.map(a => 'igentic://handoff/v1/' + a), '/console'].sort());
  for (const element of ['<script', '<form', '<iframe', '<img', '<link'])
    assert.equal(html.toLowerCase().includes(element), false);
  assert.ok(html.includes("connect-src 'none'"));
  assert.ok(html.includes('zweite manuelle Auswahl'));
});

test('skills-only fallback never pretends MCP device connectivity', () => {
  const skill = readFileSync(new URL('../../igentic-chatgpt-iphone/skills/igentic-chatgpt-iphone/SKILL.md',
    import.meta.url), 'utf8');
  assert.ok(skill.includes('no tool was called'));
  assert.ok(skill.includes('no device connection was checked'));
  assert.ok(skill.includes('optional manual navigation link'));
  for (const action of HANDOFF_ACTIONS)
    assert.ok(skill.includes('igentic://handoff/v1/' + action));
  assert.ok(skill.includes('Neither path automatically'));
});
