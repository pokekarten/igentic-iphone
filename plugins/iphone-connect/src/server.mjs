import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { readFile, access } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join, dirname } from 'node:path';
import { homedir } from 'node:os';
import { PhoneService } from './service.mjs';
import { MobileBackend, FixtureBackend, loadConfig } from './backend.mjs';
import { NativeCoreDeviceBackend } from './native-coredevice.mjs';
import { PluginError } from './process.mjs';
import { optionalToolCatalog, prepareLocalTask } from './optional-core.mjs';

export const ROOT = dirname(dirname(fileURLToPath(import.meta.url)));
export const UI_URI = 'ui://igentic/iphone-dashboard.html';
const id = z.string().uuid();
const session = { sessionId: id };
const payload = z.object({ data: z.record(z.string(), z.unknown()) });
const hints = readOnly => ({ readOnlyHint: readOnly, destructiveHint: false, openWorldHint: false });

export function createServer(service) {
  const server = new McpServer({ name: 'igentic-iphone-connect', version: '0.1.0' }, {
    instructions: 'Use fixed diagnostics tools only. List devices, start a short session, open Diagnostics, observe, prepare a supported navigation, execute once, read result and stop. Fixture results are not physical-device evidence. Never replay unknownOutcome. No personal data, screenshots, reminder writes or arbitrary app control are available.'
  });
  const add = (name, title, description, shape, readOnly, fn, ui = false) => {
    server.registerTool(name, { title, description, inputSchema: z.object(shape).strict(),
      outputSchema: payload, annotations: hints(readOnly),
      ...(ui ? { _meta: { ui: { resourceUri: UI_URI } } } : {})
    }, async (args, extra) => {
      const abort = () => { if (args.sessionId) void service.stop(args.sessionId).catch(() => {}); };
      extra.signal?.addEventListener('abort', abort, { once: true });
      try {
        if (extra.signal?.aborted) throw new PluginError('cancelled');
        const data = await fn(args);
        return { structuredContent: { data }, content: [{ type: 'text', text: JSON.stringify(data) }] };
      } catch (e) {
        // Only fixed internal error codes cross the tool boundary.
        const code = e instanceof PluginError ? e.code : 'internalError';
        return { isError: true, content: [{ type: 'text', text: code }] };
      } finally { extra.signal?.removeEventListener('abort', abort); }
    });
  };
  add('iphone_list_devices', 'List authorized iPhones',
    'Use this to find the configured iPhone alias and connection availability. No personal device identifiers or installed app list.',
    {}, true, () => service.list());
  add('iphone_native_app_status', 'Check our iGentic app over Apple CoreDevice',
    'Read-only first-party status for the allowlisted Diagnostics app: installed and process running. Does not inspect private app content or prove foreground/UI state.',
    {}, true, () => service.nativeAppStatus());

  add('iphone_connection_report', 'Check USB, Wi-Fi and other connection paths',
    'Read-only live CoreDevice status and five separately scoped route states. No device identifiers, network scan or iPhone actions. A detected tunnel is not proof of app-owned receipt or optional legacy driver readiness.',
    {}, true, () => service.connectionReport());
  add('iphone_get_capabilities', 'Get iPhone capabilities',
    'Use this to check actual supported actions and limitations. Configuration is not observed device readiness.',
    {}, true, () => service.capabilities());
  add('iphone_tool_catalog', 'List first-party and optional tools',
    'Offline first-party capabilities and optional provider equivalents. Installed or connected third-party tools are never inferred.',
    {}, true, () => optionalToolCatalog());
  add('iphone_prepare_local_task', 'Prepare a Mac-free iPhone task',
    'Make a manual, non-executing handoff for on-device diagnostics, discovery, draft, speech, selected-image OCR or reminder. No iPhone connection or external provider needed.',
    { task: z.enum(['diagnostics', 'discovery', 'text-draft', 'speak-text', 'read-image-text', 'reminder']),
      text: z.string().max(800).optional() }, true,
    a => prepareLocalTask(a.task, a.text));
  add('iphone_start_session', 'Start diagnostic session',
    'Use this for a requested iGentic diagnostic task. Acquires a 5-minute exclusive local-device lease; does not capture the screen.',
    { device: z.literal('iphone-1') }, false, a => service.start(a.device));
  add('iphone_native_launch_app', 'Launch only our iGentic app via Apple CoreDevice',
    'Owner-requested, policy-gated first-party launch of the configured iGentic Diagnostics app. Independently verifies only that its process runs; foreground and view navigation remain unverified. Requires an exclusive session.',
    session, false, a => service.nativeLaunch(a.sessionId));
  add('iphone_open_diagnostics', 'Open iGentic Diagnostics',
    'Launch only the configured iGentic Diagnostics app and verify fixed own-app view receipt or optional legacy UI. Foreground application changes.',
    session, false, a => service.open(a.sessionId));
  add('iphone_observe', 'Observe diagnostic state',
    'Read only fixed own-app marker states from its view receipt or optional legacy UI. No raw text, screenshots, coordinates or private data returned. Refreshes session observation state.',
    session, false, a => service.observe(a.sessionId));
  add('iphone_prepare_action', 'Prepare safe navigation',
    'Prepare one immutable open-discovery navigation from a fresh observation. Changes local proposal state; does not tap the phone.',
    { ...session, observationId: id, action: z.literal('open-discovery') }, false,
    a => service.prepare(a.sessionId, a.observationId, a.action));
  add('iphone_execute_action', 'Execute prepared navigation once',
    'Consume the exact proposal once and open bundled discovery in our app after checking fresh foreground state. No persistent user-data writes. Unknown outcome must not be replayed.',
    { ...session, proposalId: id }, false, a => service.execute(a.sessionId, a.proposalId));
  add('iphone_get_action_result', 'Get verified action result',
    'Read a prior action receipt for this session. Verified means an independent post-action observation matched; unknownOutcome is not success.',
    { ...session, proposalId: id }, true, a => service.result(a.sessionId, a.proposalId));
  add('iphone_stop_session', 'Stop iPhone session',
    'Cancel pending requests and release the device lease when execution has stopped. Does not undo already-dispatched actions.',
    session, false, a => service.stop(a.sessionId));
  add('iphone_show_dashboard', 'Show iPhone dashboard',
    'Display device capabilities and optional active session in an interactive card. Does not capture the screen.',
    { sessionId: id.optional() }, true, a => ({ ...service.capabilities(),
      ...(a.sessionId ? { sessionId: service.session(a.sessionId).id } : {}) }), true);
  server.registerResource('iphone-dashboard', UI_URI, {}, async () => ({ contents: [{ uri: UI_URI,
    mimeType: 'text/html;profile=mcp-app', text: await readFile(join(ROOT, 'ui/dashboard.html'), 'utf8'),
    _meta: { ui: { prefersBorder: true, csp: { connectDomains: [], resourceDomains: [] } } }
  }] }));
  return server;
}

