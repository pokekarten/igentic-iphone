// First-party, offline-safe capability directory and manual handoff.
// This file deliberately does not import, spawn, probe, or install any provider.
const OPTIONAL = Object.freeze([
  ['chatgpt', 'MCP client', 'native-ios-or-any-mcp-client'],
  ['fieldglass', 'native OCR and workspace UI', 'igentic-offline-tools'],
  ['mobilecli', 'legacy device automation', 'apple-coredevice-own-app-only'],
  ['pymobiledevice3', 'alternative Apple device diagnostics', 'apple-coredevice-own-app-only'],
  ['libimobiledevice', 'alternative Apple device diagnostics', 'apple-coredevice-own-app-only'],
  ['tailscale', 'private network reachability', 'on-device-or-usb-wifi'],
  ['remote-desktop', 'Mac desktop operations', 'on-device-manual-actions'],
  ['playwright-xctest', 'development test automation', 'on-device-manual-actions'],
  ['mlx-swift-lm', 'optional local open-weight inference', 'manual-or-platform-model'],
  ['llama-cpp', 'optional local open-weight inference', 'manual-or-platform-model'],
  ['apple-foundation-models', 'optional local model proposals', 'manual-reminder-draft']
]);
export function optionalToolCatalog() {
  return {
    schema: 1,
    policy: 'all-optional-no-implicit-provider-fallback',
    offlineCore: [
      { id: 'diagnostics', implemented: 'native-ios-app', entry: 'iGentic Diagnostics', noMacRequired: true },
      { id: 'discovery', implemented: 'native-ios-app', entry: 'Open local discovery', noMacRequired: true },
      { id: 'text-draft', implemented: 'native-ios-app', entry: 'Offline-Werkzeuge', noMacRequired: true },
      { id: 'workspace-note', implemented: 'native-ios-app-owner-confirmation', entry: 'Offline-Werkzeuge > Notizen lokal verwalten', noMacRequired: true },
      { id: 'speak-text', implemented: 'native-ios-app', entry: 'Offline-Werkzeuge', noMacRequired: true },
      { id: 'read-image-text', implemented: 'native-ios-app', entry: 'Offline-Werkzeuge', noMacRequired: true },
      { id: 'reminder', implemented: 'native-ios-app-owner-approval', entry: 'Erinnerung erstellen', noMacRequired: true },
      { id: 'task-handoff', implemented: 'mcp-pure-offline', entry: 'iphone_prepare_local_task', noMacRequired: true }
    ],
    optionalProviders: OPTIONAL.map(([id, purpose, firstPartyFallback]) =>
      ({ id, purpose, firstPartyFallback, installed: 'not-checked', enabled: 'not-checked' })),
    networkNotRequiredFor: ['offline-native-editor', 'ios-speech', 'ios-vision-ocr', 'manual-reminder-draft'],
    physicalControl: 'only-allowlisted-own-app-with-fresh-coredevice-evidence',
    limits: ['no-arbitrary-ios-shell', 'no-cross-app-taps', 'no-background-device-control',
      'no-provider-is-assumed-installed', 'no-automatic-action-replay']
  };
}

const TASKS = Object.freeze({
  diagnostics: { entry: 'iGentic Diagnostics', steps: [
    'Open the signed iGentic app on the iPhone.',
    'Review the built-in Diagnostics screen. No Mac or MCP connection is needed.' ] },
  discovery: { entry: 'iGentic Diagnostics > Open local discovery', steps: [
    'Open the signed iGentic app and choose Open local discovery.',
    'The bundled discovery content is available without a network connection.' ] },
  'workspace-note': { entry: 'iGentic Diagnostics > Offline-Werkzeuge > Notizen lokal verwalten', steps: [
    'Open the signed iGentic app and select Notizen lokal verwalten.',
    'Enter an ASCII note name and draft; tap Änderung prüfen to inspect both versions.',
    'Only an explicit tap on Diese Version lokal speichern writes into the app sandbox. MCP does not read or write notes.' ] },
  'text-draft': { entry: 'iGentic Diagnostics > Offline-Werkzeuge', steps: [
    'Open Offline-Werkzeuge, enter or paste text locally.',
    'Copy it only if you choose the explicit copy button. No remote write is performed.' ] },
  'speak-text': { entry: 'iGentic Diagnostics > Offline-Werkzeuge', steps: [
    'Open Offline-Werkzeuge, enter or paste text.',
    'Tap Vorlesen. The iOS speech synthesizer runs on the device.' ] },
  'read-image-text': { entry: 'iGentic Diagnostics > Offline-Werkzeuge', steps: [
    'Open Offline-Werkzeuge and select one image with the system photo picker.',
    'Tap/copy the recognized text only if you want to share it. OCR runs in native Vision.' ] },
  reminder: { entry: 'iGentic Diagnostics > Erinnerung erstellen', steps: [
    'Open Erinnerung erstellen and enter a title and due date manually.',
    'Review the destination, iOS permission and approval before any reminder is written.' ] }
});
export function prepareLocalTask(task, text = '') {
  if (!Object.hasOwn(TASKS, task) || typeof text !== 'string')
    throw new TypeError('invalidOfflineTask');
  if (text.length > 800 || Buffer.byteLength(text, 'utf8') > 1600 ||
      /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/u.test(text))
    throw new TypeError('invalidOfflineText');
  if (text.trim() && !['text-draft', 'speak-text', 'reminder'].includes(task))
    throw new TypeError('textNotSupportedForTask');
  const item = TASKS[task];
  return {
    schema: 1, task, status: 'manual-handoff-only',
    entry: item.entry, steps: [...item.steps],
    deviceActionExecuted: false, appInstalled: 'not-checked',
    providerRequired: false, macRequired: false, networkRequired: false,
    approval: task === 'reminder' ? 'explicit-on-device-before-write' : 'user-action-on-device',
    ...(text.trim() ? { copyableDraft: text } : {}),
    privacy: 'Only caller-supplied text is returned. Nothing is sent to or read from an iPhone.'
  };
}
