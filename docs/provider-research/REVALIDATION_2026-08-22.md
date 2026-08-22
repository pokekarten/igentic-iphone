# Provider assumption revalidation — 2026-08-22

Status: source-backed delta review; does not replace the provider assessments

Purpose: re-check time-sensitive assumptions from the July 2026 provider research before they are reused by iGentic or another project. This note records only material deltas and confirmations. It is not an integration approval and does not change `PolicyEngine`, `ApprovalManager`, `AuditLog`, routing, credentials, billing, or provider configuration.

Baseline reviewed: `main` at `249faef5e4a2c85a438233c1cc43eb319e11a87f`.

## Reuse rule

Provider research is per-service, per-plan, per-region, and time-sensitive. Do not copy a provider label such as "free", "ZDR", "EU", or "no training" into another project without checking the exact current product path and account setting.

## Mistral — material correction

The July overview is too broad where it says API data is not used for training and associates ZDR mainly with a Scale plan.

Current official sources say:

- Mistral Studio/API **Free mode** may use input/output data to train or improve models unless the user opts out in the Admin Panel.
- **Pay-as-you-go** Studio/API usage is opted out of model training by default.
- Labs models can use data for training regardless of the normal opt-out setting.
- ZDR is available only with **pay-as-you-go** and only for supported **stateless** API calls.
- ZDR does not cover stateful products such as Agents, Batch files, Conversations, Libraries, `/v1/files`, Vibe Work, or Chat.
- Mistral states that data is hosted in the EU by default, with a US endpoint available explicitly; some features may involve transfers through documented subprocessors.

Implication for iGentic: do not treat "Mistral API" as one privacy class. The adapter/policy must distinguish Free mode, pay-as-you-go, Labs, stateful features, and ZDR state.

Official sources checked 2026-08-22:

- https://docs.mistral.ai/admin/monitor-comply/privacy-data-controls
- https://docs.mistral.ai/admin/monitor-comply/zero-data-retention
- https://help.mistral.ai/en/articles/347617-do-you-use-my-user-data-to-train-your-artificial-intelligence-models
- https://help.mistral.ai/en/articles/455207-can-i-opt-out-of-my-input-or-output-data-being-used-for-training
- https://help.mistral.ai/en/articles/347612-can-i-activate-zero-data-retention-zdr
- https://help.mistral.ai/en/articles/347629-where-do-you-store-my-data-or-my-organization-s-data

## Groq — core privacy assumptions confirmed; catalog is volatile

Current official sources still support the important July conclusions:

- inference customer data is not retained by default except limited reliability/abuse cases or features that require state;
- all customers may enable ZDR in Data Controls;
- retained customer data is stored in US GCP buckets;
- rate limits are organization-level and the exact limits can vary by account/model;
- a documented Free Plan exists, but model IDs and limits change and must not be hard-coded as long-lived assumptions.

The model catalog has already moved since the July assessment, which reinforces the existing rule to resolve live model IDs instead of treating the July table as canonical.

Official sources checked 2026-08-22:

- https://console.groq.com/docs/your-data
- https://console.groq.com/docs/rate-limits
- https://console.groq.com/docs/models

## OpenRouter — free route confirmed; privacy remains downstream-dependent

Current official sources confirm:

- a Free plan exists and currently advertises 25+ free models and 50 requests/day;
- OpenRouter states that it does not use inputs/outputs for its own model training;
- prompts are transmitted to the selected downstream model provider, whose retention/training policy still matters;
- workspace guardrails can enforce ZDR, model/provider restrictions, budget limits, prompt-injection defenses, and DLP;
- provider policy metadata remains heterogeneous, so a generic free route is not a privacy guarantee or a reproducible model identity.

Implication for iGentic: OpenRouter can remain a controlled broker for public/lower-sensitivity experiments, but an adapter must pin or constrain downstream providers whenever privacy properties matter.

Official sources checked 2026-08-22:

- https://openrouter.ai/pricing
- https://openrouter.ai/privacy/
- https://openrouter.ai/providers
- https://openrouter.ai/blog/announcements/guardrails/

## Gemini — deployment restriction confirmed; EEA data-handling nuance added

The July provider assessment correctly distinguishes Google AI Studio / Gemini Developer API / Vertex AI and correctly notes that API clients made available to users in the EEA, Switzerland, or UK may use only Paid Services.

A nuance matters for research reuse:

- the general Gemini pricing page still marks Free Tier data as "Used to improve our products: Yes" and Paid Tier as "No";
- however, the current Gemini Additional Terms state that for users in the EEA, Switzerland, or UK, the terms under the Paid Services data-handling section apply to **all** Services, including AI Studio and unpaid Gemini API quota, even when offered free of charge;
- the separate restriction remains that when an API Client is made available to users in those regions, only Paid Services may be used.

Implication for iGentic: because iGentic is a user-facing app, the conservative decision to avoid an unpaid Gemini deployment path remains appropriate. But cross-project consumers must not generalize that decision into "Gemini free always has identical data-use rules worldwide"; region and use mode matter.

Official sources checked 2026-08-22:

- https://ai.google.dev/gemini-api/terms
- https://ai.google.dev/gemini-api/docs/pricing

## Cross-project transfer lesson

The strongest reusable result is methodological rather than provider-specific:

1. record the exact service path, plan, region, endpoint class, and account privacy setting;
2. separate vendor claims from measured runtime evidence;
3. never promote a Free Tier or model catalog snapshot into a stable architecture dependency;
4. keep paid entitlement, free quota, and API billing as separate resource classes;
5. prefer current primary sources and record the revalidation date;
6. re-run this delta review before a provider becomes a default route.

This is particularly important when reusing iGentic research in workstation projects such as MacBook Neo: the device constraints, deployment model, user-facing status, and existing subscription resources differ from the iPhone product and can change the correct decision even when the provider facts are identical.
