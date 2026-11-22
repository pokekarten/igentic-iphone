import {build} from 'esbuild';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';

const ui = new URL('../ui/',import.meta.url);
let cachedCard;

async function renderCard() {
  const template = await readFile(new URL('workbench.html',ui),'utf8');
  const bundle = await build({
    entryPoints:[fileURLToPath(new URL('workbench.mjs',ui))],
    platform:'browser',format:'esm',bundle:true,minify:true,write:false
  });
  const script = bundle.outputFiles[0].text.replace(/<\/script/gi,'<\\/script');
  return template.replace('<!-- FIELDGLASS_SCRIPT -->',() => '<script type="module">'+script+'</script>');
}

export function workbenchCard() {
  cachedCard ??= renderCard().catch(error => {cachedCard = undefined; throw error;});
  return cachedCard;
}
