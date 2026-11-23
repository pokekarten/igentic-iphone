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
