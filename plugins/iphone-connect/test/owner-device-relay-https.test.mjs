import test from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes,randomUUID,X509Certificate} from 'node:crypto';
import {mkdtempSync,mkdirSync,readFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFile,spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {request} from 'node:https';
import {createOwnerDeviceRelay} from '../src/owner-device-relay.mjs';
import {createLoopbackOwnerDeviceHTTPS} from '../src/owner-device-relay-https.mjs';
import {provisionPrivateReplayLedger} from '../src/durable-task-admission.mjs';
import {signReadOnlyDeviceKeyReceipt} from '../src/agent-loop-protocol.mjs';

async function startTestRelay(t) {
  const root=mkdtempSync(join(tmpdir(),'igentic-relay-https-'));
  t.after(()=>rmSync(root,{recursive:true,force:true}));
  const databasePath=join(root,'replay.sqlite'),markerDirectory=join(root,'attempts');
  mkdirSync(markerDirectory,{mode:0o700});
  const [ownerAccessKey,deviceAccessKey,proposalKey,receiptKey,markerKey]=
    Array.from({length:5},()=>randomBytes(32));
  const now=2000000000;
  provisionPrivateReplayLedger({key:proposalKey,databasePath});
  const relay=createOwnerDeviceRelay({ownerAccessKey,deviceAccessKey,proposalKey,receiptKey,
    markerKey,databasePath,markerDirectory,nowSeconds:()=>now});
  t.after(()=>relay.close(ownerAccessKey));
  const keyPath=join(root,'tls.key'),certPath=join(root,'tls.crt');
  assert.equal(spawnSync('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-days','1',
    '-keyout',keyPath,'-out',certPath,'-subj','/CN=localhost','-addext',
    'subjectAltName=IP:127.0.0.1','-addext','extendedKeyUsage=serverAuth',
    '-addext','basicConstraints=critical,CA:FALSE','-addext','keyUsage=critical,digitalSignature,keyEncipherment'],{timeout:15000,stdio:'ignore'}).status,0);
  const cert=readFileSync(certPath);
  const gateway=createLoopbackOwnerDeviceHTTPS({relay,tlsKey:readFileSync(keyPath),tlsCert:cert});
  const address=await gateway.listen();
  t.after(()=>gateway.close());
  assert.equal(address.host,'127.0.0.1');
  const post=(path,key,body={},options={})=>new Promise((resolve,reject)=>{
    const wire=typeof body==='string'?body:JSON.stringify(body);
    const req=request({host:address.host,port:address.port,path,method:options.method??'POST',
      ca:cert,rejectUnauthorized:true,agent:false,
      headers:{authorization:'Bearer '+key.toString('hex'),'content-type':'application/json',
        'content-length':Buffer.byteLength(wire),...options.headers}},res=>{
      let text='';res.setEncoding('utf8');res.on('data',c=>text+=c);
      res.on('end',()=>resolve({status:res.statusCode,body:JSON.parse(text),cache:res.headers['cache-control']}));
    });
    req.on('error',reject);req.end(wire);
  });
  return {root, address, cert, post, owner:ownerAccessKey, device:deviceAccessKey, proposalKey, receiptKey, now};
}

