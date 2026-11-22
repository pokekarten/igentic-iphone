import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { ROOT } from './paths.mjs';
import { PluginError } from './process.mjs';

const allowedSlugs = Object.freeze([
  'enterprise-agent-trust', 'field-evidence', 'insurance-risk',
  'device-fleet', 'private-model-evaluation', 'retail-inventory'
]);

export async function readBusinessCatalog() {
  const raw = await readFile(join(ROOT, 'catalog/business-solutions.json'), 'utf8');
  const data = JSON.parse(raw);
  if (data.schemaVersion !== 1 || data.source !== 'bundled-public-igentic-explore' ||
      data.executionEnabled !== false || !Array.isArray(data.solutions) ||
      data.solutions.length !== allowedSlugs.length ||
      data.solutions.some((s, i) => s.slug !== allowedSlugs[i] ||
        s.executionEnabled !== false ||
        s.status !== 'research-prototype-or-proposal' ||
        typeof s.title !== 'string' || !s.title ||
        typeof s.summary !== 'string' || !s.summary ||
        typeof s.detailMarkdown !== 'string' ||
        !s.detailMarkdown.includes('**Today:**') ||
        !s.detailMarkdown.includes('**Missing before'))) {
    throw new PluginError('catalogInvalid');
  }
  return data;
}

export async function listBusinessSolutions() {
  const catalog = await readBusinessCatalog();
  return {
    schemaVersion: catalog.schemaVersion, source: catalog.source,
    executionEnabled: false, requiresDevice: false,
    solutions: catalog.solutions.map(({ slug, title, summary, status }) =>
      ({ slug, title, summary, status, executionEnabled: false }))
  };
}

export async function getBusinessSolution(slug) {
  if (!allowedSlugs.includes(slug)) throw new PluginError('unknownSolution');
  const catalog = await readBusinessCatalog();
  const { title, summary, detailMarkdown, status } = catalog.solutions.find(s => s.slug === slug);
  return {
    slug, title, summary, detailMarkdown, status,
    source: catalog.source, executionEnabled: false, requiresDevice: false,
    backendConnected: false, customerReady: false
  };
}
