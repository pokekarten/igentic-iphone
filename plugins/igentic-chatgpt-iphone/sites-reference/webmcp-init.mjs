import { registerReadOnlyBrowserHandoff } from './webmcp-site.mjs';

// For optional HTTPS browser previews. Does not create a ChatGPT plugin,
// publish a Site or start a phone transport.
const message = document.getElementById('webmcp-status');
const registration = await registerReadOnlyBrowserHandoff(document);
if (message) message.textContent = registration.available
  ? 'WebMCP-Werkzeug bereit. Es erzeugt nur manuelle iGentic-Links.'
  : 'WebMCP nicht verfügbar. Die drei manuellen Links funktionieren weiterhin.';
window.addEventListener('pagehide', () => registration.close(), { once: true });
