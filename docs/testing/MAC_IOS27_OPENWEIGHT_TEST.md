# iOS 27 / Open-Weight: reproducible Mac test preparation

**Owner:** iGentic iPhone. **Test date:** 2026-11-22. **Scope:** Mac readiness plus iGentic's unsigned iOS 27 build. This is **not** yet an MLX/GGUF/Core AI model inference test, nor physical iPhone proof. The user's MacBook Neo was offline when preparing this test; an unrelated GitHub-hosted `xcode-27` Apple runner can execute the same checks.

## Start on the owner Mac

**Prerequisites:** Mac reachable, terminal with cloned iGentic checkout, Xcode **27** active, Swift compiler **6.4 or newer** (required by iOS27 SwiftLlama bridge), iOS 27 SDK, Apple Silicon, at least 7 GiB RAM for this **unsigned compile-only smoke**, and 5 GiB disk free. Below 8 GiB the preflight prints a warning; no model-inference readiness is inferred. Do **not** replace the owner's existing checkout, reset working changes, or install dependencies automatically.

From the repository root, with the exact iOS27 test branch checked out:

```bash
python3 scripts/mac_ios27_openweights_test.py --phase preflight
```

This is the **default and safest test**: read-only system diagnostics, version checks, memory and disk preflight; no model weights, network calls, code signing, secrets or device serial numbers. Return code 0 means readiness for the compile steps; 1 means a gate failed.

For an **explicit** local build plus Swift unit tests and an **unsigned iOS27 simulator compile**:

```bash
python3 scripts/mac_ios27_openweights_test.py --phase build \
  --report "$HOME/igentic-mac-ios27-build-report.json"
```

The runner uses at most two Swift/Xcode build jobs, a unique temporary build directory and cleans **only its own** temporary artifacts after it finishes. It never touches downloaded model directories, signs an app or modifies user's Git repositories. The report contains OS/toolchain, disk/RAM and check status, but **no serial numbers, account data or API credentials**. The runner refuses to overwrite an existing report.

For a **separately requested iOS27 simulator launch**, available only with an installed iPhone simulator:

```bash
python3 scripts/mac_ios27_openweights_test.py --phase simulator
```

This builds again, installs the already unsigned `iGenticDiagnostics` target, launches/screenshots/relaunches it, and shuts down and deletes only a newly provisioned disposable simulator matching the active Xcode runtime. Existing simulator state is not used as a test target. An iOS26 simulator is not accepted. The simulator phase may be too memory-intensive on an 8 GiB Mac; use the build phase first.

**Additional CI safety net:** [Mac iOS 27 readiness workflow](../../.github/workflows/mac-ios27-openweights-readiness.yml) executes these unit tests and the build phase on GitHub's `xcode-27` hosted macOS runner on the PR using its exact event SHA. Its success proves build readiness on the **hosted runner**, not the owner's Mac.

## Evidence and stop conditions

| Gate | Evidence expected | Stop condition |
| --- | --- | --- |
| Mac build host | Apple silicon arm64, >=7 GiB RAM, >=5 GiB free disk; below 8 GiB warns that model inference is not assessed | Any missing build resource |
| SDK/compiler | Xcode 27+, iOS27 SDK, Swift 6.4+ | Anything earlier (Xcode26/Swift6.2 not enough for SwiftLlama's native 27 bridge) |
| Existing policy regressions | `validate_repo_structure`, `validate_ios27_baseline`, unit tests | Any failure |
| iGentic package | `swift build`, `swift test` in ios/ | Any compile/test failure |
| iOS app | unsigned Xcode27 simulator target compile | Build failure |
| Simulator (explicit) | iOS27 device install, screenshot and relaunch | Missing simulator or any smoke failure |
| Open-weight inference | **NOT COVERED YET** | No weights/adapters integrated in this test |
| Physical iPhone inference | **NOT COVERED YET** | Must test signed application on device |
| Security | Review the exact-head CodeQL and GitHub admission checks on [iOS27 PR #389](https://github.com/pokekarten/igentic-iphone/pull/389); historical failed checks do not override newer runs | Do not merge until required current checks and security review pass |

This script makes **no** external model or package downloads itself. The checked iGentic `ios/Package.swift` has only internal library targets; Swift/Xcode's normal package resolution is outside the script's explicit control, so do not interpret a generic SwiftPM network promise as a verified firewall-level guarantee.

## Next optional *real model* acceptance, once Mac is online

Perform in a **separate, opt-in PR**, not silently as part of preflight:

1. **MLX/Qwen3 0.6B 4-bit:** exact MLX Swift LM 3.x release, exact Hugging Face commit and weight/tokenizer file hashes, offline model cache; Xcode 27 `MLXFoundationModels` adapter with untrusted text-only proposals and no tool execution. Record model-load success, prompt-to-first-token latency, tokens/s, peak RAM, repeat runs and German responses.
2. **GGUF/LFM or Qwen 0.6B:** pinned SwiftLlama b11960 Apple XCFramework, exact SHA-approved GGUF. Use native `LlamaLanguageModel` with Swift6.4, test text/cancellation separately from permissioned tool calling. Model name alone is not authority.
3. **Core AI/Qwen3 0.6B:** exact Apple Core AI `.aimodel` artifact plus tokenizer, run on macOS 27 and separately **on a real iOS 27 iPhone**; do not equate Xcode simulator compilation with runtime Core AI proof.
4. Verify same prompt and bounded context across backends; run offline after complete downloads and record device OS, actual free memory, package pins, weights provenance and raw performance report. **No secrets or personal content** in sample prompts or logs.
5. Reject unverified/partial weights, mutable model revisions, unrecognized tool capability modes and attempted direct calendar/reminder writes. Keep `PolicyEngine → ApprovalManager → one-use capability ledger → AuditLog` above all backends.

**Source research:** [iOS27 runtime survey](../research/IOS27_OPEN_WEIGHT_RUNTIME_SURVEY_2026_11_22.md) and [five-archive source audit](../research/FIVE_UPLOADED_IOS27_RUNTIME_SOURCE_AUDIT_2026_11_22.md). This test branch is stacked on PR #389; the research documents currently live on the separate Draft PR #379 and may not yet be visible when working against this branch. That separation is intentional; upstream research links are available in the PR bodies.
