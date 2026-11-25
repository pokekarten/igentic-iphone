# iGentic decision and knowledge models V0

Research checked 2026-11-25. Candidate shortlist, not an iPhone-ready ranking. Open weights do not imply an open-source license; exact model revision, license, artifact hash and runtime compatibility must be verified before acquisition or distribution.

## Independent model roles

- Decision: classify intent, choose the next allowlisted action or abstain; propose only, never authorize.
- Arguments: compare options and counterarguments with explicit evidence IDs; no free-form reasoning transcript required.
- Knowledge: local retrieval from a versioned source store with provenance, access classification, deletion and update support. Start with lexical retrieval then compare multilingual embeddings. Model weights are not the authoritative knowledge base.
- Verifier: independently classify evidence as supported, contradicted, insufficient or conflicting. A semantic prediction is advisory; deterministic checks validate source identity, freshness/scope, permission and tool schema. Existing Swift policy/approval/audit remains authoritative.

## Candidate research

| Role | Candidate | Source | Qualification |
|---|---|---|---|
| Decision | LFM2.5-230M | https://huggingface.co/LiquidAI/LFM2.5-230M | specialized compact agent candidate; custom license review |
| Decision | FunctionGemma 270M | https://ai.google.dev/gemma/docs/functiongemma | specialized action training recipe; Gemma terms |
| Decision | LFM2.5-350M | https://huggingface.co/LiquidAI/LFM2.5-350M | native function syntax; custom license review |
| Decision | Granite 4.0 350M | https://huggingface.co/ibm-granite/granite-4.0-350m | small comparison; pin license and tokenizer |
| Decision | Qwen3 0.6B | https://huggingface.co/Qwen/Qwen3-0.6B | known baseline; prior Mac MLX smoke #445 |
| Arguments | Qwen3.5 0.8B and 2B | https://huggingface.co/Qwen/Qwen3.5-0.8B ; https://huggingface.co/Qwen/Qwen3.5-2B | compact reasoning comparison; text-only first |
| Arguments | LFM2.5-1.2B-Thinking | https://huggingface.co/LiquidAI/LFM2.5-1.2B-Thinking | conditional license; measure reasoning budget |
| Knowledge | multilingual-e5-small | https://huggingface.co/intfloat/multilingual-e5-small | MIT claim; compact bilingual retrieval |
| Knowledge | Qwen3-Embedding and Reranker 0.6B | https://github.com/QwenLM/Qwen3-Embedding | compare separately; no assumption reranking implies entailment |
| Verifier | mDeBERTa multilingual NLI | https://huggingface.co/MoritzLaurer/mDeBERTa-v3-base-mnli-xnli | MIT claim; verify exact labels and calibration |

External evaluation references: https://gorilla.cs.berkeley.edu/leaderboard.html (BFCL), https://artificialanalysis.ai/methodology/mobile-device-benchmark-set (mobile methodology). Vendor scores and independent scores are not directly comparable when tool parsers or subsets differ.

## V0 experiment and training boundary

The 16 independent synthetic cases (eight scenario families, English/German pairs) evaluate evidence relations, abstention, conflicting sources, negation, scope and adversarial source instructions. They are not a substitute for immutable action-routing Benchmark V0, not a retrieval benchmark, and not training data. Never train on these prompts, translations or close paraphrases. Expand by version, using family-level separation. Score decision, relation, citations, exact output, and parseable unsafe proposals separately. Malformed outputs fail, not repaired. The unsafe-proposal metric is limited to parseable JSON, not a complete safety measurement.

Default invocation only validates fixtures:

    python3 scripts/igentic_decision_knowledge_eval.py
    python3 -m unittest discover -s scripts -p 'test_igentic_decision_knowledge_eval.py'

Explicit host inference with pre-existing pinned community MLX snapshot:

    python3 scripts/igentic_decision_knowledge_eval.py --run-mlx

This experimental prompt is direct JSON, not the native Qwen tool envelope; no results are comparable to the canonical upstream Benchmark V0. No real tools, private data, cloud calls, model downloads or weight publication. Inference success does not prove physical iPhone readiness.

## Next causal steps

1. Establish exact host baseline and document error classes; do not tune on V0.
2. Create disjoint synthetic training and development families for decision, abstention and evidence grounding. Record sources and dataset hashes.
3. Compare tiny decision candidates on identical held-out cases with native format and bounded inference. Add independent lexical retrieval baseline then test embedding/reranker on a separate retrieval set.
4. Train a small adapter only after license/revision review and baseline. Compare before/after on untouched held-out sets; publish only allowed artifacts, not private data.
5. Validate native iPhone memory, latency, thermal, battery, cancellation and deterministic policy, then integrate as opt-in proposal-only provider.

At each development iteration refresh primary model cards, licenses, current benchmarks and relevant runtime changes before proposing a new candidate. Do not automatically upgrade models based on a leaderboard.

## Observed host baseline — 2026-11-25

Executed on the owner MacBook Neo from isolated source commit `bf18edab9c665fad08675ad47caedeab615610fc`, using cached community Qwen3 0.6B 4-bit MLX revision `73e3e38d981303bc594367cd910ea6eb48349da8`, MLX 0.32.1 and mlx-lm 0.31.3. No weight download, external model call or device inference.

- Focused unit tests: 11/11 passed; repository validator and default no-inference path passed.
- Actual direct-JSON model evaluation: 0/16 exact, 16/16 invalid format, 0/8 exact for each language; two responses hit the 96-token cap. Model evaluation returned exit 1 as expected.
- Individual generation times observed: 0.380–1.337 seconds. This is a small host smoke run, not statistical performance evidence.
- No parseable unsafe proposal was counted; malformed output means this does NOT establish safe reasoning. Semantic decision accuracy is not assessable through the strict interface on this run. No raw generated output retained in the report.

Decision: do not promote this model/configuration into the execution path. Compare native tool output or constrained structured generation on separate development examples without changing the V0 evaluation. Keep the deterministic fallback. This does not reject the entire Qwen family or establish that another model is better.
