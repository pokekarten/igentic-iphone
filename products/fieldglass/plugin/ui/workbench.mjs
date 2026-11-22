import { App } from '@modelcontextprotocol/ext-apps';

const app = new App({name:'Fieldglass',version:'0.1.0'}, {});
const prepare = document.querySelector('#prepare');
const compare = document.querySelector('#compare');
const handoff = document.querySelector('#handoff');
const deliver = document.querySelector('#deliver');
const prepared = document.querySelector('#prepared');
const comparison = document.querySelector('#comparison');
const labels = {manual:'Manuelle Übergabe', simulator:'iOS-Simulator', device:'iPhone am Mac', 'configuration-error':'Kanalauswahl prüfen'};
let channel = 'manual';
let experiment;

app.ontoolresult = ({structuredContent}) => {
  channel = structuredContent?.channel ?? 'manual';
  document.querySelector('#channel').textContent = labels[channel] ?? 'Unbekannter Kanal';
  deliver.hidden = !['simulator','device'].includes(channel);
};

async function call(name, args) {
  const response = await app.callServerTool({name, arguments:args});
  if (response.isError || !response.structuredContent) throw Error();
  return response.structuredContent;
}

let revision = 0;
function resetExperiment() {
  revision++;
  experiment = undefined;
  handoff.hidden = true;
  prepared.textContent = '';
}
prepare.addEventListener('input', resetExperiment);
prepare.addEventListener('submit', async event => {
  event.preventDefault();
  resetExperiment();
  const token = revision;
  const args = Object.fromEntries(new FormData(prepare));
  const button = prepare.querySelector('button');
  button.disabled = true;
  try {
    const result = await call('prepare_experiment', args);
    if (token !== revision) return;
    experiment = {experimentId:result.experimentId,...args};
    document.querySelector('#link').value = result.link;
    handoff.hidden = false;
    deliver.disabled = false;
    prepared.textContent = 'Auftrag bereit.';
  } catch {
    if (token === revision) prepared.textContent = 'Auftrag konnte nicht erstellt werden. Suchtext und Verbindung prüfen.';
  } finally {button.disabled = false;}
});
deliver.addEventListener('click', async () => {
  if (!experiment || !['device','simulator'].includes(channel)) return;
  const token = revision;
  deliver.disabled = true;
  try {
    const result = await call('deliver_experiment', experiment);
    if (token !== revision) return;
    prepared.textContent = result.status === 'submitted' ? 'Übergabe angenommen. Prüfung in Fieldglass starten.'
      : result.status === 'device-unavailable' ? 'Das ausgewählte iPhone ist nicht erreichbar.'
      : 'Ausgang der Übergabe unklar. Auf dem Gerät prüfen.';
  } catch {
    if (token === revision) prepared.textContent = 'Ausgang der Übergabe unklar. Auf dem Gerät prüfen.';
  }
});

let compareRevision = 0;
compare.addEventListener('input', () => {compareRevision++; comparison.textContent = '';});
compare.addEventListener('submit', async event => {
  event.preventDefault();
  const token = ++compareRevision;
  const button = compare.querySelector('button');
  button.disabled = true;
  comparison.textContent = '';
  try {
    const result = await call('compare_results', Object.fromEntries(new FormData(compare)));
    if (token !== compareRevision) return;
    const outcome = {match:'Treffer','no-match':'Kein Treffer'};
    comparison.textContent = [outcome[result.before],outcome[result.after]].join(' → ') +
      (result.changed ? ' · Ergebnis geändert.' : ' · Gleiches Ergebnis.');
  } catch {
    if (token === compareRevision) comparison.textContent = 'Vergleich fehlgeschlagen. Zwei verschiedene Berichte desselben Auftrags und die Verbindung prüfen.';
  } finally {button.disabled = false;}
});
try {
  await app.connect();
  for (const form of [prepare,compare]) form.querySelector('button').disabled = false;
} catch {
  document.querySelector('#channel').textContent = 'Verbindung zum MCP-Host fehlt.';
}