export async function main() {
  const mode = process.env.IGENTIC_IPHONE_BACKEND ?? 'physical';
  if (!['fixture', 'physical'].includes(mode)) throw new PluginError('unknownBackend');
  let configPath = process.env.IGENTIC_IPHONE_CONFIG;
  if (!configPath) {
    const path = join(homedir(), 'Library/Application Support/iGentic/iphone-connect/config.json');
    try { await access(path); configPath = path; } catch {}
  }
  const config = mode === 'physical' ? await loadConfig(configPath) : null;
  // First-party Apple CoreDevice is the default. External MobileCLI is an
  // explicitly selected, independent legacy option; not a hard dependency.
  const driver = process.env.IGENTIC_IPHONE_DRIVER ?? 'coredevice';
  if (!['coredevice', 'mobilecli'].includes(driver)) throw new PluginError('unknownDriver');
  if (mode === 'physical' && driver === 'mobilecli' && !config?.mobilecliPath)
    throw new PluginError('mobilecliNotConfigured');
  const service = new PhoneService({ backend: mode === 'fixture' ? new FixtureBackend()
    : driver === 'coredevice' ? new NativeCoreDeviceBackend(config) : new MobileBackend(config),
    stateDir: process.env.IGENTIC_IPHONE_STATE_DIR ?? join(homedir(), 'Library/Application Support/iGentic/iphone-connect') });
  const server = createServer(service);
  const close = async () => { await service.close(); await server.close(); };
  process.once('SIGINT', () => void close()); process.once('SIGTERM', () => void close());
  process.stdin.once('end', () => void service.close());
  await server.connect(new StdioServerTransport());
}
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch(e => { console.error(e instanceof PluginError ? e.code : 'startupFailed'); process.exitCode = 1; });
}
