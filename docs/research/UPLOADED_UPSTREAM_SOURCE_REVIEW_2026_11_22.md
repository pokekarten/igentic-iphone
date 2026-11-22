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

- XcodeGen declares **iOS 17.0** minimum, **Swift 5.9**, the llama.swift package and a `fikrikarim/FluidAudio` **fork followed at branch main**. It does **not** depend on the official FluidInference package at a pinned revision.
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

## 2026-11-22 deeper implementation review and iGentic reuse decision

### Scope and confidence

This second pass **reopened and read the four uploaded ZIP snapshots directly** rather than extrapolating from project descriptions. Static inventory: ipb 122 regular files (29 Python, 6 Swift), FluidAudio 981 (778 Swift), Volocal 51 (18 Swift), Pocket Agent 221 (119 Swift). This included the package manifests, tool/action implementations, core audio/model orchestration, caches, tests, native interface descriptions, build requirements and license texts. In the uploaded snapshots FluidAudio has **305 Swift test files** under its Tests tree; ipb has focused host/MCP and device-test sources. **No XCTest test source is present** in the uploaded Volocal or Pocket Agent ZIPs. Test files indicate coverage *intent*, not successful execution or full coverage.

The four top-level license files are respectively **MIT (ipb), Apache-2.0 (FluidAudio), MIT (Volocal), MIT (Pocket Agent)**. This does **not** settle licenses for binary frameworks, downloaded model weights, remote services, bundled JS or attribution obligations. Pocket Agent vendors portions of LiteRT-LM/other wrappers and explicitly separates optional native binary engines; FluidAudio has a separately versioned NeMo text processing binary target. Review each linked component before importing.

### Decision: use a narrow component/pattern, do not merge entire apps

| Upstream | Reuse decision | Exact reason and scope |
| --- | --- | --- |
| **FluidAudio** | **Integrate conditionally as an optional iOS speech dependency**, pinned to a reviewed commit/release with exact selected model snapshot; first STT/VAD only | Direct Swift package (tools version 6.0, iOS 17+), actual ASR/VAD/TTS implementation and extensive test sources. iGentic lacks a comparable voice subsystem; no need to fork a 778-Swift-file library. **Do not** import the huge demo/CLI/runtime surface into iGentic or assume all models/weights are local before provisioned. |
| **Pocket Agent** | **Reuse interaction/test patterns, not its whole kernel** | Its approved diff is one-shot, checked against changed on-disk content and contained within a security-scoped user-selected workspace. iGentic already has policy, approval receipts and a one-shot execution ledger. Importing another agent authority would duplicate and potentially weaken the existing safety boundary. |
| **Volocal** | **Reuse voice pipeline architecture after correction, not as a direct dependency** | Compact example of shared audio graph, partial ASR, sentence-level streaming TTS and revision-based cancellation, but its unpinned dependencies, insufficient model integrity checks, initialization error handling and unsynchronized audio callback fields require redesign. |
| **ipb** | **Keep outside the phone app as an explicitly opt-in developer QA backend**, compare to existing ARTEMIS PR #378 | macOS 27/Xcode/CoreDevice 27 + iOS 27 private ABI; MCP input/AX and uncertainty isolation are useful on *owned test devices*, but it cannot provide Mac-free phone operation or App Store-permitted generic UI action APIs. Never give an arbitrary model raw device-control tools. |

### High-signal code findings / severity

**P0 — Volocal fail-open readiness reporting.** In the uploaded VoicePipeline.configure, the callers await STTManager.initialize and TTSManager.initialize and then mark isReady=true. Both initialize functions **catch and store errors internally rather than throwing**; hence failed speech or synthesis initialization can coexist with global readiness. The LLM path is checked differently. Before adapting this design, use a typed aggregate state: ready only if STT, required LLM backend *and* optionally TTS report positive availability. Emit distinct `notAvailable` / `permissionDenied` / `modelCorrupt` / `downloadRequired` error states and cover with mock tests. Source evidence: Volocal/Pipeline/VoicePipeline.swift, Volocal/STT/STTManager.swift, Volocal/TTS/TTSManager.swift.

**P0 — Volocal cross-thread AudioBridge state is not visibly synchronized.** AudioBridge is declared `@unchecked Sendable`; MainActor writes `inputContinuation` / `isSpeaking` while the AVAudioEngine tap closure reads `inputContinuation`. The comment assumes normal Bool loads/stores are atomic, which **does not by itself establish race freedom or synchronization**. Use actor-isolated state plus a properly synchronized callback bridge (or a real-time safe, bounded SPSC ring/lock-free primitive with documented memory ordering); avoid blocking, allocations and excessive copies on the real-time audio callback. Inspect tap-to-stream backpressure and dropped-buffer behavior. These are source-level race risks, not reproduced crashes.

**P0 — Volocal unpinned model and dependency admission.** Its XcodeGen project follows the `fikrikarim/FluidAudio` fork at branch `main`; the Qwen3.5 2B Q4_K_S GGUF URL also resolves `main`. The LLM downloader moves the URLSession temporary file into final position without a visible hash comparison. The registry's readiness accepts any existing same-named file larger than 1,024 bytes, while the separate downloader's presence check merely tests existence. These checks do not prove model identity or lack of corruption. In iGentic, use the **already open model-verification PRs #383/#385**, pin repo revision + SHA-256, validate download and cache before enabling inference; do not build a second verifier.

