import html from './index.html';
import { handleSitesMcp } from './mcp-handler.mjs';

// Bundle with the existing esbuild dependency and its .html text loader.
export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === '/mcp') return handleSitesMcp(request);
    if (url.pathname === '/' && !url.search && request.method === 'GET') {
      return new Response(html, { headers: {
        'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store',
        'x-content-type-options': 'nosniff', 'referrer-policy': 'no-referrer',
        'content-security-policy': "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
      } });
    }
    return new Response('Not found', { status: 404 });
  }
};
