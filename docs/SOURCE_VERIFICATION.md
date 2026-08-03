# Source Verification

This repository separates verified facts, executable contracts, observed runtime results and assumptions.

## Rule

For fast-moving topics, verify current official sources before making durable architecture claims. Then record the evidence class so a source statement cannot silently become a runtime or device claim.

Fast-moving topics include:

- Apple Intelligence APIs and Foundation Models;
- Core AI and Core ML;
- iOS background behavior;
- iPhone Air hardware and OS behavior;
- local model runtimes and conversion toolchains;
- model candidates, licenses and artifacts;
- MCP and agent tooling.

## Source quality

| Source class | Meaning |
| --- | --- |
| Apple official | Apple developer, support, security or platform documentation |
| Project official | Runtime documentation, model card, license or release documentation |
| Research | Paper, benchmark or reproducible technical analysis |
| Community signal | Issue, discussion, benchmark repository or blog post used only for discovery |
| Assumption | Plausible hypothesis that still requires a bounded test |

Community signals must not replace primary sources when a primary source exists.

## Non-interchangeable evidence classes

Use the canonical evidence classes from `docs/KNOWLEDGE_MAP.md` and `docs/model-research/RUNTIME_EVIDENCE_MATRIX.md`:

- `source_claim` — a cited source states that a capability exists;
- `software_contract` — repository code, schemas or tests define expected behavior;
- `compile_result` — one exact artifact was converted or compiled;
- `host_runtime_result` — one exact artifact executed on a recorded non-iPhone host;
- `simulator_result` — one exact artifact executed in an Apple simulator;
- `physical_device_result` — one exact build and artifact was measured on a recorded physical device;
- `assumption` — a clearly labeled hypothesis for the next test.

A later evidence class must never be inferred from an earlier one. Runtime source-code support, a model-card claim, desktop execution or simulator success is not physical iPhone Air evidence.

## Required wording

Use precise labels such as:

- `Apple-officially documented`;
- `project-officially documented`;
- `software contract only`;
- `compile result only`;
- `host runtime result`;
- `simulator result`;
- `physical-device result`;
- `assumption / next test`.

Avoid broad terms such as “supported”, “ready” or “works on iPhone” without exact evidence identity and scope.

## Canonical model-research sources

- candidate and license claims: `docs/model-research/IPHONE_AIR_MODEL_CANDIDATES.md`
- immutable benchmark and evaluator: `docs/model-research/IGENTIC_ACTION_BENCHMARK_V0.md` and `docs/model-research/EVALUATOR_CONTRACT_V0.md`
- dataset and training provenance: `docs/model-research/DATASET_GOVERNANCE.md` and `docs/model-research/TRAINING_RUN_CONTRACT.md`
- runtime evidence: `docs/model-research/RUNTIME_EVIDENCE_MATRIX.md`
- physical-device measurements: `docs/model-research/IPHONE_AIR_DEVICE_EVIDENCE_PROTOCOL.md`

These contracts define how evidence is recorded; they do not claim that a model has been trained, exported or run on a physical iPhone Air.

## Do not overstate

Do not overstate:

- iOS background behavior;
- model-size viability;
- API or locale availability;
- local data access;
- action automation;
- conversion success;
- cancellation or recovery behavior;
- latency, memory, battery or thermal performance.

Unknown or unobserved values remain `unknown`, `not_assessed`, `not_run` or `null` as defined by the relevant contract.

## Update path

When a durable source claim changes:

1. update the canonical topic document;
2. preserve or supersede the old evidence record rather than rewriting history silently;
3. update overview files such as `MODEL_STRATEGY.md` only when their summary becomes inaccurate;
4. keep live PR, check, branch and mergeability state out of durable documentation.
