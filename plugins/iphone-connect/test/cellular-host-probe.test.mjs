import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { createServer as createHttpsServer } from 'node:https';
import { mkdtemp, readFile, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { HEARTBEAT_PATH, createCellularGateway } from '../src/cellular-gateway.mjs';
import { parseOwnerHostEndpoint, probeOwnerCellularHost } from '../src/cellular-host-probe.mjs';
import { checkConfiguredHost } from '../scripts/smoke-cellular-host.mjs';

const key = Buffer.alloc(32, 1);
const fixed = JSON.stringify({
  schema:1, status:'accepted', capability:'readiness-only',
  deviceControl:'not-enabled', backgroundExecution:'not-guaranteed'
});

async function setupTLS(t) {
  const dir = await mkdtemp(join(tmpdir(), 'igentic-owner-host-probe-'));
  t.after(() => rm(dir, { recursive:true, force:true }));
  const cert = join(dir, 'cert.pem');
  const priv = join(dir, 'key.pem');
  const proc = spawnSync('openssl', [
    'req', '-x509', '-newkey', 'rsa:2048', '-sha256', '-nodes', '-days', '1',
    '-keyout', priv, '-out', cert, '-subj', '/CN=localhost',
    '-addext', 'subjectAltName=IP:127.0.0.1'
  ], { encoding:'utf8', timeout:15000 });
  assert.equal(proc.status, 0, 'throwaway test-only localhost certificate');
  return {
    ca:await readFile(cert), priv:await readFile(priv), dir
  };
}

test('owner endpoint is HTTPS with exact fixed path and no credentials or redirects', () => {
  assert.equal(parseOwnerHostEndpoint('https://example.org'+HEARTBEAT_PATH).pathname,
    HEARTBEAT_PATH);
  for (const url of [
    '', 'http://example.org'+HEARTBEAT_PATH, 'https://example.org/admin',
    'https://user:password@example.org'+HEARTBEAT_PATH,
    'https://example.org'+HEARTBEAT_PATH+'?key=oops',
    'https://example.org'+HEARTBEAT_PATH+'#hash',
    'file:///tmp/private', 'javascript:alert(1)', 'https://example.org'
  ]) assert.throws(() => parseOwnerHostEndpoint(url), /invalidOwnerEndpoint/);
});

test('default host smoke requires explicit configuration and never infers LTE', async () => {
  const result = await checkConfiguredHost({});
  assert.deepEqual(result, {
    status:'blocked', reason:'ownerHostConfigurationMissing',
    cellularVerified:false, iphoneAppVerified:false
  });
  assert.equal((await checkConfiguredHost({
    IGENTIC_CELLULAR_ENDPOINT:'https://example.org'+HEARTBEAT_PATH,
    IGENTIC_CELLULAR_SHARED_KEY_FILE:'/not/an/available/owner/key'
  })).reason,'privatePairingKeyRequired');
});

test('owner-host probe proves HTTPS and request-bound HMAC, but never cellular', async t => {
  const tls=await setupTLS(t);
  const server=createCellularGateway({
    tlsKey:tls.priv,tlsCert:tls.ca,sharedKey:key,port:0
  });
  const listening=await server.listen();
  t.after(()=>server.close());
  const endpoint='https://127.0.0.1:'+listening.port+HEARTBEAT_PATH;
  const report=await probeOwnerCellularHost({endpoint,sharedKey:key,ca:tls.ca});
  assert.deepEqual(report,{
    status:'authenticated-owner-host-readiness',proofVerified:true,
    route:'mac-network',cellularVerified:false,iphoneAppVerified:false,
    backgroundVerified:false
  });
  await assert.rejects(
    probeOwnerCellularHost({endpoint,sharedKey:key}),
    /ownerHostNetworkOrTLSFailed/,
    'untrusted localhost TLS cannot be silently bypassed'
  );
  await assert.rejects(
    probeOwnerCellularHost({endpoint,sharedKey:Buffer.alloc(32,2),ca:tls.ca}),
    /ownerHostRejected/
  );
  const nonce=randomUUID();
  assert.equal((await probeOwnerCellularHost({
    endpoint,sharedKey:key,ca:tls.ca,nonceFactory:()=>nonce
  })).proofVerified,true);
  await assert.rejects(probeOwnerCellularHost({
    endpoint,sharedKey:key,ca:tls.ca,nonceFactory:()=>nonce
  }),/ownerHostRejected/,'replayed nonce must be rejected');
});

test('reject authentic TLS if the JSON or request-bound response proof is false',async t=>{
  const tls=await setupTLS(t);
  let mode='missing-proof';
  const host=createHttpsServer({
    key:tls.priv,cert:tls.ca,minVersion:'TLSv1.2'
  },(req,res)=>{
    req.resume();
    if (mode==='redirect') {
      res.writeHead(302,{location:'https://example.org/'+HEARTBEAT_PATH}).end();
      return;
    }
    if (mode==='drip') {
      res.writeHead(200,{'content-type':'application/json; charset=utf-8'});
      res.flushHeaders();
      const timer = setInterval(() => res.write(' '),25);
      res.once('close',()=>clearInterval(timer));
      return;
    }
    const body=mode==='oversize'?'x'.repeat(700)
      : mode==='false-schema' ? JSON.stringify({ schema:1,status:'accepted',
          capability:'control',deviceControl:'enabled',backgroundExecution:'enabled' }) : fixed;
    const headers={
      'content-type':'application/json; charset=utf-8',
      ...(mode==='missing-proof'?{}:{'x-igentic-response-proof':'0'.repeat(64)})
    };
    res.writeHead(200,headers).end(body);
  });
  await new Promise((resolve,reject)=>{
    host.once('error',reject);host.listen(0,'127.0.0.1',resolve);
  });
  t.after(()=>new Promise(resolve=>host.close(resolve)));
  const endpoint='https://127.0.0.1:'+host.address().port+HEARTBEAT_PATH;
  for(const [next,expected] of [
    ['missing-proof','ownerHostProofInvalid'],
    ['false-schema','ownerHostResponseMalformed'],
    ['oversize','ownerHostResponseTooLarge'],
    ['redirect','ownerHostRejected'],
    ['drip','ownerHostTimeout']
  ]) {
    mode=next;
    await assert.rejects(
      probeOwnerCellularHost({endpoint,sharedKey:key,ca:tls.ca,
        timeoutMs:next==='drip'?1200:5000}),
      new RegExp(expected),next
    );
  }
});

test('key path must be a private regular file; symlink is not followed',async t=>{
  const tls=await setupTLS(t);
  const secret=join(tls.dir,'secret.key');
  await writeFile(secret,key.toString('base64')+'\n',{mode:0o600});
  const alias=join(tls.dir,'alias.key');
  await symlink(secret,alias);
  const report=await checkConfiguredHost({
    IGENTIC_CELLULAR_ENDPOINT:'https://example.org'+HEARTBEAT_PATH,
    IGENTIC_CELLULAR_SHARED_KEY_FILE:alias
  });
  assert.equal(report.status,'blocked');
  assert.equal(report.reason,'privatePairingKeyRequired');
});

test('unconfigured CLI prints only fixed blocked status, never host or secrets', () => {
  const cli = fileURLToPath(new URL('../scripts/smoke-cellular-host.mjs',import.meta.url));
  // Child process startup can be delayed substantially on a busy Mac.
  // This is a test harness deadline, not a network or security timeout.
  const proc=spawnSync(process.execPath,[cli], {
    env:{ PATH:process.env.PATH||'/usr/bin:/bin' },encoding:'utf8',timeout:30000
  });
  assert.equal(proc.status,2);
  const report=JSON.parse(proc.stdout.trim());
  assert.equal(report.status,'blocked');
  assert.equal(report.cellularVerified,false);
  assert.ok(!proc.stdout.includes('example.org'));
});
