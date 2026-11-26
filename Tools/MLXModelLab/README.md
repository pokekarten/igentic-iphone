# Optional native MLX Model Lab

Experimental iOS 27 package, not linked by the main application or default Swift package. The app must explicitly choose a trusted in-process adapter and a private, exclusively controlled model directory. Only the pinned Qwen snapshot is admitted. No download or automatic tool callback. The journaled diagnostic loop executes only the existing policy-gated local readers; the fixed three-case benchmark does not execute actions. Model text is never printed. Use only synthetic benchmark inputs.

Physical test, 2026-11-26: local checkout of MLX Swift LM `026d599e52f3a2cebbecbd5b3f318b800a73ff02`, MLX Swift 0.33.0, Xcode 27.2 and Metal 27B47. A separate signed lab host built and ran the exact adapter source and repository workflow on iPhone Air. Receipt: completed, 4 turns, capabilities.read/status.read/model.readiness/finish, report prepared, 593 ms for journaled loop, 2.38 s launch-to-receipt. Independent journal readback confirmed completed with four steps. The main app was not replaced. This is bounded read-only acceptance, not general agent quality or production admission.

This repository manifest pins the previously tested local checkout by revision; its remote dependency resolution and portable host packaging still require separate validation. No weights or local device identifiers are committed. The lab API is experimental and no automatic provider switch is enabled.

### Local model routing acceptance

The optional lab now selects Apple by default when its structured-proposal runtime is ready. Explicit Qwen selection requires opt-in and pinned artifact admission. The automatic Qwen fallback is eligible only before a new attempt when Apple is unavailable and Qwen is opted in and admitted; it is not an automatic replay of a failed or partial attempt. The physical test did not simulate Apple unavailability. No hosted provider is included.

Physical acceptance (2026-11-26): automatic selected Apple and completed four turns in 1978 ms; explicit Qwen selected Qwen and completed four turns in 597 ms; both prepared a local report and independently verified a fresh completed journal. Explicit Qwen without opt-in returned blocked and the existing journal was identical. All three physical cases passed. The main app and its model data were preserved. Timings are single observations, not comparative benchmark claims.

Focused Swift suite: 16 tests passed, including all 24 preference/availability/consent combinations and no provider replay after failure. The optional lab package remains separate from the main app.

### LFM2.5 350M research-only candidate and classification comparison

Official 4-bit MLX export `LiquidAI/LFM2.5-350M-MLX-4bit` at `f6cb4e006bb7a2d8a6afa14ec0a53e0586f65a5b`; original license text at `LiquidAI/LFM2.5-350M` revision `9921cd4d82c0e3986887aa4b376f9446729ef8a3`. LFM Open License v1.0 is not Apache-2.0; its commercial revenue threshold is USD 10 million and redistribution has notice/license obligations. This candidate is for noncommercial research only, not admitted to the production router. The exact nine staged files including the original license are verified by AgentCore (226,583,972 bytes); no weights are committed.

Physical iPhone Air: native LFM inference completed 12/12 bilingual A/B tasks, 8/12 correct (6/6 development fixtures, 2/6 additional fixtures). Load 315 ms, first case 1315 ms, remaining 37–46 ms. Qwen same prompts and fixtures, thinking disabled, repeated twice: 8/12 correct (4/6 development, 4/6 additional), load 663 ms on repeat, cases 69–90 ms, 2.49 s launch-to-receipt. LFM 2.98 s launch-to-receipt. No actions executed. First Qwen comparison runner had an incorrect receipt prefix; corrected runner independently verified repeat. Small synthetic set, language-specific prompts selected on development fixtures; not a statistically meaningful or general capability benchmark. Neither model qualified for unrestricted classification by this experiment. Keep LFM out of automatic routing; Qwen diagnostic agent remains a separate bounded task-specific acceptance.
