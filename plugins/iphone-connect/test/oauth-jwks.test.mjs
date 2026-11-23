import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPair, exportJWK, createLocalJWKSet, SignJWT } from 'jose';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import { startPortableGateway } from '../src/portable-gateway.mjs';
import {
  validateTrustedJWKSConfig, verifySignedJWTAccessToken,
  createTrustedJWKSResourceServerOAuth, oauthFromEnvironment
} from '../src/oauth-jwks.mjs';

const issuer = 'https://accounts.igentic.example.test';
const resource = 'https://mcp.igentic.example.test';
const jwksUri = issuer + '/.well-known/jwks.json';

test('trusted static issuer and HTTPS JWKS config rejects SSRF and JWT header URL assumptions', () => {
  const conf = validateTrustedJWKSConfig({ issuer, resource, jwksUri });
  assert.deepEqual(conf, { issuer, resource, jwksUri });
  for (const args of [
    { issuer: 'http://127.0.0.1', resource, jwksUri },
    { issuer, resource: 'http://mcp.igentic.example.test', jwksUri },
    { issuer, resource, jwksUri: 'http://127.0.0.1/private' },
    { issuer, resource, jwksUri: 'https://evil.example.test/.well-known/jwks.json' },
    { issuer, resource, jwksUri: issuer + '/' },
    { issuer, resource, jwksUri: issuer + '/jwks.json?token=secret' },
    { issuer, resource, jwksUri: issuer.replace('accounts','user:pass@accounts') + '/jwks.json' },
    { issuer, resource, jwksUri: issuer + '/jwks.json#fragment' },
    { issuer, resource, jwksUri: issuer + '/jwks.json/../other.json' },
    { issuer: issuer + '/tenant', resource, jwksUri }
  ]) assert.throws(() => validateTrustedJWKSConfig(args), /jwksConfigInvalid/);
  assert.equal(oauthFromEnvironment({}), undefined);
  assert.throws(() => oauthFromEnvironment({
    IGENTIC_OAUTH_RESOURCE: resource
  }), /oauthNotConfigured/);
  const oauthEnv = oauthFromEnvironment({
    IGENTIC_OAUTH_ISSUER: issuer, IGENTIC_OAUTH_RESOURCE: resource,
    IGENTIC_OAUTH_JWKS_URI: jwksUri
  });
  assert.equal(oauthEnv.resource, resource);
  const oauth = createTrustedJWKSResourceServerOAuth({ issuer, resource, jwksUri });
  assert.equal(oauth.resource, resource);
  assert.deepEqual(oauth.authorizationServers, [issuer]);
  assert.equal(typeof oauth.verifyAccessToken, 'function');
});

test('actual RSA signature, issuer, audience, freshness and read-only scope protect local MCP tool', async t => {
  const { publicKey, privateKey } = await generateKeyPair('RS256');
  const jwk = await exportJWK(publicKey);
  Object.assign(jwk, { kid: 'igentic-unit-rsa-1', alg: 'RS256', use: 'sig' });
  const trustedKeySet = createLocalJWKSet({ keys: [jwk] });
  const sign = (patch = {}, header = { alg: 'RS256', kid: jwk.kid }) => {
    const { sub = 'fixture-person', scope = 'igentic:handoff:read',
      iss = issuer, aud = resource, iat, exp, nbf } = patch;
    let jwt = new SignJWT({ scope, ...patch })
      .setProtectedHeader(header)
      .setIssuer(iss).setAudience(aud).setSubject(sub)
      .setIssuedAt(iat ?? Math.floor(Date.now() / 1000));
    if (exp !== null) jwt = jwt.setExpirationTime(exp ?? '15m');
    if (nbf !== undefined) jwt = jwt.setNotBefore(nbf);
    return jwt.sign(privateKey);
  };
  const verify = token => verifySignedJWTAccessToken(token, trustedKeySet, { issuer, resource });
  const valid = await sign();
  assert.equal((await verify(valid)).scope, 'igentic:handoff:read');
  const today = Math.floor(Date.now() / 1000);
  const forbidden = [
    await sign({ iss: 'https://other.example.test' }),
    await sign({ aud: 'https://other-resource.example.test' }),
    await sign({ exp: today - 10 }),
    await sign({ nbf: today + 3600 }),
    await sign({ iat: today - 7200, exp: today + 500 }),
    await sign({ scope: 'igentic:phone:write' }),
    await sign({ scope: 'wrong-igentic:handoff:read' }),
    await sign({}, { alg: 'RS256', kid: jwk.kid, jku: 'https://evil.example.test/key' }),
    await sign({}, { alg: 'RS256', kid: jwk.kid, x5u: 'https://evil.example.test/cert' }),
    await sign({ sub: '' }),
    await sign({ exp: null })
  ];
  for (const token of forbidden) await assert.rejects(verify(token));
  const broken = valid.split('.');
  broken[1] = broken[1].slice(0, -1) + (broken[1].endsWith('A') ? 'B' : 'A');
  await assert.rejects(verify(broken.join('.')));
  const wrongKey = (await generateKeyPair('RS256')).privateKey;
  await assert.rejects(verify(await new SignJWT({ scope: 'igentic:handoff:read' })
    .setProtectedHeader({ alg: 'RS256', kid: jwk.kid })
    .setIssuer(issuer).setAudience(resource).setSubject('fixture-person')
    .setIssuedAt().setExpirationTime('15m').sign(wrongKey)));

  // Integration is a real MCP SDK POST, using real signature validation and
  // only a disposable local keyset. No real issuer, password or API key.
  const gateway = await startPortableGateway({
    oauth: {
      resource, authorizationServers: [issuer],
      verifyAccessToken: (token, ctx) => {
        assert.equal(ctx.resource, resource);
        assert.equal(ctx.scope, 'igentic:handoff:read');
        return verify(token);
      }
    }
  });
  t.after(() => gateway.close());
  const endpoint = 'http://127.0.0.1:' + gateway.port + '/mcp';
  const denied = await fetch(endpoint, {
    method: 'POST', headers: {
      authorization: 'Bearer ' + (await sign({ scope: 'igentic:phone:write' })),
      'content-type': 'application/json'
    }, body: '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
  });
  assert.equal(denied.status, 401);
  const client = new Client({ name: 'signed-fixture', version: '0.1.0' });
  t.after(() => client.close());
  await client.connect(new StreamableHTTPClientTransport(new URL(endpoint), {
    requestInit: { headers: { authorization: 'Bearer ' + valid } }
  }));
  const response = await client.callTool({ name: 'iphone_chatgpt_handoff',
    arguments: { action: 'diagnostics' } });
  assert.equal(response.structuredContent.data.launchUrl, 'igentic://handoff/v1/diagnostics');
  assert.equal(response.structuredContent.data.actionExecuted, false);
  assert.equal(response.structuredContent.data.iPhoneConnected, 'not-checked');
  assert.doesNotMatch(JSON.stringify(response), /fixture-person|igentic-unit-rsa-1/);
});
