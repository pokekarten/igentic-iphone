import { App } from '@modelcontextprotocol/ext-apps';

const app = new App({ name: 'iGentic iPhone Connect', version: '0.1.0' }, {});
const status = document.querySelector('#status');
let sessionId;
function render(result) {
  if (result.isError) { status.textContent = result.content?.[0]?.text ?? 'Request failed'; return; }
  const d = result.structuredContent?.data ?? {};
  sessionId = d.sessionId ?? sessionId;
  // A configured physical backend is not evidence of a reachable phone.
  // Only a real sanitized observation can justify an observed-state label.
  const mode = d.backend === 'fixture' ? 'Synthetic test device'
    : d.backend === 'physical' ? (Array.isArray(d.markers) ? 'iPhone diagnostics observed' : 'iPhone connection not verified')
      : 'iGentic diagnostics status';
  status.textContent = d.stopped ? 'Session stopped' : `${mode} · ${d.status ?? d.mode ?? 'Availability unknown'}`;
  document.querySelector('#details').textContent = d.markers?.join(' · ')
    ?? 'Diagnostics and bundled discovery only. No personal app content is shared.';
  document.querySelector('#stop').disabled = !sessionId || d.stopped === true;
  document.querySelector('#observe').disabled = !sessionId || d.stopped === true;
}
app.ontoolresult = render;
app.ontoolinput = p => { sessionId = p.arguments?.sessionId ?? sessionId; };
app.ontoolcancelled = () => { status.textContent = 'Request cancelled'; };
for (const [button, tool] of [['#observe', 'iphone_observe'], ['#stop', 'iphone_stop_session']]) {
  document.querySelector(button).addEventListener('click', async () => {
    if (!sessionId) return;
    try { render(await app.callServerTool({ name: tool, arguments: { sessionId } })); }
    catch { status.textContent = 'Connection unavailable'; }
  });
}
app.connect().catch(() => { status.textContent = 'Open this card in a compatible MCP Apps host.'; });
