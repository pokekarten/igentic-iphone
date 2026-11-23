// Optional WebMCP browser-tab adapter. This is NOT a hosted ChatGPT Site
// plugin, an MCP HTTP server, or remote iPhone access. In browsers supporting
// document.modelContext, agents can request one fixed manual navigation link.
import { SITES_HANDOFF_TOOL, callSitesHandoffTool } from './handoff-site.mjs';

export async function registerReadOnlyBrowserHandoff(doc, { controller = new AbortController() } = {}) {
  // Never register tools in insecure contexts, untrusted frames, or when
  // WebMCP is missing. An iframe must not grant extra agent capabilities.
  if (!doc?.defaultView?.isSecureContext || doc.defaultView !== doc.defaultView.top ||
      !doc.modelContext || typeof doc.modelContext.registerTool !== 'function') {
    return { available: false, close: () => {} };
  }
  const descriptor = {
    name: SITES_HANDOFF_TOOL.name,
    title: SITES_HANDOFF_TOOL.title,
    description: SITES_HANDOFF_TOOL.description,
    inputSchema: SITES_HANDOFF_TOOL.inputSchema,
    execute: async (args, options) => {
      if (options?.signal?.aborted) throw new Error('browserToolCancelled');
      // Only computes the exact fixed link; NEVER opens it, clicks,
      // fetches or accesses any local phone content or other app.
      return callSitesHandoffTool(SITES_HANDOFF_TOOL.name, args);
    },
    annotations: { readOnlyHint: true, consequentialHint: false,
      untrustedContentHint: false }
  };
  try {
    await doc.modelContext.registerTool(descriptor, { signal: controller.signal });
  } catch {
    controller.abort();
    return { available: false, close: () => {} };
  }
  return {
    available: true,
    close: () => controller.abort()
  };
}
