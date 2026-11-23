// Client-neutral, read-only MCP gateway preview. No phone or private data.
import { createServer as createHttpServer } from 'node:http';
import { fileURLToPath } from 'node:url';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { z } from 'zod';
import { makeConnectionReport } from './connection-report.mjs';
import { optionalToolCatalog, prepareLocalTask } from './optional-core.mjs';

const noArgs = z.object({}).strict();
const output = z.object({ data: z.record(z.string(), z.unknown()) });
const annotations = { readOnlyHint: true, destructiveHint: false, openWorldHint: false };
const wrap = data => ({
  structuredContent: { data },
  content: [{ type: 'text', text: JSON.stringify(data) }]
});
export function createPortableMcp() {
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
      task: z.enum(['diagnostics', 'discovery', 'text-draft', 'speak-text', 'read-image-text', 'reminder']),
      text: z.string().max(800).optional()
    }).strict(), outputSchema: output, annotations
  }, async ({ task, text }) => wrap(prepareLocalTask(task, text)));
  return mcp;
}
export async function startPortableGateway({ port = 0 } = {}) {
  if (!Number.isInteger(port) || port < 0 || port > 65535) throw Error('invalidPort');
  const http = createHttpServer(async (req, res) => {
    if (req.url !== '/mcp') {
      res.writeHead(404, { 'content-type': 'text/plain' }).end('Not found');
      return;
    }
    if (req.method !== 'POST') {
      res.writeHead(405, { 'allow': 'POST', 'content-type': 'text/plain' })
        .end('Method not allowed');
      return;
    }
    if (Number(req.headers['content-length']) > 65536) {
      res.writeHead(413, { 'content-type': 'text/plain' }).end('Too large');
      return;
    }
    const mcp = createPortableMcp();
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
  startPortableGateway({ port: Number(process.env.IGENTIC_PORTABLE_MCP_PORT ?? '37865') })
    .then(gateway => console.error('iGentic read-only MCP gateway: http://127.0.0.1:' + gateway.port + '/mcp'))
    .catch(() => { console.error('gatewayStartupFailed'); process.exitCode = 1; });
}
