# iGentic: source-level review of four uploaded iPhone projects (2026-11-22)

**Scope:** source-only analysis of four user-supplied, locally inspected ZIP archives corresponding to projects **already present in the [project atlas](IPHONE_AGENT_PROJECT_ATLAS.md)**. This is an evidence upgrade, **not four newly discovered repositories**. No third-party code was installed, imported as an iGentic dependency, executed, or tested on a physical phone. The ZIPs are snapshots without a proven Git commit correspondence; upstream links are navigational and may have changed since these archives.

## Archive identity and limited mechanical checks

| Upstream | ZIP SHA-256 (uploaded snapshot) | ZIP entries | Static checks |
| --- | --- | ---: | --- |
| [ipbtools/ipb](https://github.com/ipbtools/ipb) | `7c0226d4518434314d76d8dcddb9aab952e548278cc5cafd666c4bad5617f98e` | 142 | ZIP integrity valid, no traversal-style member names detected, 29 Python files successfully parsed as AST |
| [FluidInference/FluidAudio](https://github.com/FluidInference/FluidAudio) | `acf8c433b4b9a7fc9ca5f75747171c8188ad25535e93b2db1d003a3cbbb5e4ee` | 1,182 | ZIP integrity valid, no traversal-style member names detected, 10 Python files successfully parsed as AST |
| [fikrikarim/volocal](https://github.com/fikrikarim/volocal) | `f631619eef7de940cf943962bace31c98fd6618d229d1d2a4eeaaa13c87d7b11` | 74 | ZIP integrity valid, no traversal-style member names detected; no Python files |
| [meshoklv/pocket-agent](https://github.com/meshoklv/pocket-agent) | `c0892e414a5b562c8128a26a4d0d3fd68c01ed77e8b34e6500785fdec19b1f50` | 286 | ZIP integrity valid, no traversal-style member names detected, 1 Python file successfully parsed as AST |

**Interpretation:** ZIP checks and Python **syntax-tree parsing only** do not validate Swift compilation, Objective-C build, runtime behavior, third-party packages, model weights, iOS permissions, security or licenses. The ZIPs and extracted source code are **not** added to iGentic; only these provenance hashes and observations are committed.

## 1. Pocket Agent — approval-before-file-write is real source structure

**Snapshot code inspected:** [AgentEngine](https://github.com/meshoklv/pocket-agent/blob/main/PocketAgent/Agent/AgentEngine.swift), [FileToolsImpl](https://github.com/meshoklv/pocket-agent/blob/main/PocketAgent/Tools/FileToolsImpl.swift), [SafePath](https://github.com/meshoklv/pocket-agent/blob/main/PocketAgent/Tools/SafePath.swift), [DiffBuilder](https://github.com/meshoklv/pocket-agent/blob/main/PocketAgent/Tools/DiffBuilder.swift), [entitlements](https://github.com/meshoklv/pocket-agent/blob/main/PocketAgent/PocketAgent.entitlements).

- `AgentEngine.approve()` transitions out of awaiting-approval **before awaiting work**, limiting double-tap re-entry. `WriteFileTool.preview` stores a full proposed diff keyed to the invocation; `execute` consumes that pending diff **once** and writes the approved text, rather than accepting a fresh replacement returned by the model.
- A file-changed-since-preview result rebuilds the approval flow instead of silently overwriting newer content. `SafePath` rejects parent traversal and symbolic links across path components; the diff layer preserves real line break differences and applies a memory bound to its diff algorithm.
- The code also contains **test-only** ability to write without a preview when `requiresPreview` is disabled. That exception is *not* a safe reusable product API. The source includes optional remote-model providers and elevated-memory entitlements; claims of wholly offline operation apply only to the locally configured path, not every optional mode.
- **iGentic transfer:** copy the *behavioral test contract*, not the authority implementation: canonical immutable proposal, one-shot receipt, user-visible complete diff/action description, no disk mutation on rejection, stale-file race requiring fresh consent, and clear cancellation outcome. Keep iGentic `PolicyEngine`, `ApprovalManager` and `AuditLog` in charge.
- **Unverified:** entitlement availability/signing, TOCTOU hardening under concurrent filesystem mutation, symlink race resistance, storage provider edge cases, code coverage on the target iPhone Air, model speed and transitive licenses. Do not claim a formal security audit.

## 2. Volocal — concrete STT/LLM/TTS composition, with reproducibility gaps

**Snapshot code inspected:** [XcodeGen configuration](https://github.com/fikrikarim/volocal/blob/main/project.yml), [ModelRegistry](https://github.com/fikrikarim/volocal/blob/main/Volocal/Models/ModelRegistry.swift), [UnifiedModelManager](https://github.com/fikrikarim/volocal/blob/main/Volocal/Models/UnifiedModelManager.swift), [STTManager](https://github.com/fikrikarim/volocal/blob/main/Volocal/STT/STTManager.swift), [VoicePipeline](https://github.com/fikrikarim/volocal/blob/main/Volocal/Pipeline/VoicePipeline.swift).

- XcodeGen declares **iOS 17.0** minimum, **Swift 5.9**, the `llama.swift` package and a `fikrikarim/FluidAudio` **fork followed at branch main**. It does **not** depend on the official FluidInference package at a pinned revision.
- Local pipeline is specific: **Qwen3.5-2B Q4_K_S GGUF** through a llama-based runtime; **Parakeet EOU 320 ms** streaming STT; **PocketTTS** speech output. The pipeline uses partial and end-of-utterance callbacks, turn revisions, asynchronous cancellation and a queued sentence/TTS path.
- **Supply-chain gap:** the GGUF download URL tracks a Hugging Face `resolve/main` file, and the inspected successful download path moves the file into place without a visible SHA-256 integrity check. The readiness helper accepts a pre-existing LLM file when its size is merely greater than 1,024 bytes. These paths are **not strong proof of correct model identity**.
- No claim that its Parakeet EOU configuration accurately recognizes **German** is supported by this source inspection. German WER, TTS output language, barge-in robustness, microphone permission, cancellation and privacy require actual on-device tests.
- **iGentic transfer:** adopt the small voice state-machine test scenarios and STT-to-tool-proposal **preview-only** flow first. Before actual integration: pin source revisions and weight hashes, require verified model readiness, record offline data egress and implement deterministic session cancellation. Do **not** let voice text become direct execution authority.

## 3. FluidAudio — reusable first-party-style Swift library; model provenance is separate

**Snapshot code inspected:** [Package manifest](https://github.com/FluidInference/FluidAudio/blob/main/Package.swift), [model guide](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Models.md), [HF client](https://github.com/FluidInference/FluidAudio/blob/main/Sources/FluidAudio/Shared/Download/HFClient.swift), [file downloader](https://github.com/FluidInference/FluidAudio/blob/main/Sources/FluidAudio/Shared/Download/FileDownloader.swift), and relevant bundled license and test directories.

- Swift tools **6.0** and package minimum **iOS 17** are stated. The package has Core ML speech/voice utilities and substantial Swift test coverage in the archive. The default package bundles additional text-processing resources and a **versioned XCFramework URL with an SPM checksum**; this **is not the same as pinning all speech model weights**.
- Model documentation differentiates **English-only** and **multilingual** ASR families (e.g. Parakeet v2 versus v3). Thus do not choose a default based on model family alone: German support, streaming latency and memory should be compared on the exact selected runtime/model.
- The download stack supports an explicit **offline mode**, downloads with partial-file/resume handling and size checks. The source's model-download helper accepts `revision = "main"` by default. A matching size or cached file **does not necessarily establish cryptographic provenance**. Third-party model, asset and binary-target license review remains distinct from repository-level Apache-2.0.
- **iGentic transfer:** consider a **separate, optional, bounded** audio adapter: microphone capture → local STT → typed proposal → existing iGentic review gate. Audio and generated text stay out of logs; no ambient microphone background behavior is implied by the library. Start with offline synthetic PCM fixtures and German WER before any always-listening assistant.

## 4. ipb — valuable Mac-side QA adapter, not an on-iPhone agent runtime

**Snapshot code inspected:** [README](https://github.com/ipbtools/ipb/blob/main/README.md), [MCP bridge](https://github.com/ipbtools/ipb/blob/main/Sources/ipb_mcp.py), [child-process handling](https://github.com/ipbtools/ipb/blob/main/Sources/ipb_mcp_process.py), [MCP contract](https://github.com/ipbtools/ipb/blob/main/docs/mcp.md), [verification log](https://github.com/ipbtools/ipb/blob/main/docs/verification.md).

- Declared supported operating envelope: **macOS 27 host, Xcode/CoreDevice 27 beta components, iOS 27+ physical device**. It uses **private CoreDevice/HID/AX interfaces** rather than public iOS App Intents; no iPhone-local AI runtime or Mac-free product operation is provided. The snapshot explicitly drops iOS 26 support.
- The local stdio MCP wrapper validates typed tool arguments, limits request/output size and concurrency, and uses per-device persistent locks/state. For interrupted/uncertain actions it can set **observeRequired** or **orphanPossible** quarantine, preventing blind retries. Successful CLI completion does **not** imply app-level outcome (`businessVerified` stays unknown).
- Important limit from upstream itself: normal manual CLI sessions, mirrors and agents with different lock/state roots may operate **outside the MCP per-device lock**. This is **not an iGentic policy authorization layer**, and neither the private ABI nor its host support is stable by specification.
- **iGentic transfer:** assess **read-only first** as an alternative device-lab adapter to the existing [ARTEMIS PR #378](https://github.com/pokekarten/igentic-iphone/pull/378). Apply iGentic permission receipts *above* the host adapter, use the same signed synthetic Diagnostics test case, block write retries on uncertain effects, and do not expose screenshots or AX trees to an external provider without explicit consent.

## Integration priority and exact acceptance gates

| Priority | Candidate | Smallest permissible experiment | Rejection / stop conditions |
| --- | --- | --- | --- |
| **P0** | Pocket Agent design patterns | Host-test a **synthetic** proposed file modification: approve/reject/duplicate/stale/changed-file/cancellation; compare with iGentic action receipt policy | Any mutation without fresh human consent; ambiguous write replay; scope escape |
| **P0** | FluidAudio + Volocal concepts | iPhone Air **offline German** STT and typed proposal preview from a fixed synthetic/consented utterance | Unpinned/incorrect model weights, nonlocal audio data, missing mic permission, unsafe hands-free execution |
| **P1** | ipb lab adapter | **Host-only** read-only UI-tree observation on owned, available iOS 27 device; compare latency and error receipts against ARTEMIS on the same synthetic Diagnostics app | Unsupported OS/host, remote data exposure, uncertain actions, no ownership/approval |
| **Defer** | Reusing whole third-party agent runtimes | Evaluate only after measuring concrete missing capabilities in current Swift kernel | Duplicate model-agent frameworks, unreviewed licenses/dependencies, elevated entitlements without evidence |

**Admission order:** preserve single active implementation track; confirm current owner-controlled admission/security requirements, review PRs already open, exact-head tests, then macOS simulator and physical iPhone tests. Research snapshots are not a reason to merge blocked PRs. Do not install unsigned/private-API drivers or grant unattended cross-app control as part of this source review.

**Not performed:** Swift build, Xcode run, device pairing, target-device benchmark, model download, third-party executable execution, full vulnerability review, license compatibility ruling, cloud calls or iOS setting changes.
