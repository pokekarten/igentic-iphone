# iGentic iPhone

<p align="center">
  <img src="assets/brand/logo-lockup-v3.svg" alt="iGentic logo lockup" width="760">
</p>

**iGentic iPhone** is an experimental, privacy-first iPhone AI Runtime Layer.

The goal is not to build another chatbot app. The goal is to explore the iPhone, especially iPhone Air, as the trust and control plane for a personal AI system: local first, approval gated, offline capable and able to delegate larger tasks only when policy allows it.

> Status: Experimental / Research Prototype

This repository is intentionally small and controller-friendly. It is designed for a workflow where ChatGPT acts as the project controller through the GitHub Connector, Codex creates narrow Draft PRs, and real iPhone testing decides what is actually usable.

## Mission

The iPhone becomes the private brain and control point of a personal AI setup.

It should:

- understand tasks locally,
- keep personal context on device whenever possible,
- use CPU, GPU and Neural Engine consciously,
- trigger app actions only through safe APIs,
- ask for approval before critical actions,
- delegate larger jobs to trusted devices or external AI only after policy checks,
- write audit logs for meaningful decisions.

## Core thesis

The iPhone is not the strongest computer in the personal AI setup. It is the most trusted one. It holds identity, permissions, context and private data. Compute can be delegated, but control should remain local.

## Architecture

```text
User / Siri / Shortcut / Widget / App
        ↓
iPhone AI Layer Controller
        ↓
Intent Understanding
        ↓
Local Context Engine
        ↓
Task Router
        ↓
Local Execution or Delegation
        ↓
Action Layer via App Intents / Shortcuts
        ↓
Audit Log / Approval / Result Verification
```

## Repo operating model

This repo follows the lessons learned from the Pokekartenkiste project:

1. GitHub is the source of truth.
2. ChatGPT controls the project state and reviews PRs.
3. Codex is used sparingly for small Draft PR slices.
4. Every task needs an allowlist of files and clear stop rules.
5. Privacy, policy and auditability come before autonomy.
6. Real device tests are required for iPhone-specific claims.

See:

- `AGENTS.md`
- `PROJECT_STATE.md`
- `ROADMAP.md`
- `GOVERNANCE.md`
- `MODEL_STRATEGY.md`
- `docs/GITHUB_CONTROL.md`
- `docs/VALIDATION.md`
- `docs/WORKFLOWS.md`
- `docs/apple-api-review.md`
- `docs/local-runtime-review.md`
- `docs/app-intents-safety.md`
- `docs/CHATGPT_NEXT_TASK.md`
- `docs/CODEX_NEXT_TASK.md`
- `docs/SPARSAMKEIT.md`
- `docs/SOURCE_VERIFICATION.md`

## Brand and community

The master brand is **iGentic**. `iGentic iPhone` is the current research track.

Brand, design and community decisions are part of the repository because this is an open-source project with a long-term identity and IP direction.

- Brand foundation: `docs/brand/BRAND.md`
- Corporate identity: `docs/brand/CORPORATE_IDENTITY.md`
- Brand asset manifest: `docs/brand/BRAND_ASSET_MANIFEST.md`
- Brand review workflow: `docs/brand/BRAND_REVIEW_WORKFLOW.md`
- Social identity: `docs/brand/SOCIAL_IDENTITY.md`
- Design system: `docs/brand/DESIGN_SYSTEM.md`
- Logo brief: `docs/brand/LOGO_BRIEF.md`
- Logo usage rules: `docs/brand/LOGO_USAGE.md`
- Community strategy: `docs/community/COMMUNITY_STRATEGY.md`
- Communication channels: `docs/community/COMMUNICATION_CHANNELS.md`
- Social media playbook: `docs/community/SOCIAL_MEDIA_PLAYBOOK.md`
- GitHub control runbook: `docs/GITHUB_CONTROL.md`
- Validation contract: `docs/VALIDATION.md`
- Workflow overview: `docs/WORKFLOWS.md`
- Preferred brand assets: `assets/brand/logo-symbol-v3.svg`, `assets/brand/logo-lockup-v3.svg`, `assets/social/instagram-profile-v3.svg`