**P1 — Volocal language and resource gate.** ModelRegistry describes approximately **1.26 GB** LLM, **450 MB** speech and **600 MB** TTS: around **2.31 GB downloaded assets**, not resident memory or full install footprint. German Parakeet EOU accuracy, TTS voice language and iPhone Air sustained latency are not demonstrated in the archive. Start with *one* known multilingual German ASR target, local typed proposal preview, no compulsory model/TTS download; include low-storage and low-memory refusal tests.

**P1 — Pocket Agent approval implementation is valuable but not directly authoritative for iGentic.** In its AgentEngine, the state moves away from awaitingApproval before async work. WriteFileTool.preview creates the exact proposed file diff and stores it by invocation; execute removes it via PendingDiffStore.take under an NSLock, and calls workspace.write with the approved newText and writeExpectation. This is a strong fail-closed interaction pattern; it also has an explicit **requiresPreview=false test-only bypass** that must never be copied into production. `SafePath` checks symbolic links on each component and blocks protected paths such as Git metadata/secret files on **read and write**, not just write. Security-scoped folder bookmarks and content freshness are transferable patterns. **Not proven:** race-free filesystem confinement under concurrent directory replacement; a check followed later by a write is not by itself a descriptor-relative open guarantee. Revalidate at actual write, test symlink swap and replace races. Source evidence: PocketAgent/Agent/AgentEngine.swift, PocketAgent/Tools/FileToolsImpl.swift, PocketAgent/Tools/SafePath.swift and PocketAgent/Tools/ProjectFolderStore.swift.

**P1 — Pocket Agent hardware/dependency/test boundary.** Its XcodeGen target is iOS 17+, intentionally uses **Swift 5 language mode / minimal concurrency checking**, and pins particular LiteRT-LM, MLX and tokenizers package versions. LiteRT is locally wrapped; optional llama/SD binaries are **not present in the source archive**. Its BUILD document says the author **had not verified this release copy in Xcode**. No XCTest test source is present in this snapshot. It requests increased-memory-limit and extended virtual addressing entitlements whose availability is device/signing dependent. The README's offline statement applies to configured local model operation; optional remote providers are also implemented. Do not vendor the app or assume the supplied ZIP can build/execute unmodified on our target iPhone Air.

**P1 — FluidAudio downloads: stronger than size checks, but revision still matters.** Its ModelCache.hasMatchingContent supports checking locally cached LFS files with **SHA-256 object IDs** and Git objects with **Git-blob SHA-1** when the remote tree lists those IDs. HFTreeLister extracts those IDs; FileDownloader separately rejects HTML, empty and mismatched-size artifacts. The offline mode blocks network calls and cache redownload paths; there are targeted tests for download resume, corrupt/incomplete caches and offline cases. This **corrects an oversimplified size-only reading**: the implementation has cryptographic validation in a cache adoption path. However, default remote revision values can still be `main`, and a remote tree ID only identifies what that remote revision served, **not a reviewed immutable iGentic model artifact**. Pin upstream package, exact HF model commit, model license and expected hashes; test file tampering against a fixed owner-approved manifest. Offline mode uses a shared mutable flag, so set it before concurrent workloads and do not equate a global flag with network-sandbox enforcement.

**P1 — FluidAudio integration footprint.** The root manifest has Swift tools 6.0, platform minimum iOS 17, an optional Swift 6.2 traits manifest elsewhere and a prebuilt `NemoTextProcessing` XCFramework with an SPM checksum. Licensing the package does not automatically license its model checkpoints and all extras. Choose **one exact version**, limit feature surface to STT + VAD for first iteration, account for compilation/binary size, privacy manifest, mic consent, German ASR metrics, first-launch download and resident memory. TTS/diarization can wait until the first microphone-to-preview path passes acceptance.

**P1 — ipb ambiguous side effect handling is unusually useful.** The uploaded MCP guide describes per-device UUID locks, cross-server POSIX flock, persisted operation intents, process ownership, cancellation cleanup, bounded RPC/output and fail-closed `observeRequired` vs `orphanPossible` quarantine. The bridge emits `businessVerified=unknown` even when the child succeeds; no blind retry of an uncertain write is permitted. This should inspire a **host adapter contract** in iGentic QA: command-succeeded does not imply app-action-succeeded, and observed state must be fresh. Important limits: manual CLI/mirror or a different state directory bypass these locks; private Apple interfaces, iOS 27+ eligibility, real-device coverage and macOS version constraints remain unresolved. The snapshot itself states the new MCP path is **device-unverified**, and host fixture tests are not phone acceptance. ipb is *not* a production iPhone-local capability.

### Fit against iGentic's current source and open PRs

