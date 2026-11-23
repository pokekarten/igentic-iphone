import test from 'node:test';
import assert from 'node:assert/strict';
import { HANDOFF_ACTIONS, prepareChatGPTHandoff } from '../src/chatgpt-handoff.mjs';
import { validatePublishedHandoffEvidence } from '../src/published-handoff-evidence.mjs';

const sample = () => HANDOFF_ACTIONS.map(action => ({
  structuredContent: { data: prepareChatGPTHandoff(action) }
}));

test('published plugin handoffs must match each canonical manual-only action', () => {
  const accepted = validatePublishedHandoffEvidence(sample());
  assert.deepEqual(accepted, HANDOFF_ACTIONS.map(action => ({
    action, launchUrl: 'igentic://handoff/v1/' + action
  })));
});

test('published result cannot silently upgrade navigation to device control', () => {
  for (const changed of [
    { actionExecuted: true }, { iPhoneConnected: true },
    { requiresOwnerTap: false }, { authorization: 'remote-control' },
    { dataSentToIPhone: 'device-details' }, { requiresInstalledSignedApp: false },
    { launchUrl: 'shortcuts://run-shortcut?name=anything' },
    { launchUrl: 'igentic://handoff/v1/diagnostics?payload=private' },
    { status: 'executed' }, { extra: 'unexpected' }
  ]) {
    const results = sample();
    Object.assign(results[0].structuredContent.data, changed);
    assert.throws(() => validatePublishedHandoffEvidence(results),
      /publishedHandoffEvidenceInvalid/);
  }
  const reordered = sample().reverse();
  assert.throws(() => validatePublishedHandoffEvidence(reordered), /publishedHandoffEvidenceInvalid/);
  const missing = sample().slice(1);
  assert.throws(() => validatePublishedHandoffEvidence(missing), /publishedHandoffEvidenceInvalid/);
  assert.throws(() => validatePublishedHandoffEvidence([{ isError: true }]),
    /publishedHandoffEvidenceInvalid/);
});
