import { readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const input = join(root, 'docs/explore/index.json');
const output = join(root, 'plugins/iphone-connect/catalog/business-solutions.json');
const expected = [
  'enterprise-agent-trust', 'field-evidence', 'insurance-risk',
  'device-fleet', 'private-model-evaluation', 'retail-inventory'
];

const source = JSON.parse(await readFile(input, 'utf8'));
const collection = source.collections?.find(c => c.slug === 'business-solutions');
if (source.schemaVersion !== 2 || !collection ||
    JSON.stringify(collection.topics) !== JSON.stringify(expected)) {
  throw new Error('businessCatalogSourceInvalid');
}
const topics = new Map(source.topics.map(t => [t.slug, t]));
const solutions = expected.map(slug => {
  const topic = topics.get(slug);
  if (!topic || !topic.title || !topic.summary ||
      !topic.bodyMarkdown?.includes('**Today:**') ||
      !topic.bodyMarkdown?.includes('**Missing before')) {
    throw new Error('businessCatalogTopicInvalid');
  }
  return {
    slug, title: topic.title, summary: topic.summary,
    detailMarkdown: topic.bodyMarkdown,
    status: 'research-prototype-or-proposal',
    executionEnabled: false
  };
});
const payload = JSON.stringify({
  schemaVersion: 1,
  source: 'bundled-public-igentic-explore',
  executionEnabled: false,
  solutions
}, null, 2) + '\n';

if (process.argv.slice(2).includes('--check')) {
  if (await readFile(output, 'utf8').catch(() => '') !== payload) {
    console.error('businessCatalogStale'); process.exitCode = 1;
  } else console.log('Business catalog projection up to date.');
} else {
  await writeFile(output, payload, 'utf8');
  console.log('Business catalog projection generated.');
}