Live source and PR heads were checked again on 2026-11-22. Current main contains PolicyEngine, ApprovalManager, AppActionCoordinator, SafeActionExecutionCapabilityLedger, AppleFoundationModelsRuntime, ToolRegistry and bounded action-specific canonical drafts. The one-shot capability ledger already consumes authorization only once; **do not replace it with Pocket Agent's pending diff store**. Its potential gap is a future **workspace-file** intent, which requires its own actual side-effect review and should not be smuggled into existing reminder authorization.

Current open draft work already covers: **#380** read-only App Intent, **#381** untrusted proposal gate, stacked **#382/#384** Apple model preview tests, **#383/#385** open-weight verified admission, **#386** integrated test acceptance, **#387** Qwen local smoke and **#388** physical-device readiness. Therefore do not open duplicate PRs for generic model runtime, GGUF integrity, or authorization. The existing **#378** ARTEMIS adapter is the alternative Mac lab driver; ipb must be evaluated as a disjoint comparison, not made a competing production controller.

### Exact preferred iGentic architecture

```text
Explicit mic start + privacy permission
    -> audio capture (owned Swift adapter; bounded and cancellable)
    -> optional pinned FluidAudio ASR/VAD [offline; model snapshot verified]
    -> plain transcript (untrusted; German + noise + injected speech tests)
    -> current on-device model OR deterministic intent parser
    -> existing typed UntrustedActionProposalGate (#381)
    -> existing PolicyEngine / AppActionCoordinator / one-shot approval
    -> explicit user review and typed app-scoped App Intent (#380)
    -> post-action verification + privacy-safe AuditLog
    -> optional later TTS with interruption/retry semantics
```

No vendor audio package, model response or external device driver acquires permission to execute. On iOS the standard App Intents API exposes declared application capabilities, not arbitrary privileges in every other app. [Apple App Intents](https://developer.apple.com/documentation/appintents) remains the production surface. The ipb/ARTEMIS laboratory exists **outside** this pipeline and requires explicit owner permission.

### Implementable minimum acceptance suite (tests to add when work is authorized)

| Slice | Deterministic acceptance cases | Required evidence |
| --- | --- | --- |
| **S0: Existing PR integration** | #380 read-only App Intent plus #381 untrusted proposal gate; verify deny/no-write; accepted proposal still cannot self-authorize | Exact-head macOS Swift tests + signed synthetic simulator check; physical iPhone separately |
| **S1: Speech input interface** | Mock STT; cancelled turn, mic denied, missing model, expired audio buffer, partial vs final transcript; only final transcript reaches proposal parser | Swift unit tests with synthetic/no-personal-audio fixtures; never assert actual ASR latency from mocks |
| **S2: Optional FluidAudio integration** | Pinned package and model; German speech WER vs synthetic/consented fixed samples; network-off, tampered weight, low RAM, low storage and model-missing errors | iPhone Air observed data + exact OS/build/device/model revision; zero unapproved external network egress |
| **S3: Action review** | Spoken disallowed "change system settings" -> refusal; prompt injection spoken as an instruction -> non-authoritative content; duplicate approve, stale preview, reject and cancel -> no side effect | Existing Swift approval invariants; fresh screenshot/result after any real action |
| **S4: Pocket-style file workspace (later)** | User-selected security-scoped folder; deny Git metadata/secrets, path traversal and symlink targets; changed file requires new diff; write-after-crash is not silently replayed | Host/physical iPhone filesystem fixtures and signed side-effect test; separate implementation review |
| **S5: ipb developer lab** | On owned iOS 27 device: read-only observe → optional explicitly approved synthetic tap; malformed result, child timeout, orphan quarantine, wrong device UUID and stop cleanup | macOS 27/Xcode 27, provenance-pinned binary and fixture-only screenshots; **no** production coupling |

### Work order, stop rules and final adoption

**Now (do not duplicate existing PRs):** first finish review, required owner repository admission and exact-head acceptance of the existing native App Intent/model preview stack. This provides a tested *safe action target* before voice or UI automation is added.

**First net-new product implementation:** introduce an iGentic-defined `SpeechInput` protocol with an explicit active mic session, typed availability and cancellation states; implement a fixture-driven mock and a **read-only transcript-to-proposal** UI using the existing gate. Then compare an exactly pinned FluidAudio STT/VAD adapter against native alternatives on the owner's iPhone Air. Do not initially add PocketTTS or a second large LLM as hard requirements.

**After voice passes:** add optional TTS and semantic interruption only when actual measured use shows value. For a future coding/workspace feature, implement Pocket Agent-inspired diff/approval behaviors *using our own authority ledger*, never silent writes.

**Independent developer path:** assess ipb read-only for a physical iOS 27 QA device only if the Mac/device/Apple private ABI prerequisites are confirmed; keep it disjoint from ARTEMIS and the shipped iPhone app.

**Hard stops:** missing package/model license, unpinned weights, unapproved microphone/network, unsynchronized audio bridge, insufficient memory, automatic retry of uncertain mutations, device-specific failure treated as green, or any proposal/provider/tool bypassing iGentic authorization.

**This pass did not:** execute any uploaded third-party code, run their Swift/Xcode tests, load third-party weights, install iOS apps, modify the physical iPhone/Mac, validate release signing or prove production readiness.
