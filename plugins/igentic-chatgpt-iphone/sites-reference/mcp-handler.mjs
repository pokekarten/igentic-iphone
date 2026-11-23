import { SITES_HANDOFF_TOOL, callSitesHandoffTool } from './handoff-site.mjs';

// Stateless, owner-private Sites adapter. This endpoint is not an identity
// provider or a remotely authorized device driver.
const MAX_BYTES = 4096;
const VERSION = '2026-07-28';
const SERVER_INFO = Object.freeze({ name: 'igentic-iphone-handoff', version: '0.1.0' });
const SERVER_META = Object.freeze({ 'io.modelcontextprotocol/serverInfo': SERVER_INFO });
const headers = { 'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store', 'x-content-type-options': 'nosniff' };
const json = (value, status = 200) => new Response(JSON.stringify(value), { status, headers });
const failure = (id, code, message, status = 200, data) => json({jsonrpc:'2.0', id,
  error: { code, message, ...(data === undefined ? {} : { data }) }}, status);
const success = (id, result) => json({ jsonrpc:'2.0', id,
  result: {resultType:'complete', ...result, _meta: SERVER_META} });
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
  return JSON.parse(new TextDecoder('utf-8', {fatal:true}).decode(bytes));
}

export async function handleSitesMcp(request) {
  const url = new URL(request.url);
  if (url.pathname !== '/mcp' || url.search) return json({error:'notFound'}, 404);
  if (request.method !== 'POST')
    return new Response(null, {status:405, headers:{...headers,allow:'POST'}});
  if (request.headers.get('content-type')?.split(';')[0].trim().toLowerCase() !== 'application/json')
    return json({error:'jsonRequired'},415);
  let rpc;
  try { rpc = await readBoundedJSON(request); }
  catch (error) {
    return error instanceof RangeError ? json({error:'bodyTooLarge'},413)
      : failure(null,-32700,'Parse error',400);
  }
  // Reject malformed RPC, notifications and batches. Never echo request data.
  if (!record(rpc) || rpc.jsonrpc !== '2.0' || typeof rpc.method !== 'string'
      || !Object.hasOwn(rpc,'id')
      || !(typeof rpc.id === 'string' || Number.isSafeInteger(rpc.id))
      || (typeof rpc.id === 'string' && rpc.id.length > 128)
      || Object.keys(rpc).some(k => !['jsonrpc','id','method','params'].includes(k)))
    return failure(null,-32600,'Invalid Request',400);

  const {id,method,params} = rpc;
  if (!record(params)) return failure(id,-32602,'Invalid params');
  const meta = params._meta;
  const protocol = record(meta) ? meta['io.modelcontextprotocol/protocolVersion'] : undefined;
  if (!record(meta) || typeof protocol !== 'string'
      || !record(meta['io.modelcontextprotocol/clientCapabilities']))
    return failure(id,-32602,'Invalid params');
  // MCP 2026-07-28 mirrors version, method and tool name into HTTP headers.
  // Reject spoofed/missing mirrors BEFORE tool execution or tool discovery.
  const expectedName = method === 'tools/call' && typeof params.name === 'string'
    ? params.name : null;
  if (request.headers.get('mcp-protocol-version') !== protocol
      || request.headers.get('mcp-method') !== method
      || (expectedName !== null
        ? request.headers.get('mcp-name') !== expectedName
        : request.headers.has('mcp-name')))
    return failure(id,-32020,'Header mismatch',400);
  if (protocol !== VERSION)
    return failure(id,-32022,'Unsupported protocol version',400,
      {supported:[VERSION],requested:protocol});

  switch (method) {
    case 'server/discover':
      if (Object.keys(params).some(k=>k !== '_meta'))
        return failure(id,-32602,'Invalid params');
      return success(id,{ supportedVersions:[VERSION], capabilities:{tools:{}} });
    case 'tools/list':
      if (Object.keys(params).some(k=>k !== '_meta'))
        return failure(id,-32602,'Invalid params');
      return success(id,{ tools:[SITES_HANDOFF_TOOL] });
    case 'tools/call':
      if (Object.keys(params).some(k=>!['name','arguments','_meta'].includes(k)))
        return failure(id,-32602,'Invalid params');
      try {
        const data = callSitesHandoffTool(params.name,params.arguments);
        return success(id,{content:[{type:'text',text:JSON.stringify(data)}],
          structuredContent:{data},isError:false});
      } catch {
        return success(id,{content:[{type:'text',text:'unsupportedSiteToolCall'}],isError:true});
      }
    default:
      return failure(id,-32601,'Method not found',404);
  }
}
