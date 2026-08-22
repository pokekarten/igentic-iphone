# Provider Research

Status: canonical index for external-provider evaluation

This directory holds source-backed, public-safe assessments of external AI providers that may be used as delegated fallbacks in iGentic.

## Read in this order

1. `MODEL_STRATEGY.md` — model authority and delegation rules.
2. `docs/local-runtime-review.md` — local vs delegated runtime boundary.
3. `docs/provider-research/REVALIDATION_2026-08-22.md` — current delta check for time-sensitive provider assumptions and cross-project reuse.
4. `docs/provider-research/GOOGLE_GEMINI.md` — Google Gemini / AI Studio assessment; read together with the revalidation note.
5. `docs/provider-research/GROQ.md` — Groq provider assessment; read together with the revalidation note.
6. `docs/provider-research/OPENROUTER.md` — OpenRouter provider assessment; read together with the revalidation note.

## Boundary

- These documents are about providers, not on-device model candidates.
- Providers are delegation targets, not local runtimes.
- No provider document may bypass `PolicyEngine`, `ApprovalManager`, or `AuditLog`.
- Unknown or time-sensitive values must stay unverified until checked against the live source.
- A dated provider assessment is a research snapshot, not a permanent statement about pricing, free tiers, model catalogs, retention, training, residency, or terms.

## Change rule

Keep provider assessments small, sourced, and easy to replace when the vendor docs change. Prefer a dated delta revalidation when only a few time-sensitive assumptions changed; rewrite a provider assessment only when the old structure itself has become misleading.