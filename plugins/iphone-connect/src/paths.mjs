import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// Shared path without a server/catalog circular import. Never use caller input.
export const ROOT = dirname(dirname(fileURLToPath(import.meta.url)));
