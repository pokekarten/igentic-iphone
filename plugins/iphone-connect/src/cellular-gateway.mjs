// iGentic-owned opt-in cellular readiness endpoint: HTTPS only.
// No phone control, arbitrary actions, device identifiers or IP logging.
import { createServer as createHttpsServer } from 'node:https';
import { createHmac, createHash, timingSafeEqual } from 'node:crypto';
import { readFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

export const HEARTBEAT_PATH = '/v1/companion/readiness';
export const HEARTBEAT_BODY = Buffer.from('{"schema":1,"kind":"readiness"}');
const MAX_BODY = 512;
const WINDOW_SECONDS = 60;
const MAX_NONCES = 1024;
const NONCE_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export function decodeSharedKey(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9+/]{43}=$/.test(value.trim()))
    throw Error('invalidPrivateCellularKey');
  const b = Buffer.from(value.trim(), 'base64');
  if (b.length !== 32 || b.toString('base64') !== value.trim())
    throw Error('invalidPrivateCellularKey');
  return b;
}

export function cellularMessage({ timestamp, nonce, body = HEARTBEAT_BODY }) {
  if (!Number.isSafeInteger(timestamp) || typeof nonce !== 'string'
      || !NONCE_PATTERN.test(nonce)) throw Error('invalidCellularEnvelope');
  const sha = createHash('sha256').update(body).digest('hex');
  return ['igentic-cellular-v1', 'POST', HEARTBEAT_PATH,
    String(timestamp), nonce, sha].join('\n');
}

export function signCellular({ key, timestamp, nonce, body = HEARTBEAT_BODY }) {
  if (!Buffer.isBuffer(key) || key.length !== 32) throw Error('invalidPrivateCellularKey');
  return createHmac('sha256', key)
    .update(cellularMessage({ timestamp, nonce, body }), 'utf8').digest('hex');
}

const failure = status => ({ status, body: { schema: 1, status: 'rejected' } });

export function createHeartbeatVerifier({ key, nowSeconds = () => Math.floor(Date.now() / 1000) }) {
  if (!Buffer.isBuffer(key) || key.length !== 32) throw Error('invalidPrivateCellularKey');
  const nonces = new Map();
  return ({ method, url, headers, body, secure }) => {
    if (!secure) return failure(403);
    if (url !== HEARTBEAT_PATH) return failure(404);
    if (method !== 'POST') return failure(405);
    if (!Buffer.isBuffer(body) || body.length !== HEARTBEAT_BODY.length
        || !timingSafeEqual(body, HEARTBEAT_BODY)) return failure(400);
    const timestampText = headers['x-igentic-timestamp'];
    const nonce = headers['x-igentic-nonce'];
    const auth = headers['x-igentic-signature'];
    if (typeof timestampText !== 'string' || !/^[1-9][0-9]{0,11}$/.test(timestampText)
        || typeof nonce !== 'string' || !NONCE_PATTERN.test(nonce)
        || typeof auth !== 'string' || !/^[0-9a-f]{64}$/.test(auth))
      return failure(401);
    const timestamp = Number(timestampText);
    const now = nowSeconds();
    if (!Number.isSafeInteger(timestamp) || Math.abs(now - timestamp) > WINDOW_SECONDS)
      return failure(401);
    const expected = Buffer.from(signCellular({ key, timestamp, nonce, body }), 'hex');
    const supplied = Buffer.from(auth, 'hex');
    if (supplied.length !== expected.length || !timingSafeEqual(supplied, expected))
      return failure(401);
    // Cache only authenticated nonces; per-process bounded replay resistance.
    for (const [n, t] of nonces) if (now - t > WINDOW_SECONDS * 2) nonces.delete(n);
    if (nonces.has(nonce)) return failure(409);
    if (nonces.size >= MAX_NONCES) return failure(429);
    nonces.set(nonce, now);
    return { status: 200, body: {
      schema: 1, status: 'accepted', capability: 'readiness-only',
      deviceControl: 'not-enabled', backgroundExecution: 'not-guaranteed'
    } };
  };
}

