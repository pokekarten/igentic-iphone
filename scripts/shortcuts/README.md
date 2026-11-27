# iGentic Shortcut Factory — bounded status-loop candidate

This is the first local-only authoring slice, not an installed Shortcut. It targets the two existing iOS 27 App Intents, rather than inventing actions or modifying a user's Shortcuts database.

1. Build the current iGentic app with Xcode. Use the actual build's metadata; old DerivedData may contain only the diagnostics intent.
2. Preflight: `python3 scripts/shortcuts/status_loop_factory.py --metadata /path/to/iGentic.app/Metadata.appintents/extract.actionsdata`.
3. For an already signed development build, create a **new unsigned candidate**: `python3 scripts/shortcuts/status_loop_factory.py --app /path/to/iGentic.app --output /local/private/iGentic-status-unsigned.shortcut`. The parent directory must exist. No overwrite; the team identity is read from the local signature and never printed. Do not commit generated files.
4. Review the candidate plist and the AppIntent descriptor encoding against a real owner-exported Shortcut. The serialization is a hypothesis pending iOS import and runtime verification. Do not sign or install it merely because structural tests pass.
5. After review and explicit owner authorization, use Apple's `shortcuts sign --mode people-who-know-me --input /local/private/iGentic-status-unsigned.shortcut --output /local/private/iGentic-status.shortcut`, then use the system import UI. Do not bypass signing/consent. Verify iCloud synchronization separately, not from presence on the Mac.
6. Run on the physical iPhone once after verifying no pending status task. Verify the same task ID in the final finished result via the existing local `iphone_shortcut_result` tool and record only fixed booleans. Unknown results must not be blindly repeated.

The five actions are Start, parse JSON dictionary, extract taskId, Advance with fixed `status.read`, Advance with fixed `finish`. No model call, external observation sharing, arbitrary action or write to personal data is included. This is intentionally separate from the ChatGPT model action. The subsequent model-backed flow must send only the approved prompt, never automatically send the private local status observation.

Tests: `python3 -m unittest discover -s scripts/shortcuts -p 'test_*.py'`. Fixture success is not a physical acceptance pass. The generated unsigned plist contains a local signing-team identifier, so keep it private.

The preflight also checks the observed Xcode 27 String/Bool parameter and return types, non-optional parameters and background mode. The repository audit runs these fixture tests. Output is created exclusively with mode 0600; no existing file or symlink is overwritten.

## Setup Manager

Run the read-only status check with explicit paths to the signed app, private artifact directory and private iCloud folder:

    python3 scripts/shortcuts/setup_manager.py --app /path/to/iGentic.app --local /private/artifacts --cloud '/path/to/iCloud Drive/iGentic Setup'

Add `--prepare` to generate and Apple-sign missing local files, recording their digests; add `--publish` to stage the recorded signed artifact without replacing a conflicting file. Existing unrecorded artifacts can be inspected but are not automatically republished. The manager returns only fixed booleans and the next setup gate, not private library names or signing identifiers. The local manifest records the factory run and bytes; it is not an independent Apple signature attestation. iCloud upload is checked through Foundation metadata. A Mac library match is not proof of iPhone import; system import, owner authorization and the physical two-turn acceptance remain separate gates. The manager never invokes the Shortcut, accepts dialogs or modifies the Shortcuts database.


## Separate native diagnostic result candidate

Use `--kind agent-result` with the same metadata preflight or signed app
candidate generation command. The new, distinct candidate invokes only
`iGenticRunLocalDiagnosticAgentIntent` (discoverable, background, zero
parameters, String output) and Show Result. Attachment-valued slots use
`WFTextTokenAttachment`; the Show Result text slot uses
`WFTextTokenString` with U+FFFC, range `{0, 1}` and the exact native output UUID.
The existing five-action status-loop factory and Setup Manager are unchanged.
A separate manually authored candidate completed a physical diagnostic journal,
but visible result text was not independently confirmed. These fixtures
validate serialization, not system display. Do not retry an uncertain run,
automatically sign/import this candidate, or treat a journal as display proof.
