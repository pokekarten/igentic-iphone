# Seven uploaded upstream ZIP repositories: iGentic source audit (2026-11-22)

**Evidence class:** user-supplied source ZIPs inspected locally. This upgrades the existing [source atlas](IPHONE_AGENT_PROJECT_ATLAS.md) and the earlier [four-upstream review](UPLOADED_UPSTREAM_SOURCE_REVIEW_2026_11_22.md); it is not seven new project discoveries. No external code is vendored, installed or executed. No iPhone/Mac build, simulator run, model inference, Apple entitlement or physical device has been verified in this pass.

## Corpus and per-file verification

| Source snapshot | File count | Source ZIP SHA-256 | Key use |
| --- | ---: | --- | --- |
| [FluidAudio](https://github.com/FluidInference/FluidAudio) | 981 | `acf8c433b4b9a7fc9ca5f75747171c8188ad25535e93b2db1d003a3cbbb5e4ee` | Optional local STT/VAD |
| [Apple Foundation Models Utilities](https://github.com/apple/foundation-models-utilities) | 44 | `e9fcacd991637d4dd9c2e2ced4e7c751f23c01ea7b1e369dfb386e6f89622306` | iOS 27 native agent profiles |
| [iCTRL](https://github.com/OpenMinis/iCTRL) | 122 | `1cc47b61e7b6d07f7ecdd5270f652cf44c5af864788ee3571f58147e2171ef4e` | Standalone-on-phone XCTest lab |
| [ipb](https://github.com/ipbtools/ipb) | 122 | `7c0226d4518434314d76d8dcddb9aab952e548278cc5cafd666c4bad5617f98e` | macOS host device lab |
| [Pocket Agent](https://github.com/meshoklv/pocket-agent) | 221 | `c0892e414a5b562c8128a26a4d0d3fd68c01ed77e8b34e6500785fdec19b1f50` | One-shot diff-before-write pattern |
| [Resident](https://github.com/Jflick58/resident) | 1005 | `a2fee8ad2865295f8b9ebd02af8921968c0cf194ca3a7b2e61cc996075152c5b` | Local agent harness, selective tools, MLX, MCP |
| [Volocal](https://github.com/fikrikarim/volocal) | 51 | `f631619eef7de940cf943962bace31c98fd6618d229d1d2a4eeaaa13c87d7b11` | Streaming voice interaction pattern |

A *second* uploaded Apple ZIP was **byte-identical** to the first, verified via SHA-256; it contributes no new files. Totals: **8 ZIPs, 7 distinct snapshots, 2,546 files**, including **2,369 analyzable text** and **177 binary/asset** files. ZIP CRC valid, no path-traversal-style member names. Automated per-file inventory recorded path, SHA-256, size, type and static pattern counts. **1,738/1,738 Swift files** parsed using the Linux Swift **6.2.1 frontend**; **59/59 Python files** parsed as AST. JSON, JSONL, YAML and XML/Apple plists validated; Bash syntax checks passed for 28 checked scripts. Two Zsh scripts in ipb were **not checked** because Zsh is absent; using Bash to parse them would give misleading errors. **Parser success is not a build, type check or security audit.** Deeper semantic review was focused on entry points, model lifecycle, permission and action paths, device control, tests and manifests. A per-file CSV manifest is available as a separate user-facing audit artifact, not added to this app's source tree.

## Most useful new deep findings (in addition to the four-repo report)

### 1. Resident: learn its harness, do not inherit direct action authority

**Primary source:** uploaded [Jflick58/resident](https://github.com/Jflick58/resident) ZIP, Apache-2.0 top-level license; `project.yml`, `HarnessKit/Package.swift`, `HarnessMLX/Package.swift`, `Vendor/README.md`, `App/State/AppModel.swift`, `HarnessKit/Sources/HarnessKit/Core/Agent.swift`.

**Strong candidates for iGentic:** tools-on-demand `ToolShelf` via `ToolGroups.swift`, context trimming `ResultFit.swift`, turn resumption, explicit local model-fit budget `ModelFit.swift`, MCP OAuth/keychain connector handling, skills, locally run MLX and action/benchmark fixtures. Its architecture keeps the lightweight harness separate from `HarnessMLX`; that separation maps well to iGentic's existing safety kernel. It already uses **FluidAudio from version 0.18.3** for speech, so investigate its integration experience before creating a competing voice stack.

**P0 — authorization mismatch, directly observed code:** `Agent.swift` invokes `await tool.call(call.arguments)` (around line 253); `FileTools.swift` routes file edit/write to `Workspace`; `Workspace.swift` performs real `Data.write(to:)` mutations (around lines 452–510). Tool availability is configured by presets and opened groups, but **this execution path does not show an iGentic-style per-action immutable proposal and explicit one-shot approval**. Keep `PolicyEngine`, `AppActionCoordinator`, `ApprovalManager`, `SafeActionExecutionCapabilityLedger` and `AuditLog` entirely independent of the model and MCP adapter. A tool call is always a proposal, not permission.

**P0 — JavaScript resource isolation:** `HarnessKit/Sources/HarnessKit/Tools/JavaScriptTool.swift` starts `JSContext.evaluateScript` on a dedicated `Thread`, then a delayed callback resumes the waiting continuation after a default 5-second timeout. It **does not interrupt a CPU-bound JS loop**; a comment expressly says JavaScriptCore lacks an interrupt method. Its timeout message says the code was stopped, which is misleading for a runaway thread. Do not reuse this as a bounded execution sandbox. A separately killable runner with CPU/memory limits and explicit user consent is required for arbitrary code.

**P0 — model identity:** `HarnessKit/Sources/HarnessKit/Models/ModelDownloader.swift` uses a cache completeness check based on file size, downloading from `resolve/main`; `App/State/BackgroundDownloader.swift` also refers to `resolve/main`. This does **not** prove an immutable model revision or SHA-256. Align any adaptation with existing iGentic model-admission draft PRs [#383](https://github.com/pokekarten/igentic-iphone/pull/383) and [#385](https://github.com/pokekarten/igentic-iphone/pull/385), not a second downloader/security stack.

**P1 — file confinement test:** `Workspace.clean` rejects parent traversal; `url` constructs paths, while edit/write uses normal file URLs. The inspected write path does not itself show final target/symlink checks immediately before writing. Test malicious folder symlinks and destination swaps before considering workspace tools. This is an **unverified confinement risk**, not a demonstrated exploit.

**Other constraints:** local MLX does not make optional web/MCP or remote-model paths offline. Snapshot target is **iOS 18+**; it declares increased-memory-limit and background-GPU entitlements requiring actual signing/device evidence. Its vendored MLX-Swift-LM copy contains local changes and multiple upstream PR integrations (documented in `Vendor/README.md`), which raises ongoing maintenance/licensing/version provenance costs. Do **not** import the vendor subtree into iGentic merely to obtain tools-on-demand.

### 2. iCTRL: the most important phone-native automation experiment, not a normal App Intent

**Primary source:** uploaded [OpenMinis/iCTRL](https://github.com/OpenMinis/iCTRL) ZIP, Apache-2.0 top-level license; `README.md`, `project.yml`, `iCTRLUITests/ActionHandler.swift`, `iCTRLUITests/iCTRLUITests.swift`, `iCTRLKit/JSONRPCServer.swift`, `AuthManager.swift`, `SecureEnvelope.swift`, `iCTRLApp/DDI/`.

iCTRL runs a **long-lived XCUITest runner on the iPhone** exposing JSON-RPC at port 8200; an optional companion app helps install/remount the Developer Disk Image. In the source and README the listener is **localhost-only by default**, with separately enabled LAN/nearby access. Pairing requires an on-device grant, uses X25519-derived key exchange and HMAC-based authenticated envelopes; clients can be revoked. It has UI-element references that re-resolve with expiry, foreground checks, OCR fallback and diagnostic/circuit-breaker facilities. Unlike `ipb`, it is designed for an **agent on the phone to call the loopback runner after setup**, without a continuously running Mac.

**High-value bounded iGentic QA:** physical-device feasibility after signing/DDI, restore after restart/OS upgrade, stale element/alert mismatch, screen lock, user revocation, app-specific denylist, no-action-before-approval, no blanket "Allow all future taps" and an emergency stop. A single key to the iCTRL runner can grant broad device UI control; therefore *pairing permission is not per-action authorization*.

**Do not ship by assumption:** its runner relies on XCTest/private compatibility and is not equivalent to supported iOS App Intents or proof of App Store acceptance. DDI and signatures still matter. Custom envelope composition needs independent security testing and private/sensitive data redaction; the bundled `cli/ictrl` executable should not be executed or downloaded automatically. The observed source does not prove iPhone Air compatibility or sustained background availability. Keep it an **explicitly opted-in experimental/developer-mode adapter**, with deterministic policy above RPC.

### 3. Apple Foundation Models Utilities: optional iOS-27-only native skills/context

**Primary source:** uploaded [apple/foundation-models-utilities](https://github.com/apple/foundation-models-utilities) ZIP, Apache-2.0, `Package.swift` and `Sources/FoundationModelsUtilities/{History,Skills,LanguageModels}`.

The packaged version declares **swift-tools 6.2**, **iOS/macOS/watchOS/visionOS 27.0**. In contrast iGentic `ios/Package.swift` currently declares **Swift tools 6.0 and iOS 17.0**. Do **not** globally increase minimum deployment or add an unconditional package import without an explicit iOS-27 module/target design.

**Transferable utilities:** `DropCompletedToolCalls` and `RollingWindow` keep transcripts bounded; `SummarizeHistory` can compress long sessions; `Skills`/activation helpers support on-demand instructions and tool declarations; `ChatCompletionsLanguageModel` maps OpenAI-compatible HTTP endpoints into a Foundation Models `LanguageModel` interface. The ZIP contains 33 Swift source/test files including tests for SSE, history, tool calls and errors. iOS-27 native `DynamicProfile` is a better starting point than writing a parallel dynamic session framework.

**Privacy/authority stops:** `ChatCompletionsLanguageModel` may call a **remote** configured server; "Foundation Models" does not imply offline execution for this adapter. History summarization may send transcript contents to whichever model is supplied, including a network model. Dynamically activating a model-suggested Skill/tool must not grant privileges. Evaluate as an optional extension subject to existing privacy/data-classification policy and system availability checks.

## Prior four sources: reuse decisions unchanged, evidence improved

**[FluidAudio](https://github.com/FluidInference/FluidAudio)** (Apache-2.0 repository): optional pinned **ASR/VAD only** for German offline transcripts; review model/binary licenses, exact HF revision, cold-start/RAM and explicit microphone consent. Its cache does support remote-content hash checks when object IDs are provided, unlike simplistic size-only implementations. Keep TTS until basic STT is proven; compare with Resident's already existing FluidAudio integration.

**[Pocket Agent](https://github.com/meshoklv/pocket-agent)** (MIT): learn immutable diff-before-write, one-shot consumed preview, stale-file refusal, scoped-folder handling. Its test-only non-preview write bypass is not a production feature. Avoid importing the second agent kernel, optional remote model paths or elevated-memory entitlements. No XCTest source was present in the uploaded snapshot.

**[Volocal](https://github.com/fikrikarim/volocal)** (MIT): take UX ideas for listen → final transcript → response → cancel/barge-in. Do not copy its `@unchecked Sendable` shared audio bridge or aggregate readiness: `STTManager`/`TTSManager` can record failures while `VoicePipeline` still reports ready. Its FluidAudio fork and GGUF use mutable `main`, with weak hash-based model admission. No XCTest source in its snapshot.

**[ipb](https://github.com/ipbtools/ipb)** (MIT): **macOS-only** private CoreDevice/HID/AX QA tool for iOS 27+ devices, not phone-native production runtime. Valuable uncertain-action quarantine (`observeRequired`, `orphanPossible`), per-device locks and explicit separation of CLI-command success from app-level effect. Compare to existing [ARTEMIS PR #378](https://github.com/pokekarten/igentic-iphone/pull/378) only in a controlled test lab.

## Direct integration plan without duplicating existing iGentic PRs

1. **Accept/validate the existing safe target first:** [#380](https://github.com/pokekarten/igentic-iphone/pull/380) read-only native App Intent and [#381](https://github.com/pokekarten/igentic-iphone/pull/381) untrusted proposal gate; continue stacked #382/#384, #383/#385 and physical readiness #386/#388 in reviewed order. Do not merge this research PR to circumvent tests.
2. **First new narrow product change:** introduce an `iGenticSpeechInput` boundary with explicit mic session, availability, typed errors and cancellation; mock-only tests first, followed by **one** source-pinned FluidAudio German STT/VAD adapter. It may emit proposals but **never authority**.
3. **Resident-inspired harness experiment:** optional tool catalogue opening and context trimming, with denied/unavailable tool requests failing closed. Never call external tools with unreviewed payloads directly from a model.
4. **iCTRL independent feasibility:** only on an owner-controlled physical test iPhone after explicit consent; measure DDI/reboot, signing expiry, lock state, network exposure and stop behavior. No unapproved cross-app actions.
5. **Foundation-Models-Utilities spike:** iOS 27 conditional/isolated module for `DynamicProfile`, History and Skills, but keep the iOS 17 core functional and enforce locality on every configured language-model endpoint.
6. **Later file coding action:** Pocket Agent-approved diff semantics under iGentic one-shot ledger and a race-safe workspace implementation; import no whole app.

**Hard stops:** silent network or microphone access; allowing a connected tool to bypass iGentic's approval; direct command reruns after unknown side effects; package/model weights without verified identity/license; source-level claims rebranded as physical iPhone acceptance.

**Methodology limitation:** Each of 2,546 files received an automated per-file inventory and triage; **not every line received manual semantic review**. Human attention was directed to implementation entry points and high-risk paths. Swift frontend parsing does not prove import availability, typecheck, iOS SDK linking, signing, entitlements, platform memory/thermal behavior, device compatibility, actual tests passing or absence of vulnerabilities. This is source evidence; the exact uploaded ZIP archive is the reference, not the mutable GitHub `main` link.
