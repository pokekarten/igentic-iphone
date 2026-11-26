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
| `npm run control -- screen` | Explicit local physical Wi-Fi screenshot metadata test; no image retained or exported; no touch, live stream or visible-app claim |
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

The screen mode starts only the configured own app via the existing MCP lease, checks fresh native view receipts and Wi-Fi before/after, then uses Xcode 27's documented screenshot command. A raw screen capture may contain personal data if the foreground changes; it is confined to a temporary local directory and removed in normal cleanup. It is not a general MCP capability.

Optional physical UI fallback (local operator only):

- Use a separate Python environment with [Open iPhone Use v0.2.0](https://github.com/semsturgut/open-iphone-use/tree/658a806a744502beb4181cca547aa590147ceeaf) (source pin) installed; do not register or expose its unrestricted server.
- Set `IGENTIC_OIU_PYTHON` to that environment's absolute Python executable.
- `npm run control -- ax` opens our own diagnostic app under its existing lease and reads only fixed accessibility markers.
- `npm run control -- touch` is a separate explicit physical test. It checks Wi-Fi, policy, fresh before/after screenshots, exactly one known own-app target, AX root/target process identity against the installed executable, and live AX admission, sends one touch, and verifies navigation. The authenticated CoreDevice display/HID session is still needed; continuous video delivery is not required for this bounded test. No raw image/tree leaves the local process. Never automatically repeat an unknown input outcome. No general cross-app control or permissions bypass is provided.

### Physical built-in App Shortcut (no iCloud import)

`npm run control -- shortcut` is an explicit local operator acceptance mode
using the same optional adapter environment. It verifies the installed
iGentic app name, the Apple Shortcuts process and the system library's Apps
section, enters the iGentic group, checks the exact registered read-only
`iGentic Status-Loop` tile and its known sibling actions, then taps that tile
once. It refuses to overwrite a pending task, accepts no permission dialogs,
and does not run custom shortcuts or an external model.

The baseline is an exact app-container journal or a successful targeted
directory listing showing its absence. A new finished UUID and bounded
creation time are required; the independent local MCP client then requests
`iphone_shortcut_result` with that exact UUID. Only fixed booleans leave the
local test process. No raw library, task ID, device identifiers or observation
text are exported. The local lease serializes cooperating tools, not human
activity; this is local device evidence, not cryptographic remote attestation.
If input was attempted but its result is unknown, stop and inspect, never
automatically re-tap. This does not verify custom Shortcut import, a model
reply, Siri voice, or a ChatGPT-account roundtrip.
