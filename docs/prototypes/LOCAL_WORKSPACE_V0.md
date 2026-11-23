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

## Physical-device acceptance checklist (not yet executed)

1. On the owner's signed iOS 27 build, open Offline-Werkzeuge and Notizen lokal verwalten with Wi-Fi disconnected and no Mac attached.
2. Enter name `offline_test` and two lines of synthetic text. Verify that preview shows an empty previous version and that leaving the screen without saving creates no note.
3. Return, preview again, tap the explicit save button, reopen and verify the exact saved text.
4. Preview an edit, change the draft before saving, and ensure the stale preview is dismissed; separately verify oversize content and invalid filenames are rejected.
5. Verify that the ChatGPT-facing MCP `iphone_prepare_local_task` response for `workspace-note` is a manual plan only, including `deviceActionExecuted=false`, and never includes note content or a device receipt.

Record the exact GitHub head, app signing context, OS version and only redacted synthetic evidence; do not mark the feature as physically accepted based on the simulator build.
