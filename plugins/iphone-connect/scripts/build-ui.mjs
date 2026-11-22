import { build } from 'esbuild';
import { writeFile } from 'node:fs/promises';
import { ROOT } from '../src/server.mjs';
import { join } from 'node:path';
const result = await build({ entryPoints: [join(ROOT, 'ui/dashboard.mjs')], bundle: true,
  platform: 'browser', format: 'esm', minify: true, write: false });
const script = result.outputFiles[0].text.replace(/<\/script/gi, '<\\/script');
const html = `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>iGentic iPhone Connect</title><style>
:root{color-scheme:light dark;font:15px system-ui}body{margin:0;padding:24px;background:light-dark(#fafafa,#151719);color:light-dark(#182028,#f1f5f9)}
main{max-width:650px;margin:auto}h1{font-size:22px;margin:0 0 14px}p{line-height:1.6}#status{font-weight:650}button{font:inherit;border:1px solid #789;border-radius:10px;padding:10px 16px;margin:8px 8px 0 0;cursor:pointer}button:disabled{opacity:.45}button:focus-visible{outline:3px solid #478bff;outline-offset:3px}#stop{background:#982b28;color:white}small{display:block;margin-top:18px;opacity:.7}
</style><main><h1>iGentic iPhone Connect</h1><p id="status" role="status" aria-live="polite">Connecting…</p>
<p id="details">Diagnostics and bundled discovery. Session actions stay scoped to your test app.</p>
<button id="check">Check connections</button><button id="observe" disabled>Refresh status</button><button id="stop" disabled>Stop session</button>
<small>Stopping cancels pending work; it cannot undo an action already sent.</small></main><script type="module">${script}</script></html>`;
await writeFile(join(ROOT, 'ui/dashboard.html'), html.replace(/[ \t]+$/gm, ''));
console.log('MCP Apps dashboard built.');
