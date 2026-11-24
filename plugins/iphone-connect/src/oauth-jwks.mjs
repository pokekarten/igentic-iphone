import { createRemoteJWKSet, jwtVerify } from 'jose';

const SCOPE = 'igentic:handoff:read';
const ALGORITHMS = Object.freeze(['RS256', 'PS256', 'ES256', 'EdDSA']);

// This is an OAuth *resource-server* verifier, not a JWT token issuer.
// No JWT-controlled jku/x5u URL, none or shared-secret HS* algorithm is trusted.
function strictHTTPSOrigin(value) {
  let url;
  try { url = new URL(value); } catch { throw new TypeError('jwksConfigInvalid'); }
  if (typeof value !== 'string' || !url.hostname || url.protocol !== 'https:'
      || url.username || url.password || url.hash || url.search
      || url.pathname !== '/' || url.origin !== value)
    throw new TypeError('jwksConfigInvalid');
  return url.origin;
}

export function validateTrustedJWKSConfig({ issuer, resource, jwksUri } = {}) {
  const trustedIssuer = strictHTTPSOrigin(issuer);
  const audience = strictHTTPSOrigin(resource);
  let jwks;
  try { jwks = new URL(jwksUri); } catch { throw new TypeError('jwksConfigInvalid'); }
  // By default the keyset MUST belong to this exact trusted issuer origin.
  // Fetching a URL chosen in a JWT header would allow SSRF/key confusion.
  if (typeof jwksUri !== 'string' || jwks.protocol !== 'https:'
      || jwks.origin !== trustedIssuer || jwks.username || jwks.password
      || jwks.hash || jwks.search || jwks.pathname === '/'
      || jwks.toString() !== jwksUri)
    throw new TypeError('jwksConfigInvalid');
  return Object.freeze({ issuer: trustedIssuer, resource: audience, jwksUri });
}

export async function verifySignedJWTAccessToken(token, keySet, { issuer, resource }) {
  if (typeof token !== 'string' || token.length < 24 || token.length > 8192)
    throw new Error('jwtInvalid');
  // jwtVerify validates signature against the trusted, explicit keyset;
  // issuer, audience, expiry and max token age are independently enforced.
  const { payload, protectedHeader } = await jwtVerify(token, keySet, {
    issuer, audience: resource, algorithms: [...ALGORITHMS],
    requiredClaims: ['sub', 'exp', 'iat'], clockTolerance: '5 seconds',
    maxTokenAge: '1 hour'
  });
  if (protectedHeader.jku !== undefined || protectedHeader.x5u !== undefined
      || typeof payload.sub !== 'string' || payload.sub.trim().length === 0
      || typeof payload.exp !== 'number' || typeof payload.iat !== 'number'
      || !Number.isFinite(payload.exp) || !Number.isFinite(payload.iat)
      || typeof payload.scope !== 'string'
      || !payload.scope.split(/\s+/).includes(SCOPE))
    throw new Error('jwtInvalid');
  return payload;
}

export function createTrustedJWKSAccessTokenVerifier(config) {
  const trusted = validateTrustedJWKSConfig(config);
  // JWKS URL is fixed by the owner at startup, never read from JWT headers.
  // JOSE fetches over HTTPS with certificate checking, limits response time,
  // caches keysets and handles key rotation.
  const keys = createRemoteJWKSet(new URL(trusted.jwksUri), {
    timeoutDuration: 5000, cacheMaxAge: 300000, cooldownDuration: 30000
  });
  return async (token, context) => {
    if (context?.resource !== trusted.resource || context?.scope !== SCOPE
        || !context?.authorizationServers?.includes(trusted.issuer))
      throw new Error('jwtContextInvalid');
    return verifySignedJWTAccessToken(token, keys, trusted);
  };
}

export function createTrustedJWKSResourceServerOAuth(config) {
  const trusted = validateTrustedJWKSConfig(config);
  return Object.freeze({
    resource: trusted.resource,
    authorizationServers: [trusted.issuer],
    verifyAccessToken: createTrustedJWKSAccessTokenVerifier(trusted)
  });
}


// Only the server operator can select these three trusted settings. An
// incomplete configuration must prevent startup; the default remains an
// unauthenticated loopback *preview* with no device data or writes.
export function oauthFromEnvironment(env) {
  const vars = [
    env.IGENTIC_OAUTH_ISSUER,
    env.IGENTIC_OAUTH_RESOURCE,
    env.IGENTIC_OAUTH_JWKS_URI
  ];
  if (vars.every(v => v === undefined)) return undefined;
  if (vars.some(v => typeof v !== 'string' || !v))
    throw new Error('oauthNotConfigured');
  return createTrustedJWKSResourceServerOAuth({
    issuer: vars[0], resource: vars[1], jwksUri: vars[2]
  });
}
