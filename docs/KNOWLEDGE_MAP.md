# iGentic Knowledge Map

Status: canonical navigation contract  
Last reviewed: 2026-06-22

This document tells contributors and automation where authoritative iGentic knowledge belongs. It is an index and routing contract, not a duplicate project summary.

## Source-of-truth order

Use the first available source in this order:

1. current verified GitHub source: repository files, issue or pull-request state, exact-head checks and merged commits;
2. durable contracts in this product repository;
3. compact private operating state in `pokekarten/agentic-private-brain`;
4. internal memory or prior chat context;
5. explicit assumptions.

Current GitHub evidence always overrides stale documentation, Brain state or remembered context. A merged or closed target must never be revived from copied text.

## Repository boundaries

| Repository | Stores | Must not store |
| --- | --- | --- |
| `pokekarten/igentic-iphone` | Product architecture, safety contracts, model strategy, benchmark and evaluator contracts, public decisions and verified evidence rules | Secrets, private user data, raw chats, model weights, transient lane state |
| `pokekarten/agentic-private-brain` | Compact private target routing, verified handoff state and durable private coordination rules | Product documentation, copied diffs, research reports, credentials or raw conversations |
| `pokekarten/agentic-dev-playbook` | Sanitized reusable methods only after they are proven in project work | Live iGentic status or project-private details |
| `pokekarten/agentic-slm-lab` | Reusable public-safe model, dataset and evaluation patterns | iGentic private data, product state or unreviewed exports |

No additional repository is required merely to preserve current iGentic research knowledge.

## Canonical product documents

| Topic | Canonical source | Notes |
| --- | --- | --- |
| Mission and contributor entry point | `README.md` | Concise orientation only |
| Durable project baseline and evidence boundary | `PROJECT_STATE.md` | Never stores a live PR number, head SHA or lane stage |
| Roadmap | `ROADMAP.md` | Product phases, not live execution state |
| Agent and contribution rules | `AGENTS.md`, `CONTRIBUTING.md`, `GOVERNANCE.md` | Human and automation behavior |
| Privacy and model authority | `MODEL_STRATEGY.md` | Models propose; deterministic policy and approval remain authoritative |
| Runtime comparison | `docs/local-runtime-review.md` | Runtime research and prerequisites |
| Apple API evidence | `docs/apple-api-review.md`, `docs/SOURCE_VERIFICATION.md` | Source-backed platform claims |
| App-action safety | `docs/app-intents-safety.md` | Draft-first and approval-gated action rules |
| Validation and workflows | `docs/VALIDATION.md`, `docs/WORKFLOWS.md` | Required repository checks and evidence |
| Durable execution protocol | `docs/CHATGPT_NEXT_TASK.md` | Stable lane rules, not the live target |
| Live iGentic target and lane stage | current GitHub issue or pull request, with authorized private Brain routing where applicable | Mutable routing state only; never copy private identifiers into public docs |
| Model research index | `docs/model-research/README.md` | Entry point for candidates, benchmarks and future evidence |

When two durable files disagree, open one narrow reconciliation issue. Do not silently choose the more convenient statement.

## Durable knowledge versus mutable state

Durable repository knowledge includes:

- architecture and safety invariants;
- accepted model and runtime evaluation rules;
- versioned schemas, benchmarks and test contracts;
- source references with review dates and evidence limits;
- decisions, stop rules and migration rules;
- verified device reports that clearly identify device, OS, build and test method.

Mutable state includes:

- active issue or pull request;
- current branch, head SHA, checks, reviews and mergeability;
- lane stage and next authorized role;
- temporary blocker or runner state.

Mutable state belongs in current GitHub resources and compact Brain routing. Do not copy it into `PROJECT_STATE.md`, `ROADMAP.md`, research indexes or README sections.

## Evidence classes

Always label or clearly distinguish these classes:

1. **Source evidence** — what an official source, model card or license states.
2. **Repository evidence** — what current code, tests, workflows and merged files prove.
3. **Runtime compatibility evidence** — a model or operator can be converted, built or loaded in a named runtime.
4. **Simulator or host evidence** — behavior observed on Mac, CI or simulator.
5. **Physical-device evidence** — behavior observed on a named iPhone, OS and build.
6. **Decision** — the chosen project direction based on the available evidence.
7. **Assumption** — an unresolved claim that must not be presented as verified.

Runtime support, a vendor benchmark, a Mac run or simulator success is not physical iPhone Air evidence.

## Update and anti-duplication rules

- Update the canonical topic file instead of creating a second summary.
- Link to detailed contracts; do not copy their complete contents into indexes.
- Record a verification date for time-sensitive platform, model and license claims.
- Preserve old benchmark and schema versions. Corrections require a new version or explicit migration note.
- Store raw experiment output outside the durable contract unless it is reviewed, public-safe and tied to an immutable configuration.
- Never commit model weights, provider credentials, real messages, contacts, files, device identifiers or other private data.
- When a source changes, update the affected decision and its review trigger; do not rewrite historical evidence silently.

## Work selection

Before implementing:

1. verify the named issue or pull request from current GitHub source;
2. authorized controllers additionally verify the current private Brain routing without copying private identifiers into public artifacts;
3. confirm there is only one active iGentic implementation PR;
4. read the canonical files for the target topic;
5. change only the allowed files;
6. re-read the exact written resource;
7. use GitHub Actions as the authoritative execution evidence for repository checks.

Every pull request body must retain the repository's `Summary`, `Scope`, `Validation`, `Safety` and `Follow-up` markers. It must mention `python3 scripts/validate_repo_structure.py` and either `cd ios && swift test` or an explicit reason that Swift tests are not applicable. These markers are part of the executable evidence contract, not optional prose.

## Knowledge-export sequence

The current model-research sequence is:

```text
candidate and license manifest
→ immutable synthetic benchmark
→ benchmark validator and backend-neutral evaluator
→ untouched backend baselines
→ dataset and training governance
→ one evidence-selected specialization run
→ runtime/export compatibility
→ physical iPhone Air evidence
```

Fine-tuning, runtime integration and device-readiness claims must not skip the earlier contracts.