export function createCellularGateway({ tlsKey, tlsCert, sharedKey, port = 0, host = '127.0.0.1',
  publicBindAcknowledged = false } = {}) {
  if (!Buffer.isBuffer(tlsKey) || !Buffer.isBuffer(tlsCert)
      || !Buffer.isBuffer(sharedKey) || sharedKey.length !== 32) throw Error('invalidCellularConfig');
  if (!Number.isInteger(port) || port < 0 || port > 65535) throw Error('invalidPort');
  if (host !== '127.0.0.1' && host !== '::1' && !publicBindAcknowledged)
    throw Error('publicBindNeedsExplicitAcknowledgement');
  const verify = createHeartbeatVerifier({ key: sharedKey });
  const server = createHttpsServer({
    key: tlsKey, cert: tlsCert, minVersion: 'TLSv1.2',
    requestCert: false
  }, (req, res) => {
    const reply = (status, value) => {
      res.writeHead(status, {
        'content-type': 'application/json; charset=utf-8',
        'cache-control': 'no-store', 'x-content-type-options': 'nosniff'
      });
      res.end(JSON.stringify(value));
    };
    if (req.url !== HEARTBEAT_PATH) return reply(404, failure(404).body);
    if (req.method !== 'POST') return reply(405, failure(405).body);
    if (Number(req.headers['content-length']) > MAX_BODY) return reply(413, failure(413).body);
    let len = 0;
    const chunks = [];
    req.on('data', chunk => {
      len += chunk.length;
      if (len > MAX_BODY) { req.destroy(); return; }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (len > MAX_BODY) return;
      const result = verify({
        method: req.method, url: req.url, headers: req.headers,
        body: Buffer.concat(chunks), secure: req.socket.encrypted === true
      });
      reply(result.status, result.body);
    });
    req.on('error', () => { if (!res.headersSent) res.destroy(); });
  });
  server.requestTimeout = 10000;
  server.headersTimeout = 7000;
  server.keepAliveTimeout = 1000;
  return {
    server,
    async listen() {
      await new Promise((resolve, reject) => {
        server.once('error', reject);
        server.listen(port, host, resolve);
      });
      return { host, port: server.address().port };
    },
    close() {
      return new Promise((resolve, reject) =>
        server.close(err => err ? reject(err) : resolve()));
    }
  };
}

export async function startFromEnvironment(env = process.env) {
  const required = ['IGENTIC_CELLULAR_TLS_KEY_FILE', 'IGENTIC_CELLULAR_TLS_CERT_FILE',
    'IGENTIC_CELLULAR_SHARED_KEY_FILE'];
  if (required.some(name => !env[name])) throw Error('missingCellularConfig');
  const keyPath = env.IGENTIC_CELLULAR_SHARED_KEY_FILE;
  const permissions = await stat(keyPath);
  if (!permissions.isFile() || (permissions.mode & 0o077) !== 0)
    throw Error('cellularKeyMustBePrivate');
  const host = env.IGENTIC_CELLULAR_LISTEN_HOST || '127.0.0.1';
  const port = Number(env.IGENTIC_CELLULAR_LISTEN_PORT || 37866);
  const gateway = createCellularGateway({
    tlsKey: await readFile(env.IGENTIC_CELLULAR_TLS_KEY_FILE),
    tlsCert: await readFile(env.IGENTIC_CELLULAR_TLS_CERT_FILE),
    sharedKey: decodeSharedKey(await readFile(keyPath, 'utf8')),
    host, port,
    publicBindAcknowledged: env.IGENTIC_CELLULAR_PUBLIC_BIND_ACK
      === 'I_ACCEPT_PUBLIC_HTTPS_EXPOSURE'
  });
  return { ...gateway, address: await gateway.listen() };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  startFromEnvironment()
    .then(g => {
      console.error('iGentic cellular HTTPS readiness gateway started on ' +
        (g.address.host === '127.0.0.1' ? 'loopback' : 'configured-host'));
    })
    .catch(e => {
      console.error(e.message?.startsWith('missing') ? 'missingCellularConfig' : 'cellularGatewayStartFailed');
      process.exitCode = 1;
    });
}
