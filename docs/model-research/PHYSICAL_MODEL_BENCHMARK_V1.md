# Physical iPhone model benchmark V1 — proposed protocol

Status: research/design, 2026-11-26. Not implemented or an acceptance claim.
Keep the existing optional MLX Model Lab and immutable V0 fixtures as regression baselines. No production provider routing change. No paid judge or OpenAI API required. All benchmark inputs must be synthetic or redistribution-cleared; never publish personal device identifiers, user files, or model weights.

## Reference projects

- https://github.com/john-rocky/edge-llm-bench : pinned cross-runtime device harness.
- https://github.com/john-rocky/apple-silicon-llm-bench : cold/warm, same-session runtime comparisons, raw receipts.
- https://ananasdda.github.io/pocket-ai-lab/models : iPhone Air catalog and device observations; footprint is not total RAM.
- https://monoware.app/blog/phone-local-small-language-models-4k-8k-benchmark : physical iPhone 15 Pro Max load/context allocation separate from agent quality.
- https://monoware.app/blog/qwen35-2b-iphone-4k-8k-long-context-benchmark : filled-context stress, separate from allocated context.
- https://pocketpal.dev/leaderboard : standard pp512/tg128 device comparison.
- https://github.com/SalesforceAIResearch/MobileAIBench : quality/resource separation; use only local, deterministic components, not hosted judge.
- https://gorilla.cs.berkeley.edu/leaderboard.html : tool-call evaluation methodology.
- https://github.com/sierra-research/tau2-bench : final state checks, not rigid path; replace remote user simulation with scripted fixtures.
- https://developer.apple.com/documentation/xcode/measuring-your-app-s-power-use-with-power-profiler : energy profiling and limits.
- https://developer.apple.com/documentation/MetricKit : diagnostics and aggregate device metrics.

## Candidate discovery and admission

A candidate is an exact model revision + artifact hashes + format/quantization + runtime revision + configuration, not just a model name. Registry status: discovered, license_reviewed, artifact_verified, host_smoke, physical_smoke, benchmarked, task_qualified, blocked. Record rejection reasons and unsupported capabilities; never erase failed candidates. Review upstream and conversion license/notice obligations independently. No execution of downloaded custom code. Stream SHA-256, exact size and file inventory, exclusive private staging. Native verification before loading. Keep separately pinned prompt template and tokenizer. For Apple record OS build, locale, availability and public model ID/version if exposed; do not invent parameter count or token count.

New research targets (not device-qualified): Falcon-H1-Tiny-Tool-Calling-90M, Falcon-H1-Tiny-Multilingual-100M, Gemma 3 270M IT, SmolLM2 135M/360M/1.7B, MobileLLM-R1.5 360M/950M, Falcon-H1 0.5B Instruct, SmolLM3 3B, Llama 3.2 1B/3B, Phi-4 Mini, LFM2.5 1.2B Instruct/2.6B, Qwen3.5 2B, LFM3 1.7B, FunctionGemma 270M. Specialist targets: FastVLM 0.5B, SmolVLM2 256M/500M, EmbeddingGemma 2, MobileCLIP2, local Apple Speech and Parakeet. Exact device and runtime evidence vary; each artifact requires its own admission.

## Architecture and proposed implementation order

1. Shared benchmark manifest, typed run/observation schema and validator, case manifest digest, deterministic scorer; keep existing 12 classification and 16 evidence cases as V0 smoke, no tuning against holdout.
2. Runtime adapter registry (Foundation Models / MLX first; llama.cpp, Core AI, LiteRT-LM, Core ML later). Capabilities include supported context, streaming, native tools, guided schema, multimodal, embedding, available telemetry. Explicit task dispatch with no automatic fallback in benchmark. All model execution stays on the iPhone. The Mac orchestrates signed lab builds, stages verified artifacts, starts an explicit fixed job, retrieves receipts, evaluates and renders.
3. Run one model at a time, unload or relaunch between candidates, retain main app unchanged. Registry-driven jobs in a private app container, no rebuild to add a supported model. Local journal persists progress and typed statuses. Fixed bounded job ID, model ID, fixture hash, time/token limits. Prevent duplicate execution; cancelled, interrupted, OOM, unavailable, timeout and unsupported are distinct outcomes. Never report missing values as zero. Keep production tools unavailable; sandbox state only, except a separate owner-approved native read-only integration suite.
4. Add performance instruments: monotonic timers, first text chunk, actual tokens when available, process physical footprint, available memory/headroom, runtime allocator peak (separate metric), thermal state, low-power and battery state, cancellation/foreground behavior. Measure load, prefill, decode, end-to-end and successful task latency separately. Use release builds for comparable results; debug results clearly labeled. For Apple do not equate app footprint with entire system-model memory. GPU/ANE attribution only if measured; do not double count mapped memory.
5. Export JSONL receipts, environment manifest, summary CSV/JSON, Markdown and generated static leaderboard. Every score links to run hashes. Keep unrounded numeric units, missing reason, all denominators, errors and repetitions.

