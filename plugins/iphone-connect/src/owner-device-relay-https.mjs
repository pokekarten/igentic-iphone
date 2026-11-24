// Loopback-only TLS transport for the local relay. No public bind, CLI,
// automatic startup, model/tool registration or account/device enrollment.
import { createServer } from 'node:https';

const MAX_BODY = 2048;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const PATHS = new Map([
  ['/v1/owner/submit','submit'], ['/v1/owner/status','status'],
  ['/v1/owner/result','result'], ['/v1/owner/cancel','cancel'], ['/v1/owner/recover','recover'],
  ['/v1/device/claim','claim'], ['/v1/device/receipt','acceptReceipt']
]);
const exact = (v, keys) => v !== null && typeof v === 'object' && !Array.isArray(v)
  && Object.keys(v).length === keys.length && keys.every(k => Object.hasOwn(v,k));

export function createLoopbackOwnerDeviceHTTPS({relay,tlsKey,tlsCert,port=0} = {}) {
  if (!relay || [...PATHS.values()].some(k=>typeof relay[k] !== 'function')
      || !Buffer.isBuffer(tlsKey) || !Buffer.isBuffer(tlsCert)
      || !Number.isInteger(port) || port < 0 || port > 65535)
    throw Error('invalidRelayHTTPSConfig');
  const server = createServer({key:tlsKey,cert:tlsCert,minVersion:'TLSv1.2',maxHeaderSize:4096},
    (req,res)=>{
      const reply = (status,body) => {
        res.writeHead(status,{'content-type':'application/json; charset=utf-8',
          'cache-control':'no-store','x-content-type-options':'nosniff',connection:'close'});
        res.end(JSON.stringify(body));
      };
      const deny = status => reply(status,{schema:1,status:'rejected'});
      if (req.socket.encrypted !== true || req.socket.remoteAddress !== '127.0.0.1'
          || req.headers.host !== '127.0.0.1:'+server.address()?.port
          || req.headers.origin !== undefined
          || Object.keys(req.headers).some(k=>k==='forwarded'||k.startsWith('x-forwarded-')))
        return deny(403);
      const method = PATHS.get(req.url);
      if (!method) return deny(404);
      if (req.method !== 'POST') return deny(405);
      const singletonHeaders = ['host','authorization','content-type','content-length','content-encoding'];
      for (const name of singletonHeaders) {
        let seen=0;
        for(let i=0;i<req.rawHeaders.length;i+=2) if(req.rawHeaders[i].toLowerCase()===name) seen++;
        if(seen>1) return deny(400);
      }
      const auth = typeof req.headers.authorization === 'string'
        ? /^Bearer ([0-9a-f]{64})$/.exec(req.headers.authorization) : null;
      if (!auth) return deny(401);
      if (req.headers['content-type'] !== 'application/json'
          || req.headers['content-encoding'] !== undefined) return deny(415);
      const length = req.headers['content-length'];
      if(req.headers['transfer-encoding']!==undefined || typeof length!=='string'
          || !/^[1-9][0-9]{0,4}$/.test(length)) return deny(411);
      if(Number(length)>MAX_BODY) return deny(413);
      let size=0, rejected=false;
      const chunks=[];
      req.on('data',chunk=>{
        if(rejected) return;
        size+=chunk.length;
        if(size>MAX_BODY || size>Number(length)){rejected=true;deny(413);return;}
        chunks.push(chunk);
      });
      req.on('aborted',()=>{rejected=true;});
      req.on('error',()=>{rejected=true;res.destroy();});
      req.on('end',()=>{
        if(rejected) return;
        if(size!==Number(length)) return deny(400);
        const wire=Buffer.concat(chunks);
        let input;
        try {
          input=JSON.parse(wire.toString('utf8'));
          // Byte-exact canonical JSON excludes duplicate fields, invalid UTF-8,
          // extra whitespace and alternate encodings before any transition.
          if(!Buffer.from(JSON.stringify(input)).equals(wire)) return deny(400);
        } catch { return deny(400); }
        const takesID=['submit','cancel','recover','result'].includes(method);
        const takesProof=method==='acceptReceipt';
        if(takesID ? (!exact(input,['requestId'])||typeof input.requestId!=='string'||!UUID.test(input.requestId))
            : takesProof ? !exact(input,['proof']) : !exact(input,[])) return deny(400);
        const key=Buffer.from(auth[1],'hex');
        try {
          const result=takesID ? relay[method](key,input.requestId)
            : takesProof ? relay[method](key,input.proof) : relay[method](key);
          return reply(200,{schema:1,result});
        } catch(error) {
          // Never echo credentials, signatures, untrusted input or local paths.
          return deny(error?.message==='relayAccessDenied'?403:409);
        } finally {key.fill(0);}
      });
    });
  server.maxConnections=16;
  server.maxRequestsPerSocket=1;
  server.requestTimeout=5000;
  server.headersTimeout=4000;
  server.keepAliveTimeout=500;
  // An inactivity timeout also bounds clients that stop mid-body.
  server.setTimeout(5000,socket=>socket.destroy());
  return Object.freeze({
    async listen(){
      await new Promise((resolve,reject)=>{
        server.once('error',reject);
        server.listen(port,'127.0.0.1',()=>{server.removeListener('error',reject);resolve();});
      });
      return Object.freeze({host:'127.0.0.1',port:server.address().port});
    },
    close(){
      return new Promise((resolve,reject)=>server.close(err=>err?reject(err):resolve()));
    }
  });
}
