import test from 'node:test';
import assert from 'node:assert/strict';
import { HANDOFF_ACTIONS, prepareChatGPTHandoff } from '../src/chatgpt-handoff.mjs';

test('ChatGPT generates only fixed user-tapped own-app handoffs', () => {
  assert.deepEqual(HANDOFF_ACTIONS, ['diagnostics', 'discovery', 'reminder-draft']);
  for (const action of HANDOFF_ACTIONS) {
    const result = prepareChatGPTHandoff(action);
    assert.equal(result.launchUrl, 'igentic://handoff/v1/' + action);
    assert.equal(result.actionExecuted, false);
    assert.equal(result.requiresOwnerTap, true);
    assert.equal(result.dataSentToIPhone, 'none');
    assert.equal(result.iPhoneConnected, 'not-checked');
    assert.equal(result.authorization, 'link-is-navigation-only-not-permission');
    assert.doesNotMatch(JSON.stringify(result), /token|password|serial|udid|authsecret/i);
  }
});

test('ChatGPT cannot inject URLs, arbitrary iOS commands or private payloads', () => {
  for (const value of [
    'delete-contacts', 'open-settings', 'run-shortcut', 'diagnostics?token=secret',
    'discovery#execute', 'reminder-draft/../../shell', 'shortcuts://run-shortcut',
    '', 'DIAGNOSTICS', null, undefined, 1, { action: 'diagnostics' }
  ]) assert.throws(() => prepareChatGPTHandoff(value), /unsupportedHandoffAction/);
});
