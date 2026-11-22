# iGentic external-project research

- [iOS 27 open-weight runtimes: MLX, llama.cpp/GGUF and Core AI](IOS27_OPEN_WEIGHT_RUNTIME_SURVEY_2026_11_22.md) — Exa+Apple+upstream code review, real iPhone apps, adapter usage, model triage and iGentic integration plan; not device-verified.

**Updated platform decision — 2026-11-22:** the product owner now requires **iOS 27.0+ only**, not legacy iOS 17–26 support. See the separate [iOS 27 migration PR #389](https://github.com/pokekarten/igentic-iphone/pull/389). Earlier proposals in these dated research documents to preserve an iOS-17 deployment target are superseded; their source observations remain historical evidence. No physical-device result is implied.

This folder holds **curated external projects**, rather than product code, dependency commitments, or device-readiness claims.

- [Technical reassessment and modernization priorities — 2026-11-21](TECHNICAL_REASSESSMENT_2026_11_21.md) — challenges earlier architecture assumptions, documents iOS 27 changes and gives a product-first test plan.
- [iPhone & mobile-agent open-source project atlas](IPHONE_AGENT_PROJECT_ATLAS.md) — physical iPhone MCP tools, on-phone agents, Shortcuts/App Intents, simulator testing, local models and GUI-agent research. Includes compatibility caveats, priority ranking and proposed safe evaluation.
- [Source-level ZIP audit: ipb, FluidAudio, Volocal and Pocket Agent — 2026-11-22](UPLOADED_UPSTREAM_SOURCE_REVIEW_2026_11_22.md) — inspected implementation paths, reproducibility/security limits, archive hashes and bounded integration gates. No external source is vendored or executed.
- [Seven uploaded upstream ZIP audits + iOS 27 modernization targets — 2026-11-22](SEVEN_UPLOADED_REPO_SOURCE_AUDIT_2026_11_22.md) — file-by-file static corpus, Resident/iCTRL/Apple source analysis and adoption priorities; source-only, no physical iPhone proof.
  
Use the evidence labels and privacy/publication rules in [the knowledge map](../KNOWLEDGE_MAP.md) and [source verification](../SOURCE_VERIFICATION.md). A third-party README is a **source claim**, not an iGentic physical-device test. Add findings to the existing atlas rather than creating duplicate lists.

Last source review: **2026-11-22** (source-only ZIP inspection; not device testing).
