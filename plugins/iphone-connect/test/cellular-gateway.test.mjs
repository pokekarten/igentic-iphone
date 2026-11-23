import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { request } from 'node:https';
import { HEARTBEAT_BODY, HEARTBEAT_PATH, createCellularGateway,
  createHeartbeatVerifier, decodeSharedKey, signCellular } from '../src/cellular-gateway.mjs';

const key = Buffer.alloc(32, 0x01);
const timestamp = 1795393200;
const envelope = (nonce=randomUUID()) => ({
  method:'POST', url:HEARTBEAT_PATH, secure:true, body:HEARTBEAT_BODY,
  headers: {'x-igentic-timestamp':String(timestamp),
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
    {secure:false},{method:'GET'},{url:'/admin'},{body:Buffer.from('{"schema":1,"kind":"readiness","action":"tap"}')},
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
  const address=await gateway.listen();
  t.after(()=>gateway.close());
  assert.equal(address.host,'127.0.0.1');
  const post=(headers,body=HEARTBEAT_BODY,method='POST',path=HEARTBEAT_PATH)=>new Promise((resolve,reject)=>{
    const req=request({host:'127.0.0.1',port:address.port,method,path,
      ca:undefined,rejectUnauthorized:false,headers},resp=>{
      let text='';resp.setEncoding('utf8');
      resp.on('data',c=>text+=c);resp.on('end',()=>resolve({status:resp.statusCode,json:JSON.parse(text)}));
    });
    req.on('error',reject);req.end(body);
  });
  // The test-only client uses rejectUnauthorized:false for its throwaway
  // self-signed localhost certificate; the production Swift client NEVER does.
  const now=Math.floor(Date.now()/1000);const nonce=randomUUID();
  const headers={'x-igentic-timestamp':String(now),'x-igentic-nonce':nonce,
    'x-igentic-signature':signCellular({key,timestamp:now,nonce})};
  const ok=await post(headers);
  assert.equal(ok.status,200);assert.equal(ok.json.deviceControl,'not-enabled');
  assert.equal((await post(headers)).status,409);
  assert.equal((await post({...headers,'x-igentic-signature':'a'.repeat(64)})).status,401);
  assert.equal((await post(headers,HEARTBEAT_BODY,'GET')).status,405);
  assert.equal((await post(headers,HEARTBEAT_BODY,'POST','/something-else')).status,404);
});
