// Explicit owner-host probe. This runs on the Mac/network, NOT the iPhone
// cellular radio. No remote commands, secrets in output, TLS bypass or redirects.
import { request as httpsRequest } from 'node:https';
import { randomUUID, timingSafeEqual } from 'node:crypto';
import { HEARTBEAT_BODY, HEARTBEAT_PATH, signCellular, signCellularResponse } from './cellular-gateway.mjs';

const MAX_REPLY_BYTES = 512;
const FIXED_REPLY_KEYS = ['backgroundExecution', 'capability', 'deviceControl', 'schema', 'status'];

function fail(code) {
  throw Error(code);
}

export function parseOwnerHostEndpoint(value) {
  if (typeof value !== 'string' || value.length > 2048) fail('invalidOwnerEndpoint');
  let parsed;
  try { parsed = new URL(value); } catch { fail('invalidOwnerEndpoint'); }
  if (parsed.protocol !== 'https:' || !parsed.hostname || parsed.username || parsed.password ||
      parsed.pathname !== HEARTBEAT_PATH || parsed.search || parsed.hash) {
    fail('invalidOwnerEndpoint');
  }
  return parsed;
}

function validResponseBody(body) {
  try {
    const value = JSON.parse(body.toString('utf8'));
    return value && typeof value === 'object' && !Array.isArray(value) &&
      JSON.stringify(Object.keys(value).sort()) === JSON.stringify(FIXED_REPLY_KEYS) &&
      value.schema === 1 && value.status === 'accepted' &&
      value.capability === 'readiness-only' &&
      value.deviceControl === 'not-enabled' &&
      value.backgroundExecution === 'not-guaranteed';
  } catch {
    return false;
  }
}

function responseProofValid(value, expected) {
  if (typeof value !== 'string' || !/^[0-9a-f]{64}$/.test(value)) return false;
  return timingSafeEqual(Buffer.from(value, 'hex'), Buffer.from(expected, 'hex'));
}

export async function probeOwnerCellularHost({
  endpoint, sharedKey, timeoutMs = 5000, nowSeconds = () => Math.floor(Date.now() / 1000),
  nonceFactory = randomUUID, ca
} = {}) {
  const url = parseOwnerHostEndpoint(endpoint);
  if (!Buffer.isBuffer(sharedKey) || sharedKey.length !== 32) fail('invalidOwnerPairingKey');
  if (!Number.isInteger(timeoutMs) || timeoutMs < 100 || timeoutMs > 30000)
    fail('invalidProbeTimeout');
  const timestamp = nowSeconds();
  const nonce = nonceFactory();
  // Validate nonce/timestamp before opening a socket; never log them.
  const signature = signCellular({ key: sharedKey, timestamp, nonce });
  const expectedProof = signCellularResponse({ key: sharedKey, timestamp, nonce });

  return new Promise((resolve, reject) => {
    let settled = false;
    let timedOut = false;
    let deadline;
    const finish = (status, result) => {
      if (settled) return;
      settled = true;
      clearTimeout(deadline);
      if (status === 'success') resolve({
        status: 'authenticated-owner-host-readiness',
        proofVerified: true,
        route: 'mac-network',
        cellularVerified: false,
        iphoneAppVerified: false,
        backgroundVerified: false
      });
      else reject(Error(result));
    };
    const options = {
      protocol: 'https:', hostname: url.hostname, port: url.port || 443,
      path: HEARTBEAT_PATH, method: 'POST', agent: false,
      rejectUnauthorized: true, headers: {
        'content-type': 'application/json',
        'content-length': HEARTBEAT_BODY.length,
        'x-igentic-timestamp': String(timestamp),
        'x-igentic-nonce': nonce,
        'x-igentic-signature': signature
      },
      // Only test callers may supply a private throwaway trust root.
      // The production CLI never passes this option.
      ...(ca === undefined ? {} : { ca })
    };
    const req = httpsRequest(options, res => {
      if (res.statusCode !== 200) {
        finish('failure', 'ownerHostRejected');
        res.destroy();
        return;
      }
      if (!['application/json', 'application/json; charset=utf-8'].includes(
        res.headers['content-type']
      )) {
        finish('failure', 'ownerHostResponseMalformed');
        res.destroy();
        return;
      }
      const chunks = [];
      let length = 0;
      res.on('data', chunk => {
        if (settled) return;
        length += chunk.length;
        if (length > MAX_REPLY_BYTES) {
          finish('failure', 'ownerHostResponseTooLarge');
          res.destroy();
          return;
        }
        chunks.push(chunk);
      });
      res.on('end', () => {
        if (settled) return;
        if (!validResponseBody(Buffer.concat(chunks))) {
          finish('failure', 'ownerHostResponseMalformed');
          return;
        }
        if (!responseProofValid(
          res.headers['x-igentic-response-proof'], expectedProof
        )) {
          finish('failure', 'ownerHostProofInvalid');
          return;
        }
        finish('success');
      });
      res.on('error', () => finish('failure', 'ownerHostNetworkOrTLSFailed'));
    });
    // Absolute deadline rather than a socket idle timeout: a hostile host
    // cannot evade it by trickling tiny chunks indefinitely.
    deadline = setTimeout(() => {
      timedOut = true;
      finish('failure', 'ownerHostTimeout');
      req.destroy();
    }, timeoutMs);
    req.on('error', () => finish('failure',
      timedOut ? 'ownerHostTimeout' : 'ownerHostNetworkOrTLSFailed'));
    req.end(HEARTBEAT_BODY);
  });
}
