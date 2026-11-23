# First-party iGentic local workspace V0

Status: offline implementation; physical iPhone acceptance remains pending.
Research inspiration: OpenMinis, Pocket Agent, virtual workspace patterns. No upstream source copied.

- Native iOS app: `Offline-Werkzeuge → Notizen lokal verwalten`.
- Owner-private Application Support/iGentic/LocalWorkspace, app sandbox only.
- ASCII note names (1–32 letters/numbers/underscore/hyphen), fixed .txt extension, max 8192 UTF-8 bytes; rejects controls, traversal, symlinks and invalid data.
- Explicit user flow: `Änderung prüfen` (old/new plaintext on device), then `Diese Version lokal speichern`. Changed files invalidate a previous preview.
- Never exposes a shell, arbitrary file path, remote file API or automatic cloud sync. No deletion or execution tool.
- Files set to 0600 and iOS complete data protection. These do not defend against a compromised OS.
- MCP local plan `workspace-note` advertises manual navigation only, never returns personal note text, phone status or execution success.
- Validation: SwiftPM macOS unit tests, iOS simulator compilation, Node protocol tests; real signed iPhone UX still requires hardware access.
- Limit: file-content comparison is a local UI stale-preview safeguard, not a multi-process transaction or authorization capability. Third-party model output cannot call apply.

Next: document import/export under explicit owner selection, cryptographic review receipts, crash journal and approval-bound app-specific actions. No generic cross-app UI permission is inferred.
