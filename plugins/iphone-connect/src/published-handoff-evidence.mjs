import { isDeepStrictEqual } from 'node:util';
import { HANDOFF_ACTIONS, prepareChatGPTHandoff } from './chatgpt-handoff.mjs';

// A test adapter, NOT authorization: the caller supplies the actual ChatGPT
// plugin's three tool outputs. The Mac cannot independently attest their source.
// Reject arbitrary URLs, hidden arguments, mismatched status or new actions.
export function validatePublishedHandoffEvidence(results) {
  if (!Array.isArray(results) || results.length !== HANDOFF_ACTIONS.length)
    throw new TypeError('publishedHandoffEvidenceInvalid');
  return HANDOFF_ACTIONS.map((action, index) => {
    const wrapper = results[index];
    const data = wrapper?.structuredContent?.data;
    if (!isDeepStrictEqual(data, prepareChatGPTHandoff(action))
        || wrapper?.isError === true)
      throw new TypeError('publishedHandoffEvidenceInvalid');
    return { action, launchUrl: data.launchUrl };
  });
}
