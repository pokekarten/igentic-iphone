import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { HANDOFF_ACTIONS, prepareChatGPTHandoff, verifyChatGPTHandoffPreviewReceipt } from '../src/chatgpt-handoff.mjs';

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


test('ChatGPT handoff routes stay aligned with the signed iOS target', () => {
  // Catch an app/server mismatch without needing a Mac, simulator or iPhone.
  // The UI must still require a second explicit owner choice after openURL.
  const swift = readFileSync(new URL('../../../ios/Sources/iGenticApp/ChatGPTHandoffRoute.swift', import.meta.url), 'utf8');
  const plist = readFileSync(new URL('../../../app/iGenticDiagnostics/iGenticDiagnostics/Info.plist', import.meta.url), 'utf8');
  const view = readFileSync(new URL('../../../ios/Sources/iGenticApp/DiagnosticView.swift', import.meta.url), 'utf8');

  const swiftActions = [...swift.matchAll(/^\s*case\s+(\w+)(?:\s*=\s*"([^"]+)")?/gm)]
    .map(match => match[2] ?? match[1]);
  assert.deepEqual(swiftActions.sort(), [...HANDOFF_ACTIONS].sort());
  assert.match(plist, /<key>CFBundleURLSchemes<\/key>[\s\S]*?<string>igentic<\/string>/);
  assert.match(view, /\.onOpenURL\s*\{\s*url\s+in[\s\S]*?ChatGPTHandoffRoute\.parse\(url\)/);
  assert.match(view, /\.sheet\(item:\s*\$chatGPTHandoff\)/);
});


test('physical preview receipt proves only a fresh allowlisted own-app sheet, not authorization', () => {
  const first = Object.freeze({
    schema: 1, eventID: 'c13b1b76-1000-4000-8000-123456789abc',
    route: 'diagnostics', view: 'handoff-preview', status: 'observed'
  });
  const next = Object.freeze({
    ...first, eventID: 'c13b1b76-1000-4000-8000-abcdef123456', route: 'discovery'
  });
  const firstID = verifyChatGPTHandoffPreviewReceipt(first, 'diagnostics');
  assert.equal(verifyChatGPTHandoffPreviewReceipt(next, 'discovery', firstID), next.eventID);
  const invalid = [
    { ...next, eventID: firstID }, // stale
    { ...next, schema: 2 },
    { ...next, view: 'permissions' },
    { ...next, status: 'approved' },
    { ...next, title: 'sensitive data' },
    { ...next, privateContent: 'secret' },
    { ...next, eventID: '0'.repeat(36) },
    { ...next, eventID: 'C13B1B76-1000-4000-8000-ABCDEF123456' },
    { ...next, route: 'delete-contacts' },
    null, [], 'untrusted'
  ];
  for (const value of invalid) {
    assert.throws(
      () => verifyChatGPTHandoffPreviewReceipt(value, 'discovery', firstID),
      /handoffReceiptInvalid/
    );
  }
  assert.throws(() => verifyChatGPTHandoffPreviewReceipt(next, 'delete-contacts'), /handoffReceiptInvalid/);
});
