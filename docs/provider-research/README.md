# Provider Research

Status: canonical index for external-provider evaluation

This directory holds source-backed, public-safe assessments of external AI providers that may be used as delegated fallbacks in iGentic.

## Read in this order

1. `../../MODEL_STRATEGY.md` — model authority and delegation rules.
2. `../local-runtime-review.md` — local vs delegated runtime boundary.
3. `GROQ.md` — current Groq provider assessment.

## Boundary

- These documents are about providers, not on-device model candidates.
- Providers are delegation targets, not local runtimes.
- No provider document may bypass `PolicyEngine`, `ApprovalManager`, or `AuditLog`.
- Unknown or time-sensitive values must stay unverified until checked against the live source.

## Change rule

Keep provider assessments small, sourced, and easy to replace when the vendor docs change.
