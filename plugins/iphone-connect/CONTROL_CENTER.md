# Local setup and acceptance runner

One bounded entrypoint for ChatGPT through an authorized Mac terminal and
Codex. This wraps the existing policy-gated local MCP harnesses, rather
than adding a second device controller or exposing a shell over MCP.

From `plugins/iphone-connect`, with Node 22+:

| Command | Scope |
|---|---|
| `npm run control -- plan` | Read-only plan, no device access |
| `npm run control -- prepare` | Install repository lockfile dependencies without lifecycle scripts |
| `npm run control -- doctor` | Read-only native and independent legacy discovery; report both even if one fails |
| `npm run control -- fixture` | Isolated fixture roundtrip; never counts as physical evidence |
| `npm run control -- wifi` | Explicit operator-run native physical Wi-Fi process launch, then own-app navigation/receipt test through an exclusive MCP session |
| `npm run control -- wifi-ui` | Independent legacy discovery gate, then existing bounded own-app MobileCLI smoke; not arbitrary UI control |
| `npm run control -- preview` | Separate operator-run physical first-party preview acceptance; only when no other agent is operating the app |

Use the physical modes only on the owner's configured iPhone and with the
owner's authorization. The native Wi-Fi process launch proves neither visible
UI nor current installed source identity. The native navigation smoke is an
own-app receipt test, not a HID tap. Legacy discovery is only a candidate, not
proof that MobileCLI used Wi-Fi. The preview route uses a local SDK client, not
a ChatGPT account. No mode claims a ChatGPT/Siri/Shortcuts account roundtrip.

Commands are allowlisted; no raw output or private identifiers are exported.
Physical modes clear backend override environment variables and never fall
back to fixtures. Uncertain actions must be independently inspected; do not
automatically retry. A nonpassing step yields exit 2. Run `node --test
test/control-center.test.mjs` for focused regression tests.

System permissions, account login, code signing/provisioning, actual Shortcut
import and the live ChatGPT model action remain explicit owner/system gates.
Do not use the CLI to bypass them. No public remote service or new API
credentials are necessary for the local modes.
