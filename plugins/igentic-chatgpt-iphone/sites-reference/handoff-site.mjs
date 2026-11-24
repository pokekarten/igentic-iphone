// Stateless read-only capability discovery and manual links for an owner-private Site.
// No iPhone connection, shortcut execution, Apple permissions, or task writes.
import { HANDOFF_ACTIONS, prepareChatGPTHandoff } from '../../iphone-connect/src/chatgpt-handoff.mjs';

const EMPTY_INPUT = Object.freeze({
  type: 'object', additionalProperties: false, properties: {}, required: []
});
const READ_ONLY = Object.freeze({
  readOnlyHint: true, destructiveHint: false, openWorldHint: false
});

export const SITES_HANDOFF_TOOL = Object.freeze({
  name: 'iphone_chatgpt_handoff',
  title: 'Prepare a manual link to iGentic on iPhone',
  description: 'Read-only manual navigation to the signed first-party iGentic app. The owner must open the link and confirm navigation inside the app. No device status or action execution is available.',
  inputSchema: Object.freeze({
    type: 'object', additionalProperties: false,
    properties: { action: { type: 'string', enum: [...HANDOFF_ACTIONS] } },
    required: ['action']
  }),
  annotations: READ_ONLY
});

export const SITES_CAPABILITY_TOOL = Object.freeze({
  name: 'igentic_get_capabilities',
  title: 'Discover safe iGentic capabilities',
  description: 'Static, read-only capabilities and limitations; does not check if an iPhone is connected, or grant device access.',
  inputSchema: EMPTY_INPUT,
  annotations: READ_ONLY
});

export const SITES_SHORTCUTS_TOOL = Object.freeze({
  name: 'igentic_shortcuts_setup',
  title: 'Prepare the API-free iGentic ChatGPT Shortcut',
  description: 'Owner-facing iOS Shortcuts setup steps for a manual ChatGPT model-response loop. Instructions only, no Shortcut installed or invoked.',
  inputSchema: EMPTY_INPUT,
  annotations: READ_ONLY
});

export const SITES_TOOLS = Object.freeze([
  SITES_HANDOFF_TOOL, SITES_CAPABILITY_TOOL, SITES_SHORTCUTS_TOOL
]);

const exactEmptyObject = args =>
  args !== null && typeof args === 'object' && !Array.isArray(args)
  && Object.keys(args).length === 0;

export function callSitesHandoffTool(name, args) {
  if (name !== SITES_HANDOFF_TOOL.name
      || !args || typeof args !== 'object' || Array.isArray(args)
      || Object.keys(args).length !== 1 || !Object.hasOwn(args, 'action'))
    throw new TypeError('unsupportedSiteToolCall');
  // NEVER interpolate the model's input into a URL.
  return prepareChatGPTHandoff(args.action);
}

export function callSitesTool(name, args) {
  if (name === SITES_HANDOFF_TOOL.name)
    return callSitesHandoffTool(name, args);
  if (!exactEmptyObject(args))
    throw new TypeError('unsupportedSiteToolCall');
  if (name === SITES_CAPABILITY_TOOL.name) {
    return {
      schema: 1, status: 'static-documentation-only',
      iPhoneConnected: 'not-checked', actionExecuted: false,
      capabilities: [
        { name: 'manual-own-app-handoff', supportedByThisSite: true,
          requiresOwnerTap: true, actions: [...HANDOFF_ACTIONS],
          limitation: 'navigation-only-no-device-receipt' },
        { name: 'api-free-shortcuts-model-loop', supportedByThisSite: false,
          requiresOwnerSetup: true, limitation: 'separate-signed-app-and-Shortcuts-acceptance-required' },
        { name: 'mac-coredevice-own-app', supportedByThisSite: false,
          limitation: 'separate-local-transport-not-connected-to-this-Site' }
      ]
    };
  }
  if (name === SITES_SHORTCUTS_TOOL.name) {
    return {
      schema: 1, status: 'owner-manual-setup-instructions',
      actionExecuted: false, shortcutCreated: false, iPhoneConnected: 'not-checked',
      shortcutName: 'iGentic KI Loop', requiresSignedIPhoneApp: true,
      requiresOwnerSetup: true, requiresChatGPTExtension: true,
      steps: [
        'Starte iGentic KI-Auftrags-ID lesen und speichere die unveränderte Auftrags-ID als Kurzbefehle-Variable.',
        'Lies iGentic KI-Prompt aus dem lokal vorbereiteten iGentic-Auftrag.',
        'Nutze in Apple Kurzbefehle die ChatGPT-Aktion Modell verwenden mit der Prompt-Variable.',
        'Übergib Modellantwort und unveränderte Auftrags-ID an iGentic KI-Antwort übernehmen.',
        'Öffne iGentic Diagnose und prüfe KI-Antwort prüfen vor jedem weiteren Schritt.'
      ],
      projectChat: {
        availableFromThisSite: false,
        shortcutProjectContext: 'not-verified',
        requiresSeparateUserConfirmation: true,
        note: 'ChatGPT Modell verwenden in Kurzbefehle ist nicht automatisch ein Chat im gewünschten ChatGPT-Projekt. Projektwahl, Kontextübernahme und Rückgabe müssen separat auf dem iPhone nachgewiesen werden.'
      },
      warning: 'A model response is untrusted text. No device action, approval, or ChatGPT-to-Site callback is performed.'
    };
  }
  throw new TypeError('unsupportedSiteToolCall');
}
