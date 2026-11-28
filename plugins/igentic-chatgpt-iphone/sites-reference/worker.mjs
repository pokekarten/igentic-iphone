import html from './index.html';
import kiLoopHtml from './ki-loop.html';
import consoleHtml from './console.html';
import consoleClient from './operator-console.js.txt';
import { handleSitesMcp } from './mcp-handler.mjs';

// Fixed, manual help routes used by the observed mobile plugin. No caller
// input is interpolated into HTML, and a help visit never executes an action.
const handoffGuides = new Map([
  ['/handoff/diagnostics', ['Diagnose öffnen', 'igentic://handoff/v1/diagnostics']],
  ['/handoff/discovery', ['Lokale Entdeckungen öffnen', 'igentic://handoff/v1/discovery']],
  ['/handoff/reminder-draft', ['Erinnerungsentwurf prüfen', 'igentic://handoff/v1/reminder-draft']]
]);
function handoffGuide([title, link]) {
  return new Response(`<!doctype html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>iGentic – ${title}</title></head><body><main><h1>${title}</h1><p>Öffne die signierte iGentic-App und bestätige die Navigation dort selbst. Diese Anleitung prüft keine Verbindung und führt keine Aktion aus.</p><p><a href="${link}">${title}</a></p><p>Ein Erinnerungsentwurf erfordert eine separate Freigabe in der App. Es gibt keinen automatischen Rückkanal zu ChatGPT.</p><p><a href="/">Zurück zur Übersicht</a></p></main></body></html>`, { headers: {
    'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store',
    'x-content-type-options': 'nosniff', 'referrer-policy': 'no-referrer',
    'content-security-policy': "default-src 'none'; connect-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
  } });
}

// Bundle with the existing esbuild dependency and its .html text loader.
export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === '/mcp') return handleSitesMcp(request);
    const guide = handoffGuides.get(url.pathname);
    if (guide && request.method === 'GET'
        && (!url.search || url.search === '?utm_source=chatgpt.com')) {
      return handoffGuide(guide);
    }
    // ChatGPT appends this exact attribution parameter to shared links.
    // Reject all other query data; never interpolate URL input into HTML.
    if (url.pathname === '/ki-loop' && request.method === 'GET'
        && (!url.search || url.search === '?utm_source=chatgpt.com')) {
      return new Response(kiLoopHtml, { headers: {
        'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store',
        'x-content-type-options': 'nosniff', 'referrer-policy': 'no-referrer',
        'content-security-policy': "default-src 'none'; style-src 'unsafe-inline'; connect-src 'none'; img-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
      } });
    }
    if (url.pathname === '/console' && !url.search && request.method === 'GET') {
      return new Response(consoleHtml, { headers: {
        'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store',
        'x-content-type-options': 'nosniff', 'referrer-policy': 'no-referrer',
        'content-security-policy': "default-src 'none'; script-src 'self'; style-src 'unsafe-inline'; connect-src 'self'; img-src 'none'; form-action 'none'; base-uri 'none'; frame-ancestors 'none'"
      } });
    }
    if (url.pathname === '/console.js' && !url.search && request.method === 'GET') {
      return new Response(consoleClient, { headers: {
        'content-type': 'text/javascript; charset=utf-8',
        'cache-control': 'no-store', 'x-content-type-options': 'nosniff',
        'referrer-policy': 'no-referrer'
      } });
    }
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