## Fixed performance protocol

- One physical iPhone model/OS build, release build, single stream, same documented input and sampling; compare within controlled sessions. Record battery band, charger state, low-power, brightness, ambient conditions (unknown if unmeasured), case/cooling, foreground state and thermal start. No forced heating or bypass of iOS limits.
- Start at nominal thermal state, cool between candidates. Stop sustained runs at serious/critical, OS warning, resource guardrail, cancellation, or bounded deadline. Record stop reason. Use randomized or rotated model order; repeat across sessions.
- Fresh process first request (cold process, not necessarily cold OS cache), three independent launches minimum; warm: one warm-up then five measured runs. Identical short input, 128 generated token target where runtime supports forced generation; report actual tokens, EOS/caps; separate synthetic throughput from natural task completion. Also pp512/tg128 and context tiers 2K, 4K, 8K with actual filled input vs allocated context; hold rendered-token budgets constant for throughput and semantic input constant for quality. 16K exploratory only if headroom and quality justify.
- Sustained 2-minute screening, then up to 10-minute repeated bounded workload only for qualified candidates; throughput drift, thermal changes and aborted runs are outcomes. Stop on serious thermal pressure or insufficient headroom. No unattended indefinite loops.
- Energy: use Instruments Power Profiler on a controlled repeated workload plus idle baseline; report actual available units and attribution. Battery percentage alone is coarse, not joules/token. MetricKit aggregates are useful diagnostics, not instant per-case power. Do not invent energy values or token counts for APIs that do not expose them.
- Report median, p95 with sample size (small n exploratory), spread, exact successes/total, and confidence intervals for rates as appropriate. Don't silently omit failures or compare unlike quantizations and devices.

## Proposed quality V1

240 original synthetic DE/EN cases (120 each), disjoint development/held-out families, versioned and frozen before tuning:
- 48 intent/routing incl. unsupported and clarification
- 64 function/action arguments incl. missing, ambiguous, malformed, distractor, forbidden
- 48 evidence decisions incl. missing/conflicting/stale/injected evidence, citations
- 40 stateful multi-turn tasks with mocked notes/calendar/reminder/device state
- 40 safety/policy stress incl. wrong tool, unauthorized write, duplicate/replay, interruption

No external LLM judge: schema checks, normalized typed arguments, citation precision/recall, exact state, forbidden effects, expected clarification, timeout and task success. Separate raw model proposal errors from policy rejections and actual side effects. Run free-form common contract (A) and native optimized/guided mode (B) as separate conditions, never pool. Native function calling can be normalized to a typed proposal, but not silently repair malformed output in A. Publish DE/EN separately, critical failures separately. Test prompt tuning only on development families; holdout prompts/expected answers not fed to model. Report repeated task success rather than cherry-picked best runs. V0 smoke stays unchanged.

Additional independent suites: retrieval (Recall@k, MRR, nDCG, bilingual synthetic corpus), vision/OCR/UI grounding (accuracy, CER, target hit rate), speech (WER/CER, real-time factor, first partial/final latency). Unsupported suites are N/A, not failure or zero. Public benchmark subsets can be added with pinned dataset revision and license; no hosted simulation requirement. Use BFCL-style action scoring, IFEval-style rule checks, and tau-bench-style mock end states.

## Routing and safety

Separate leaderboards for routing, action planning, evidence, long context, vision, retrieval, speech and runtime performance. Eligibility before ranking: artifact/licensing, supported capability, test completion, predefined task-specific quality and critical-error gates. Proposed provisional target: at least 95% held-out accuracy for bounded read-only routing and 0 forbidden executed effects; no production write permission inferred from a passing benchmark. Zero observed critical errors is not proof of zero risk. A deterministic policy engine retains final authority, with owner confirmation for sensitive effects. Prefer Pareto fronts (quality, success latency, peak memory, energy); no global weighted score until explicit weights are chosen. Use measured resource headroom/thermal state for selection before a new attempt; never replay a partially executed goal with another provider.

## Current limitations

Existing physical V0 results are small synthetic single-run tests. The generic scheduler, cross-runtime adapters, energy telemetry, V1 dataset, held-out acceptance gates and generated public leaderboard are planned, not implemented. Device pairing and signing are required for native runs; iOS foreground/background restrictions apply. Model files stay out of GitHub. Start with current Apple/MLX models and one llama.cpp comparator before widening the matrix.
