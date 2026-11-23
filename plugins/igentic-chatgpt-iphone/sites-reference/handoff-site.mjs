// Portable MCP tool contract for a future owner-created ChatGPT Site.
// This source is a REFERENCE only: committing it does not create or publish
// a ChatGPT Site, install a plugin, connect an account, or contact a phone.
import { HANDOFF_ACTIONS, prepareChatGPTHandoff } from '../../iphone-connect/src/chatgpt-handoff.mjs';

export const SITES_HANDOFF_TOOL = Object.freeze({
  name: 'iphone_chatgpt_handoff',
  title: 'Prepare a manual link to iGentic on iPhone',
  description: 'Read-only manual navigation to the signed first-party iGentic app. The owner must open the link and confirm navigation inside the app. No device status or action execution is available.',
  inputSchema: Object.freeze({
    type: 'object', additionalProperties: false,
    properties: { action: { type: 'string', enum: [...HANDOFF_ACTIONS] } },
    required: ['action']
  }),
  annotations: Object.freeze({
    readOnlyHint: true, destructiveHint: false, openWorldHint: false
  })
});

export function callSitesHandoffTool(name, args) {
  if (name !== SITES_HANDOFF_TOOL.name
      || !args || typeof args !== 'object' || Array.isArray(args)
      || Object.keys(args).length !== 1 || !Object.hasOwn(args, 'action'))
    throw new TypeError('unsupportedSiteToolCall');
  // Reuse the canonical API contract; NEVER interpolate user text into URLs.
  return prepareChatGPTHandoff(args.action);
}
