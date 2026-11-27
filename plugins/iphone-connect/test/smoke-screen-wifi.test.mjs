import test from 'node:test';
import assert from 'node:assert/strict';
import { pngDimensions } from '../scripts/smoke-screen-wifi.mjs';
const header = () => {
  const b=Buffer.alloc(24);
  Buffer.from([137,80,78,71,13,10,26,10]).copy(b);
  b.writeUInt32BE(13,8); b.write('IHDR',12);
  b.writeUInt32BE(1260,16); b.writeUInt32BE(2736,20);
  return b;
};
test('only bounded PNG metadata is returned',()=>{
  assert.deepEqual(pngDimensions(header(),1000),{width:1260,height:2736});
  assert.throws(()=>pngDimensions(header(),32*1024*1024+1));
  assert.throws(()=>pngDimensions(Buffer.alloc(24),1000));
  const b=header(); b.writeUInt32BE(0,16);
  assert.throws(()=>pngDimensions(b,1000));
});
