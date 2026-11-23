import { SITES_HANDOFF_TOOL, callSitesHandoffTool } from './handoff-site.mjs';

// Stateless Sites adapter, with no device driver, storage, identity logging or
// outbound requests. Sites must enforce owner-private access before forwarding
// requests. This handler is NOT an authentication layer for another host.
const MAX_BYTES = 4096;
const headers = { 'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store', 'x-content-type-options': 'nosniff' };
const json = (value, status = 200) => new Response(JSON.stringify(value), { status, headers });
const failure = (id, code, message, status = 200) =>
  json({ jsonrpc: '2.0', id, error: { code, message } }, status);
const record = value => value !== null && typeof value === 'object' && !Array.isArray(value);

async function readBoundedJSON(request) {
  if (!request.body) throw new Error('invalidJSON');
  const reader = request.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_BYTES) {
        await reader.cancel();
        throw new RangeError('bodyTooLarge');
      }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes));
}

export async function handleSitesMcp(request) {
  const url = new URL(request.url);
  if (url.pathname !== '/mcp' || url.search)
    return json({ error: 'notFound' }, 404);
  if (request.method !== 'POST')
    return new Response(null, { status: 405, headers: { ...headers, allow: 'POST' } });
  if (request.headers.get('content-type')?.split(';')[0].trim().toLowerCase() !== 'application/json')
    return json({ error: 'jsonRequired' }, 415);
  let rpc;
  try { rpc = await readBoundedJSON(request); }
  catch (error) {
    return error instanceof RangeError ? json({ error: 'bodyTooLarge' }, 413)
      : failure(null, -32700, 'Parse error', 400);
  }
  // Do not reflect arbitrary strings, caller headers, arguments or error details.
  if (!record(rpc) || rpc.jsonrpc !== '2.0' || typeof rpc.method !== 'string'
      || !Object.hasOwn(rpc, 'id')
      || !(typeof rpc.id === 'string' || Number.isSafeInteger(rpc.id))
      || (typeof rpc.id === 'string' && rpc.id.length > 128)
      || Object.keys(rpc).some(key => !['jsonrpc', 'id', 'method', 'params'].includes(key)))
    return failure(null, -32600, 'Invalid Request', 400);
  const { id, method, params } = rpc;
  if (params !== undefined && !record(params))
    return failure(id, -32602, 'Invalid params');
  let result;
  switch (method) {
    case 'server/discover':
      result = { supportedVersions: ['2026-07-28'], capabilities: { tools: {} } };
      break;
    case 'tools/list':
      if (params && Object.keys(params).length)
        return failure(id, -32602, 'Invalid params');
      result = { tools: [SITES_HANDOFF_TOOL] };
      break;
    case 'tools/call':
      if (!record(params) || Object.keys(params).some(key => !['name', 'arguments'].includes(key)))
        return failure(id, -32602, 'Invalid params');
      try {
        const data = callSitesHandoffTool(params.name, params.arguments);
        result = { content: [{ type: 'text', text: JSON.stringify(data) }],
          structuredContent: { data }, isError: false };
      } catch {
        result = { content: [{ type: 'text', text: 'unsupportedSiteToolCall' }], isError: true };
      }
      break;
    default: return failure(id, -32601, 'Method not found');
  }
  return json({ jsonrpc: '2.0', id, result });
}