Community direction: **GitHub-first, social-supported**. Instagram, X and LinkedIn are used for discovery and build-in-public storytelling. GitHub remains the canonical place for decisions, issues, pull requests and roadmap.

## New contributors

Start with:

- `docs/community/CONTRIBUTOR_STARTER_GUIDE.md`
- `docs/community/GOOD_FIRST_ISSUES.md`
- `CONTRIBUTING.md`
- `GOVERNANCE.md`
- `docs/GITHUB_CONTROL.md`
- `docs/VALIDATION.md`
- `docs/WORKFLOWS.md`

Recommended first lanes:

- documentation clarity,
- design and logo feedback,
- repo validation improvements,
- policy tests,
- synthetic device test reports,
- safe metadata-only runtime stubs.

Do not start with real private data, external AI provider integrations, model weights, signing files or broad rewrites.

## Model strategy

Initial model strategy is hybrid:

- Apple Foundation Models / Apple-native APIs for native iPhone integration.
- Qwen3-1.7B-class models as potential lightweight routers.
- Qwen3-4B-class models as potential controllable local agent brains.
- Embedding models for local RAG and search.
- Larger models only through Mac, Home Server, Private Cloud Compute or external AI when policy allows it.

No model weights are committed to this repo.

## Privacy-first principles

- Local Only is the default research mode.
- Private raw data must not be sent to external models automatically.
- Critical actions require user approval.
- Drafting is safer than sending.
- Delegation must use minimization, redaction and audit logs.
- Level 4 data such as health, finance, identity and keys is blocked from automatic delegation.

## Operating modes

| Mode | Description |
| --- | --- |
| Local Only | No internet, no external models, no cloud sync by default. |
| Trusted Devices | Delegation only to owned devices such as Mac or Home Server. |
| External AI | Per-task opt-in with preview, minimization and audit log. |

## Roadmap

See the full roadmap in `ROADMAP.md`.

### Phase 0: Research & Architecture

- source verification: `docs/SOURCE_VERIFICATION.md`,
- Apple API review: `docs/apple-api-review.md`,
- local runtime review: `docs/local-runtime-review.md`,
- privacy model definition: `ios/Sources/AgentCore/DataClassification.swift` and `MODEL_STRATEGY.md`,
- brand/community foundation: `docs/brand/` and `docs/community/`.

### Phase 1: Local Agent Kernel

- `TaskRouter`,
- `PolicyEngine`,
- `AuditLog`,
- `DataClassification`,
- `ApprovalManager`,
- `MemoryStore` safe stub,
- `DelegationBroker` policy-gated stub.

### Phase 2: Diagnostic iPhone Shell

- minimal SwiftUI shell,
- local-only diagnostic report,
- iPhone Air execution budget checks,
- device test template.

### Phase 3: Local Model Runtime

- Apple-native runtime evaluation,
- MLX Swift / MLC-LLM / llama.cpp evaluation,
- Qwen / Llama / Gemma / Phi candidates.

### Phase 4: App Intents

- safe actions,
- draft-first patterns,
- approval before execution.

### Phase 5: Delegation

- Mac Worker,
- Home Server Worker,
- privacy broker,
- result verification.

## Community and support

This project is open to careful, privacy-conscious collaboration.

Before contributing, read:

- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`
- `SUPPORT.md`
- `GOVERNANCE.md`
- `docs/GITHUB_CONTROL.md`
- `docs/VALIDATION.md`
- `docs/WORKFLOWS.md`
- `docs/community/COMMUNITY_STRATEGY.md`

Do not post private data, secrets, credentials, real messages, contacts, calendars, health data or financial data in public issues or pull requests. Use synthetic data for examples and tests.

## License

Code and documentation are licensed under the Apache License 2.0 unless otherwise noted. Brand and logo usage must also follow `docs/brand/LOGO_USAGE.md`.

## Safety disclaimer

This repository is not medical, legal or financial advice. It is a research prototype. Security and privacy architecture come before autonomy.
