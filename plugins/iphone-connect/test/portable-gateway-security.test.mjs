import test from 'node:test';
import assert from 'node:assert/strict';
import { request as httpRequest } from 'node:http';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import { startPortableGateway } from '../src/portable-gateway.mjs';

const resource = 'https://igentic.example.test';
const issuer = 'https://identity.example.test';
const now = () => Math.floor(Date.now() / 1000);
const claims = (extra = {}) => ({
  iss: issuer, aud: resource, exp: now() + 3600,
  scope: 'igentic:handoff:read', ...extra
});
const validToken = 'test-only-local-no-real-credentials';
const fixtureVerifier = async token => {
  if (token === validToken) return claims();
  if (token === 'test-only-expired-token') return claims({ exp: now() - 1 });
  if (token === 'test-only-wrong-issuer') return claims({ iss: 'https://wrong.example.test' });
  if (token === 'test-only-wrong-audience') return claims({ aud: 'https://wrong.example.test' });
  if (token === 'test-only-wrong-scopes') return claims({ scope: 'igentic:phone:write' });
  if (token === 'test-only-future-nbf') return claims({ nbf: now() + 3600 });
  throw Error('untrusted');
};

test('OAuth server mode needs HTTPS resource, issuer and explicit verifier', async () => {
  for (const oauth of [
    {}, null, { resource: 'http://127.0.0.1', authorizationServers: [issuer], verifyAccessToken: fixtureVerifier },
    { resource, authorizationServers: ['http://127.0.0.1'], verifyAccessToken: fixtureVerifier },
    { resource, authorizationServers: [issuer] },
    { resource, authorizationServers: [], verifyAccessToken: fixtureVerifier },
    { resource: 'https://user:pass@igentic.example.test', authorizationServers: [issuer], verifyAccessToken: fixtureVerifier },
    { resource, authorizationServers: [issuer, issuer], verifyAccessToken: fixtureVerifier }
  ]) await assert.rejects(startPortableGateway({ oauth }), /oauthNotConfigured/);
});

test('protected local MCP rejects mismatched credentials and accepts a verified fixture client', async t => {
  // This is a test fixture. Real identity providers must check signed JWTs.
  const gateway = await startPortableGateway({
    oauth: { resource, authorizationServers: [issuer], verifyAccessToken: fixtureVerifier }
  });
  t.after(() => gateway.close());
  assert.equal(gateway.host, '127.0.0.1');
  const endpoint = 'http://127.0.0.1:' + gateway.port;
  const metadata = await fetch(endpoint + '/.well-known/oauth-protected-resource');
  assert.equal(metadata.status, 200);
  assert.deepEqual(await metadata.json(), {
    resource, authorization_servers: [issuer],
    scopes_supported: ['igentic:handoff:read'], bearer_methods_supported: ['header']
  });
  const call = async auth => fetch(endpoint + '/mcp', {
    method: 'POST', headers: {
      'content-type': 'application/json',
      ...(auth ? { authorization: auth } : {})
    }, body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/list' })
  });
  const response = await call();
  assert.equal(response.status, 401);
  assert.match(response.headers.get('www-authenticate'), /Bearer resource_metadata=/);
  for (const value of [
    'not-a-valid-credential', 'test-only-expired-token', 'test-only-wrong-issuer',
    'test-only-wrong-audience', 'test-only-wrong-scopes', 'test-only-future-nbf'
  ]) assert.equal((await call('Bearer ' + value)).status, 401);
  assert.equal((await call('Basic ' + validToken)).status, 401);
  const client = new Client({ name: 'oauth-fixture', version: '1.0.0' });
  t.after(() => client.close());
  await client.connect(new StreamableHTTPClientTransport(new URL(endpoint + '/mcp'), {
    requestInit: { headers: { authorization: 'Bearer ' + validToken } }
  }));
  const tools = (await client.listTools()).tools;
  assert.ok(tools.some(x => x.name === 'iphone_chatgpt_handoff'));
  assert.ok(tools.every(x => x.annotations.readOnlyHint === true));
  const handoff = await client.callTool({
    name: 'iphone_chatgpt_handoff', arguments: { action: 'discovery' }
  });
  assert.equal(handoff.structuredContent.data.actionExecuted, false);
  assert.equal(handoff.structuredContent.data.requiresOwnerTap, true);
  assert.equal(handoff.structuredContent.data.iPhoneConnected, 'not-checked');
  assert.doesNotMatch(JSON.stringify(handoff), /test-only-local-no-real-credentials/);
});

test('local MCP refuses DNS rebinding, cross-site origin, forwarded host and unbounded payloads', async t => {
  const gateway = await startPortableGateway();
  t.after(() => gateway.close());
  const url = 'http://127.0.0.1:' + gateway.port;
  assert.equal((await fetch(url + '/.well-known/oauth-protected-resource')).status, 404);
  const body = '{"jsonrpc":"2.0","method":"initialize","id":1}';
  const headers = { 'content-type': 'application/json' };
  // Node fetch may normalize Host. Use a raw Node HTTP request so the
  // forged Host header actually reaches the local server unchanged.
  const forgedHostStatus = await new Promise((resolve, reject) => {
    const req = httpRequest(url + '/mcp', {
      method: 'POST', headers: { ...headers, host: 'evil.example' }
    }, res => { res.resume(); res.on('end', () => resolve(res.statusCode)); });
    req.on('error', reject);
    req.end(body);
  });
  assert.equal(forgedHostStatus, 403);
  assert.equal((await fetch(url + '/mcp', {
    method: 'POST', headers: { ...headers, origin: 'https://evil.example' }, body
  })).status, 403);
  assert.equal((await fetch(url + '/mcp', {
    method: 'POST', headers: { ...headers, 'x-forwarded-host': 'evil.example' }, body
  })).status, 403);
  assert.equal((await fetch(url + '/mcp', {
    method: 'POST', headers: { 'content-type': 'text/plain' }, body
  })).status, 415);
  assert.equal((await fetch(url + '/mcp', {
    method: 'POST', headers, body: 'x'.repeat(65537)
  })).status, 413);
  const chunked = await fetch(url + '/mcp', {
    method: 'POST', headers, duplex: 'half',
    body: new ReadableStream({
      start(controller) {
        controller.enqueue(new TextEncoder().encode(body)); controller.close();
      }
    })
  });
  assert.equal(chunked.status, 411);
});