test('real loopback TLS: strict owner/device roles, one claim, nonce receipt and denied malformed requests',async t=>{
  const {post, owner, device, receiptKey, now} = await startTestRelay(t);
  const id = randomUUID();
  assert.equal((await post('/v1/owner/status',device)).status,403);
  assert.equal((await post('/v1/owner/status',randomBytes(32))).status,403);
  assert.equal((await post('/v1/owner/status',owner,{}, {headers:{origin:'https://example.invalid'}})).status,403);
  assert.equal((await post('/v1/owner/status',owner,{}, {headers:{'x-forwarded-host':'example.invalid'}})).status,403);
  assert.equal((await post('/v1/owner/status?debug=1',owner)).status,404);
  assert.equal((await post('/v1/owner/status',owner,{}, {method:'GET'})).status,405);
  assert.equal((await post('/v1/owner/status',owner,{}, {headers:{'content-type':'text/plain'}})).status,415);
  assert.equal((await post('/v1/owner/status',owner,{}, {headers:{authorization:'Bearer wrong'}})).status,401);
  assert.equal((await post('/v1/owner/status',owner,' '.repeat(2049))).status,413);
  assert.equal((await post('/v1/owner/submit',owner,'{"requestId":"'+id+'","requestId":"'+id+'"}')).status,400);
  assert.equal((await post('/v1/owner/submit',owner,{requestId:id,approved:true})).status,400);
  assert.equal((await post('/v1/device/claim',device)).body.result,null);
  const start=await post('/v1/owner/submit',owner,{requestId:id});
  assert.equal(start.status,200);
  assert.equal(start.cache,'no-store');
  assert.equal(start.body.result.state,'awaiting-manual-delivery');
  assert.equal((await post('/v1/device/claim',owner)).status,403);
  const [a,b]=await Promise.all([post('/v1/device/claim',device),post('/v1/device/claim',device)]);
  const deliveries=[a,b].map(x=>x.body.result).filter(Boolean);
  assert.equal(deliveries.length,1);
  const delivery=deliveries[0];
  assert.equal(JSON.parse(delivery.canonicalWire).body.requestId,id);
  const status=await post('/v1/owner/status',owner);
  assert.equal(status.body.result.state,'outcome-unknown');
  assert.equal(status.body.result.receiptNonce,undefined);
  assert.equal((await post('/v1/owner/cancel',owner,{requestId:id})).status,409);
  const proof=signReadOnlyDeviceKeyReceipt({key:receiptKey,requestId:id,nonce:delivery.receiptNonce,observedAt:now});
  assert.equal((await post('/v1/device/receipt',owner,{proof})).status,403);
  const accepted=await post('/v1/device/receipt',device,{proof});
  assert.equal(accepted.status,200);
  assert.equal(accepted.body.result.receiptKeyAuthenticated,true);
  assert.equal(accepted.body.result.actionExecuted,false);
  assert.equal(accepted.body.result.ownerApproved,false);
  assert.equal(accepted.body.result.iPhoneConnected,'not-checked');
  const afterReceipt = await post('/v1/owner/status', owner);
  assert.equal(afterReceipt.body.result.requestId, id);
  assert.equal(afterReceipt.body.result.state, 'receipt-key-authenticated');
  assert.equal(afterReceipt.body.result.receiptKeyAuthenticated, true);
  assert.equal(afterReceipt.body.result.deviceReceipt, 'key-authenticated-not-device-attested');
  assert.equal((await post('/v1/device/receipt',device,{proof})).status,409);
  assert.equal((await post('/v1/owner/recover',owner,{requestId:id})).body.result.state,'outcome-unknown');
});

test('macOS native client refuses untrusted TLS and the Swift protocol accepts a live, test-trusted claim',
  {skip: process.platform !== 'darwin'}, async t => {
    const {root, address, cert, post, owner, device, proposalKey, now} = await startTestRelay(t);
    const binary = join(root, 'native-claim-smoke');
    const source = path => fileURLToPath(new URL(path, import.meta.url));
    const compile = spawnSync('xcrun', ['swiftc', '-parse-as-library',
      source('../../../ios/Sources/iGenticApp/AgentLoopRemoteTaskVerifier.swift'),
      source('../../../ios/Sources/iGenticApp/AgentLoopRelayClaimClient.swift'),
      source('./fixtures/NativeRelayClaimSmoke.swift'), '-o', binary],
      {encoding: 'utf8', timeout: 120000});
    assert.equal(compile.status, 0, compile.stderr || compile.error?.message);
    const requestID = randomUUID();
    assert.equal((await post('/v1/owner/submit', owner, {requestId:requestID})).status, 200);
    // Keep synthetic role credentials in an anonymous pipe, out of command arguments and logs.
    const input = {requestID, now, port:address.port, certificate:new X509Certificate(cert).raw.toString('base64'),
      deviceKey:device.toString('base64'), proposalKey:proposalKey.toString('base64')};
    await new Promise((resolve, reject) => {
      const child = execFile(binary, [], {timeout: 25000}, error => error ? reject(error) : resolve());
      child.stdin.on('error', reject);
      child.stdin.end(JSON.stringify(input));
    });
    const status = (await post('/v1/owner/status', owner)).body.result;
    assert.equal(status.requestId, requestID);
    assert.equal(status.state, 'outcome-unknown');
    assert.equal(status.actionExecuted, false);
    assert.equal((await post('/v1/device/claim', device)).body.result, null);
  });
