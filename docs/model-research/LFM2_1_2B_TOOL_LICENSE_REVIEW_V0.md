# LFM2 1.2B Tool License Review V0

Status: conditional research gate; not legal advice  
Reviewed: 2026-08-28  
Parent: #314 and #74

## Purpose

This document records the repository's source-backed license boundary for `LiquidAI/LFM2-1.2B-Tool` before any iGentic baseline adapter, model download, training, redistribution, runtime integration or product claim.

It is a research-governance record, not legal advice. It does not determine whether any person or organization satisfies the license's revenue, entity or use-specific conditions.

## Bound source

Model repository:

- `LiquidAI/LFM2-1.2B-Tool`
- current model card license identifier reviewed: `lfm1.0`
- license name: LFM Open License v1.0

Immutable license source reviewed:

- revision: `a6323e1f0ded5e89dd217d2a5b38d16380fc308d`
- https://huggingface.co/LiquidAI/LFM2-1.2B-Tool/blob/a6323e1f0ded5e89dd217d2a5b38d16380fc308d/LICENSE

This revision binds only the license text reviewed here. **The model weights, tokenizer, configuration and native tool template remain unpinned.** A later technical baseline contract must independently bind the exact model revision it executes.

## Source-backed license facts

The reviewed LFM Open License v1.0:

1. grants copyright and patent rights subject to the license terms, including its commercial-use limitation;
2. defines `Commercial Use` as use for direct or indirect commercial advantage or monetary compensation;
3. defines the `Threshold` as annual revenue of USD 10,000,000 or more;
4. conditions commercial-use rights on the relevant person or legal entity not exceeding that threshold, and states that commercial use by a legal entity exceeding the threshold is not licensed under this agreement;
5. states a threshold exception for a qualified non-profit organization's non-commercial or research use;
6. requires redistribution to include a copy of the license, prominent modification notices for changed files, retention of applicable copyright/patent/trademark/attribution notices, and applicable NOTICE attributions when a NOTICE file is present;
7. does not grant general trademark rights beyond reasonable customary use to identify origin and reproduce NOTICE content;
8. terminates automatically on noncompliance and requires use to cease and copies to be deleted after termination.

The license also states that the user is responsible for determining the appropriateness of use or redistribution. This repository therefore does not translate the source into a blanket legal or product approval.

## iGentic gate decision

```text
RESEARCH_EVALUATION_GATE: conditional
PRODUCT_DISTRIBUTION_GATE: unverified
COMMERCIAL_USE_GATE: unverified
MODEL_REVISION_GATE: unverified
NATIVE_TOOL_TEMPLATE_GATE: unverified
IPHONE_AIR_EVIDENCE: none
```

### Conditional research path

A future synthetic/public-safe untouched research evaluation may be prepared only after the executor confirms that the intended use is permitted under the applicable license conditions and that the exact model revision and license artifact are bound in the run provenance.

This review does **not** infer whether an executor, user, company or other legal entity is above or below the revenue threshold. It also does not convert a research use into a commercial/product permission.

### Product, commercial and redistribution path

Product integration, commercial use, publication of redistributed model artifacts, adapters or derivative packaging remain separately gated. Before such a step, the responsible party must verify the then-applicable entity/use conditions and satisfy relevant redistribution and notice obligations.

No iGentic manifest or decision may use `license_gate_status=approved` merely because this document exists. A future baseline must bind:

- an immutable model revision;
- the exact license reference applicable to that revision;
- the intended evidence/use class;
- a contemporaneous license review for that run.

If those facts are not established, the license gate remains `unverified` or `blocked` as appropriate.

## What this review does not authorize

This review does not authorize:

- downloading model weights or gated/private assets;
- adding model/runtime dependencies;
- an LFM2 baseline adapter or runner;
- training, fine-tuning or quantization;
- redistribution of model or adapter artifacts;
- commercial/product deployment;
- Swift or iOS integration;
- physical-device readiness or performance claims;
- moving policy, approval or execution authority into a model.

## Next technical gate

If LFM2 remains worth comparing after the required earlier untouched baselines, the next LFM2-specific technical slice must first:

1. pin an immutable `LiquidAI/LFM2-1.2B-Tool` model revision;
2. bind the exact tokenizer and native tool-template bytes/semantics at that revision;
3. re-check the license reference for that exact model revision;
4. define a dependency-free normalization contract without semantic repair;
5. only then propose an untouched Benchmark V0 host execution path.

No baseline result may be compared before these provenance boundaries are fixed.

## Sources

- LFM2-1.2B-Tool model page: https://huggingface.co/LiquidAI/LFM2-1.2B-Tool
- Immutable LFM Open License v1.0 reviewed here: https://huggingface.co/LiquidAI/LFM2-1.2B-Tool/blob/a6323e1f0ded5e89dd217d2a5b38d16380fc308d/LICENSE

## Stop rules

Stop and leave the gate unresolved if the exact model revision carries different terms, the intended use cannot be classified confidently, required redistribution obligations cannot be satisfied, or a decision would require inferring private organizational/legal facts. Escalate those questions outside this technical repository rather than encoding an unsupported approval.