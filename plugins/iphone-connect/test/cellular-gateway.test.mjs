import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { chmod, mkdtemp, readFile, rm, symlink, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { request } from 'node:https';
import { HEARTBEAT_BODY, HEARTBEAT_PATH, createCellularGateway,
  createHeartbeatVerifier, decodeSharedKey, signCellular, signCellularResponse, startFromEnvironment } from '../src/cellular-gateway.mjs';

const key = Buffer.alloc(32, 0x01);
const timestamp = 1795393200;
const envelope = (nonce=randomUUID()) => ({
  method:'POST', url:HEARTBEAT_PATH, secure:true, body:HEARTBEAT_BODY,
  headers: {'content-type':'application/json', 'x-igentic-timestamp':String(timestamp),
    'x-igentic-nonce':nonce, 'x-igentic-signature':signCellular({key,timestamp,nonce})}
});

test('strict first-party key parser and deterministic HMAC contract', () => {
  assert.deepEqual(decodeSharedKey(key.toString('base64')),key);
  assert.throws(()=>decodeSharedKey('test'),/invalidPrivateCellularKey/);
  assert.throws(()=>decodeSharedKey(Buffer.alloc(12).toString('base64')),/invalidPrivateCellularKey/);
  const nonce='11111111-2222-3333-4444-555555555555';
  assert.match(signCellular({key,timestamp,nonce}),/^[0-9a-f]{64}$/);
  assert.equal(signCellular({key,timestamp,nonce}),signCellular({key,timestamp,nonce}));
  assert.notEqual(signCellular({key,timestamp,nonce}),signCellular({key,timestamp:timestamp+1,nonce}));
});

test('server response proof binds exactly one readiness request', () => {
  const nonce = '11111111-2222-3333-4444-555555555555';
  const proof = signCellularResponse({ key, timestamp, nonce });
  assert.match(proof, /^[0-9a-f]{64}$/);
  assert.notEqual(signCellularResponse({ key, timestamp, nonce:randomUUID() }), proof);
  assert.notEqual(signCellularResponse({ key, timestamp:timestamp + 1, nonce }), proof);
  assert.notEqual(signCellularResponse({ key:Buffer.alloc(32, 2), timestamp, nonce }), proof);
  assert.throws(()=>signCellularResponse({ key, timestamp, nonce:'invalid' }),
    /invalidCellularEnvelope/);
});

test('valid readiness is authenticated, single-use, and allows NO remote action', () => {
  const verify=createHeartbeatVerifier({key,nowSeconds:()=>timestamp});
  const event=envelope();
  assert.deepEqual(verify(event),{status:200,body:{
    schema:1,status:'accepted',capability:'readiness-only',
    deviceControl:'not-enabled',backgroundExecution:'not-guaranteed'
  }});
  assert.equal(verify(event).status,409);
  assert.equal(verify(envelope()).status,200);
});

test('reject mismatched TLS, verb, route, timestamp, HMAC and unexpected body', () => {
  const check = e => createHeartbeatVerifier({key,nowSeconds:()=>timestamp})(e).status;
  const e=envelope();
  for(const patch of [
    {secure:false},{method:'GET'},{url:'/admin'},
    {headers:{...e.headers, 'content-type':'text/plain'}},
    {headers:{...e.headers, 'content-type':undefined}},
    {headers:{...e.headers, 'content-encoding':'gzip'}},
    {body:Buffer.from('{"schema":1,"kind":"readiness","action":"tap"}')},
    {body:Buffer.alloc(0)},{headers:{...e.headers,'x-igentic-timestamp':String(timestamp-61)}},
    {headers:{...e.headers,'x-igentic-timestamp':String(timestamp+61)}},
    {headers:{...e.headers,'x-igentic-signature':'0'.repeat(64)}},
    {headers:{...e.headers,'x-igentic-nonce':randomUUID()}},
    {headers:{...e.headers,'x-igentic-nonce':'not-a-uuid'}},
    {headers:{...e.headers,'x-igentic-signature':['0'.repeat(64)]}}
  ]) assert.notEqual(check({...e,...patch}),200);
});

test('gateway refuses implicit external/public binding, cleartext and invalid config', () => {
  assert.throws(()=>createCellularGateway({tlsKey:Buffer.from('a'),tlsCert:Buffer.from('b'),
    sharedKey:key,host:'0.0.0.0'}),/publicBindNeedsExplicitAcknowledgement/);
  assert.throws(()=>createCellularGateway({tlsKey:Buffer.from('a'),tlsCert:Buffer.from('b'),
    sharedKey:key,port:65536}),/invalidPort/);
  assert.throws(()=>createCellularGateway({tlsKey:Buffer.from('a'),tlsCert:Buffer.from('b'),
    sharedKey:Buffer.from('wrong')}),/invalidCellularConfig/);
});

test('real HTTPS listener accepts signed readiness, refuses replay and wrong auth',async t=>{
  const dir=await mkdtemp(join(tmpdir(),'igentic-cellular-tls-'));
  t.after(()=>rm(dir,{recursive:true,force:true}));
  const cert=join(dir,'cert.pem');const priv=join(dir,'key.pem');
  const r=spawnSync('openssl',['req','-x509','-newkey','rsa:2048','-sha256','-nodes',
    '-days','1','-keyout',priv,'-out',cert,'-subj','/CN=localhost',
    '-addext','subjectAltName=IP:127.0.0.1'],{encoding:'utf8',timeout:15000});
  assert.equal(r.status,0,'OpenSSL local throwaway TLS certificate for test');
  const gateway=createCellularGateway({tlsKey:await readFile(priv),tlsCert:await readFile(cert),
    sharedKey:key,port:0});
  assert.equal(gateway.server.maxConnections, 32);
  assert.equal(gateway.server.maxRequestsPerSocket, 10);
  const address=await gateway.listen();
  t.after(()=>gateway.close());
  assert.equal(address.host,'127.0.0.1');
  const post=(headers,body=HEARTBEAT_BODY,method='POST',path=HEARTBEAT_PATH)=>new Promise((resolve,reject)=>{
    const req=request({host:'127.0.0.1',port:address.port,method,path,
      ca:undefined,rejectUnauthorized:false,headers},resp=>{
      let text='';resp.setEncoding('utf8');
      resp.on('data',c=>text+=c);resp.on('end',()=>resolve({
        status:resp.statusCode,json:JSON.parse(text),
        responseProof:resp.headers['x-igentic-response-proof']
      }));
    });
    req.on('error',reject);req.end(body);
  });
  // The test-only client uses rejectUnauthorized:false for its throwaway
  // self-signed localhost certificate; the production Swift client NEVER does.
  const now=Math.floor(Date.now()/1000);const nonce=randomUUID();
  const headers={'content-type':'application/json','x-igentic-timestamp':String(now),'x-igentic-nonce':nonce,
    'x-igentic-signature':signCellular({key,timestamp:now,nonce})};
  const ok=await post(headers);
  assert.equal(ok.status,200);assert.equal(ok.json.deviceControl,'not-enabled');
  assert.equal(ok.responseProof, signCellularResponse({key,timestamp:now,nonce}));
  assert.equal((await post(headers)).responseProof, undefined);
  assert.equal((await post(headers)).status,409);
  const badSignature = await post({...headers,'x-igentic-signature':'a'.repeat(64)});
  assert.equal(badSignature.status,401);
  assert.equal(badSignature.responseProof, undefined);
  assert.equal((await post(headers,HEARTBEAT_BODY,'GET')).status,405);
  assert.equal((await post(headers,HEARTBEAT_BODY,'POST','/something-else')).status,404);
  assert.equal((await post({...headers,'content-type':'text/plain'})).status,415);
  assert.equal((await post({...headers,'content-encoding':'gzip'})).status,415);
  assert.equal((await post(headers,Buffer.alloc(513))).status,413);
  // Request body length greater than MAX_BODY cannot use a valid signature
  // or enter the per-nonce cache, even when sent with chunked transfer.
  assert.equal((await post({...headers,'transfer-encoding':'chunked'},Buffer.alloc(513))).status,413);
});

test('cellular host rejects group-readable TLS keys and symlinked secret files', async t => {
  const dir = await mkdtemp(join(tmpdir(), 'igentic-cellular-priv-file-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const shared = join(dir, 'shared.key');
  const tlsKey = join(dir, 'tls.key');
  const cert = join(dir, 'tls.crt');
  await writeFile(shared, key.toString('base64') + '\n', { mode: 0o600 });
  await writeFile(tlsKey, 'dummy-key', { mode: 0o600 });
  await writeFile(cert, 'dummy-cert', { mode: 0o600 });
  const env = {
    IGENTIC_CELLULAR_SHARED_KEY_FILE: shared,
    IGENTIC_CELLULAR_TLS_KEY_FILE: tlsKey,
    IGENTIC_CELLULAR_TLS_CERT_FILE: cert,
    IGENTIC_CELLULAR_LISTEN_HOST: '127.0.0.1'
  };
  await chmod(tlsKey, 0o644);
  await assert.rejects(startFromEnvironment(env), /cellularTLSKeyMustBePrivate/);
  await chmod(tlsKey, 0o600);
  await chmod(shared, 0o644);
  await assert.rejects(startFromEnvironment(env), /cellularKeyMustBePrivate/);
  await chmod(shared, 0o600);
  const alias = join(dir, 'shared-link.key');
  await symlink(shared, alias);
  await assert.rejects(startFromEnvironment({
    ...env, IGENTIC_CELLULAR_SHARED_KEY_FILE: alias
  }), /cellularKeyMustBePrivate/);
});
