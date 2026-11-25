// ChatGPT-facing, read-only handoff contract. No phone access or action execution.
export const HANDOFF_ACTIONS = Object.freeze(['diagnostics', 'discovery', 'reminder-draft']);

export function prepareChatGPTHandoff(action) {
  if (typeof action !== 'string' || !HANDOFF_ACTIONS.includes(action))
    throw new TypeError('unsupportedHandoffAction');
  // Only these constant strings ever become URLs; no user text, ids or secrets.
  const launchUrl = 'igentic://handoff/v1/' + action;
  return {
    schema: 1,
    action,
    status: 'manual-iphone-handoff',
    launchUrl,
    supportedIPhoneTarget: 'igentic-own-app-only',
    actionExecuted: false,
    iPhoneConnected: 'not-checked',
    requiresOwnerTap: true,
    requiresInstalledSignedApp: true,
    macRequiredForIPhoneStep: false,
    dataSentToIPhone: 'none',
    authorization: 'link-is-navigation-only-not-permission',
    nextStep: 'Open this link on the iPhone and choose an in-app destination yourself.',
    note: 'No App Intent is executed remotely. Reminder creation needs a separate in-app review and approval.'
  };
}


// Compare two app-owned sheet observations. This is neither authorization nor
// permission; it is a fixed, sanitized UI appearance proof. Never return an ID
// or arbitrary body through a ChatGPT tool.
export function verifyChatGPTHandoffPreviewReceipt(value, route, previousEventID = null) {
  if (!value || typeof value !== 'object' || Array.isArray(value)
      || !HANDOFF_ACTIONS.includes(route)) throw new TypeError('handoffReceiptInvalid');
  if (Object.keys(value).sort().join('|') !== 'eventID|route|schema|status|view'
      || value.schema !== 1 || value.route !== route
      || value.view !== 'handoff-preview' || value.status !== 'observed'
      || typeof value.eventID !== 'string'
      || !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value.eventID)
      || value.eventID === previousEventID) throw new TypeError('handoffReceiptInvalid');
  return value.eventID; // local comparison only, never log or expose via MCP
}
