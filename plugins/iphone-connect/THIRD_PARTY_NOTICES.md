# Third-party components

iGentic source remains under the repository Apache-2.0 license.

- `@modelcontextprotocol/sdk` 1.32.2: MIT; protocol server/client.
- `@modelcontextprotocol/ext-apps` 2.0.4: MIT; MCP Apps UI bridge.
- `zod` 4.3.6: MIT; strict input/output schemas.
- `esbuild` 0.28.2: MIT; development-time UI bundling.
- `playwright` 1.65.1: Apache-2.0; development-time browser testing.

`package-lock.json` pins resolved transitive versions and integrity hashes.
Runtime package archives retain dependency license files in `node_modules`.
Review the entire lockfile and artifacts before any public release.

MobileCLI 1.0.24 is **separate, operator-installed software**, not a bundled
dependency. Its observed npm package declares **FSL-1.1-ALv2**. Mobile MCP's
Apache-2.0 top-level license must not be confused with the underlying MobileCLI
license. No redistribution/commercial-usage clearance is asserted here. No
third-party iPhone runner, pairing record, provisioning profile, Apple developer
component, model weights, application artwork or upstream app source is bundled.
