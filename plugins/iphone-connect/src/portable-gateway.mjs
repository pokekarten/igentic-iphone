// Client-neutral, read-only MCP gateway preview. No phone or private data.
import { createServer as createHttpServer } from 'node:http';
import { fileURLToPath } from 'node:url';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { z } from 'zod';
import { makeConnectionReport } from './connection-report.mjs';
import { optionalToolCatalog, prepareLocalTask } from './optional-core.mjs';
import { HANDOFF_ACTIONS, prepareChatGPTHandoff } from './chatgpt-handoff.mjs';
import { oauthFromEnvironment } from './oauth-jwks.mjs';
import { validateOAuthConfig, isLocalGatewayRequest, hasBoundedJSONBody,
  verifiedOAuthAccess, protectedResourceMetadata } from './portable-gateway-security.mjs';

const noArgs = z.object({}).strict();
const output = z.object({ data: z.record(z.string(), z.unknown()) });
const annotations = { readOnlyHint: true, destructiveHint: false, openWorldHint: false };
const wrap = data => ({
  structuredContent: { data },
  content: [{ type: 'text', text: JSON.stringify(data) }]
});
export function createPortableMcp({ lookupOwnerResult } = {}) {
  const mcp = new McpServer({ name: 'igentic-iphone-portable', version: '0.1.0' }, {
    instructions: 'Read-only portable preview for MCP clients. No physical-device observation, iPhone action, screenshots, personal data or iOS settings. Do not claim a connected iPhone.'
  });
  mcp.registerTool('iphone_connection_report', {
    title: 'Inspect iPhone connection paths',
    description: 'Read-only USB-C, Wi-Fi, cellular, native and simulator readiness plan. No real phone connection.',
    inputSchema: noArgs, outputSchema: output, annotations
  }, async () => wrap({
    ...makeConnectionReport({ backend: 'physical', devices: [] }),
    backend: 'portable-preview',
    nextStep: 'connect-approved-iphone-companion-in-future'
  }));
  mcp.registerTool('iphone_get_capabilities', {
    title: 'Inspect portable iGentic capabilities',
    description: 'Client-independent preview. No device operations, settings changes or remote writes.',
    inputSchema: noArgs, outputSchema: output, annotations
  }, async () => wrap({
    backend: 'portable-preview',
    clientInterfaces: ['mcp', 'native-ios-app-intents-planned'],
    deviceControl: 'not-connected',
    cellularCompanion: 'readiness-only-not-verified',
    actions: [],
    transport: 'loopback-streamable-http'
  }));
  mcp.registerTool('iphone_tool_catalog', {
    title: 'List independent iPhone capabilities and optional tools',
    description: 'First-party local functions and optional providers. Never claims that an add-on is installed or reachable.',
    inputSchema: noArgs, outputSchema: output, annotations
  }, async () => wrap(optionalToolCatalog()));
  mcp.registerTool('iphone_prepare_local_task', {
    title: 'Prepare a manual on-device task without Mac or cloud',
    description: 'Non-executing instructions for the first-party native app. User-supplied draft text remains within this request; no phone is contacted.',
    inputSchema: z.object({
      task: z.enum(['diagnostics', 'discovery', 'text-draft', 'workspace-note', 'speak-text', 'dictate-text', 'read-image-text', 'reminder']),
      text: z.string().max(800).optional()
    }).strict(), outputSchema: output, annotations
  }, async ({ task, text }) => wrap(prepareLocalTask(task, text)));
  mcp.registerTool('iphone_chatgpt_handoff', {
    title: 'Prepare an iPhone handoff link for ChatGPT',
    description: 'Generate an allowlisted user-tapped link into our signed iGentic iPhone app. Does NOT call App Intents, execute actions, read phone data or imply a connected iPhone. For reminders, review and owner approval stay inside the app.',
    inputSchema: z.object({ action: z.enum(HANDOFF_ACTIONS) }).strict(),
    outputSchema: output, annotations
  }, async ({ action }) => wrap(prepareChatGPTHandoff(action)));
  if (lookupOwnerResult) {
    mcp.registerTool('iphone_owner_task_result', {
      description: 'Read relay evidence for the original task ID without triggering an action.',
      inputSchema: z.object({
        requestId: z.string().regex(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
      }).strict(), outputSchema: output, annotations
    }, async ({ requestId }) => {
      try { return wrap({ result: await lookupOwnerResult(requestId) }); }
      catch { return { isError: true, content: [{ type: 'text', text: 'resultUnavailable' }] }; }
    });
  }
  return mcp;
}
export async function startPortableGateway({ port = 0, oauth, ownerResults } = {}) {
  if (!Number.isInteger(port) || port < 0 || port > 65535) throw Error('invalidPort');
  const auth = validateOAuthConfig(oauth);
  if (ownerResults && (!auth || !auth.authorizationServers.includes(ownerResults.issuer)
      || typeof ownerResults.subject !== 'string' || !ownerResults.subject.trim()
      || typeof ownerResults.lookup !== 'function')) throw Error('invalidOwnerResultConfig');
  const { issuer, subject, lookup } = ownerResults ?? {};
  const http = createHttpServer(async (req, res) => {
    res.setHeader('cache-control', 'no-store');
    const port = http.address().port;
    if (!isLocalGatewayRequest(req, port)) {
      res.writeHead(403, { 'content-type': 'text/plain' }).end('Forbidden');
      return;
    }
    if (req.url === '/.well-known/oauth-protected-resource' && auth
        && req.method === 'GET') {
      res.writeHead(200, { 'content-type': 'application/json' })
        .end(JSON.stringify(protectedResourceMetadata(auth)));
      return;
    }
    if (req.url !== '/mcp') {
      res.writeHead(404, { 'content-type': 'text/plain' }).end('Not found');
      return;
    }
    if (req.method !== 'POST') {
      res.writeHead(405, { 'allow': 'POST', 'content-type': 'text/plain' })
        .end('Method not allowed');
      return;
    }
    const claims = auth ? await verifiedOAuthAccess(req, auth) : null;
    if (auth && !claims) {
      res.writeHead(401, {
        'content-type': 'text/plain',
        'www-authenticate': 'Bearer resource_metadata="' + auth.metadataUrl
          + '", scope="' + auth.scope + '"'
      }).end('Unauthorized');
      return;
    }
    const bodyStatus = hasBoundedJSONBody(req);
    if (bodyStatus !== 'ok') {
      const code = bodyStatus === 'tooLarge' ? 413
        : bodyStatus === 'wrongContentType' ? 415 : 411;
      res.writeHead(code, { 'content-type': 'text/plain' }).end('Invalid request');
      return;
    }
    const mcp = createPortableMcp({
      lookupOwnerResult: claims?.iss === issuer && claims?.sub === subject ? lookup : undefined
    });
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined, enableJsonResponse: true
    });
    res.once('close', () => {
      void transport.close().catch(() => {});
      void mcp.close().catch(() => {});
    });
    try {
      await mcp.connect(transport);
      await transport.handleRequest(req, res);
    } catch {
      if (!res.headersSent) {
        res.writeHead(500, { 'content-type': 'application/json' }).end(
          JSON.stringify({ jsonrpc: '2.0',
            error: { code: -32603, message: 'Internal server error' }, id: null })
        );
      }
    }
  });
  await new Promise((resolve, reject) => {
    http.once('error', reject);
    http.listen(port, '127.0.0.1', resolve);
  });
  return {
    server: http, host: '127.0.0.1', port: http.address().port,
    close: () => new Promise((resolve, reject) =>
      http.close(err => err ? reject(err) : resolve()))
  };
}
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  // CLI staging mode uses JOSE JWKS cryptographic verification, not a test
  // callback. Incomplete OAuth config fails closed before opening the port.
  startPortableGateway({
    port: Number(process.env.IGENTIC_PORTABLE_MCP_PORT ?? '37865'),
    oauth: oauthFromEnvironment(process.env)
  })
    .then(gateway => console.error('iGentic read-only MCP gateway: http://127.0.0.1:' + gateway.port + '/mcp'))
    .catch(() => { console.error('gatewayStartupFailed'); process.exitCode = 1; });
}
