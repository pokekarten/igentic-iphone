// Local-only MCP transport guard and opt-in OAuth *resource-server* seam.
// This is not an OAuth issuer, a token signer or a public HTTPS deployment.
// A future owner-selected identity provider MUST cryptographically verify
// signature, issuer, audience, expiration, and scopes in verifyAccessToken.
const FIXED_SCOPE = 'igentic:handoff:read';

function httpsURL(value) {
  if (typeof value !== 'string') throw new Error('oauthNotConfigured');
  let url;
  try { url = new URL(value); } catch { throw new Error('oauthNotConfigured'); }
  if (url.protocol !== 'https:' || !url.hostname || url.username || url.password
      || url.search || url.hash || url.pathname !== '/')
    throw new Error('oauthNotConfigured');
  return url.origin;
}

export function validateOAuthConfig(oauth) {
  if (oauth === undefined) return null;
  if (!oauth || typeof oauth !== 'object' || Array.isArray(oauth)
      || typeof oauth.verifyAccessToken !== 'function'
      || !Array.isArray(oauth.authorizationServers)
      || oauth.authorizationServers.length < 1
      || oauth.authorizationServers.length > 3)
    throw new Error('oauthNotConfigured');
  const resource = httpsURL(oauth.resource);
  const authorizationServers = oauth.authorizationServers.map(httpsURL);
  if (new Set(authorizationServers).size !== authorizationServers.length)
    throw new Error('oauthNotConfigured');
  return Object.freeze({
    resource, authorizationServers, scope: FIXED_SCOPE,
    metadataUrl: resource + '/.well-known/oauth-protected-resource',
    verifyAccessToken: oauth.verifyAccessToken
  });
}

export function isLocalGatewayRequest(req, port) {
  const host = req.headers.host;
  // Only the literal loopback target is accepted; don't trust arbitrary
  // Host, DNS names, upstream proxy metadata or forwarded headers.
  if (host !== '127.0.0.1:' + port && host !== 'localhost:' + port) return false;
  const origin = req.headers.origin;
  if (origin !== undefined && origin !== 'http://' + host) return false;
  if (req.headers['x-forwarded-host'] || req.headers['x-forwarded-proto']) return false;
  return true;
}

export function hasBoundedJSONBody(req, maxLength = 65536) {
  // Reject chunked (or missing) length rather than trusting a forged
  // Content-Length. The MCP client sends fixed-length JSON POSTs.
  if (req.headers['transfer-encoding'] !== undefined) return 'lengthRequired';
  const length = req.headers['content-length'];
  if (typeof length !== 'string' || !/^[0-9]{1,8}$/.test(length))
    return 'lengthRequired';
  if (Number(length) > maxLength) return 'tooLarge';
  const contentType = req.headers['content-type'];
  if (typeof contentType !== 'string'
      || !/^application\/json(?:\s*;\s*charset=utf-8)?$/i.test(contentType))
    return 'wrongContentType';
  return 'ok';
}

export async function verifiedOAuthAccess(req, oauth) {
  const header = req.headers.authorization;
  const match = typeof header === 'string'
    ? /^Bearer ([^\s]{16,8192})$/i.exec(header) : null;
  if (!match) return false;
  try {
    // Only the trusted, signature-checking identity-provider adapter may
    // return verified claims here. Never treat decoded JWT text as proof.
    const claims = await oauth.verifyAccessToken(match[1], {
      resource: oauth.resource, scope: oauth.scope,
      authorizationServers: oauth.authorizationServers
    });
    if (!claims || typeof claims !== 'object') return false;
    const aud = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
    const scopes = Array.isArray(claims.scope) ? claims.scope
      : typeof claims.scope === 'string' ? claims.scope.split(/\s+/) : [];
    const now = Math.floor(Date.now() / 1000);
    return oauth.authorizationServers.includes(claims.iss)
      && aud.includes(oauth.resource)
      && Number.isFinite(claims.exp) && claims.exp > now
      && (claims.nbf === undefined || Number.isFinite(claims.nbf) && claims.nbf <= now)
      && scopes.includes(oauth.scope) ? claims : false;
  } catch {
    return false;
  }
}

export function protectedResourceMetadata(oauth) {
  return {
    resource: oauth.resource,
    authorization_servers: [...oauth.authorizationServers],
    scopes_supported: [oauth.scope],
    bearer_methods_supported: ['header']
  };
}

export async function hasValidOAuthAccess(req, oauth) {
  return Boolean(await verifiedOAuthAccess(req, oauth));
}
