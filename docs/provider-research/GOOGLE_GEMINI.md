# Google Gemini / Google AI Studio Provider Assessment

Status: source-backed provider assessment
Last reviewed: 2026-07-08

Google is an external AI provider for iGentic. It is best treated as a delegated cloud fallback with a strict billing and policy gate, not as a local runtime.

## What Google is

Google's Gemini offering is split across at least three closely related products with different terms and privacy rules:

- Google AI Studio
- Gemini API / Gemini Developer API
- Vertex AI / Gemini on Google Cloud

That split matters because the free / unpaid path is not governed the same way as paid Gemini API or Vertex AI usage.

Source set:
- https://ai.google.dev/gemini-api/docs
- https://ai.google.dev/aistudio
- https://ai.google.dev/gemini-api/terms
- https://cloud.google.com/vertex-ai/generative-ai/docs/learn/privacy

## API surface

Verified public API capabilities in the reviewed Google docs include:

- REST-based Gemini API access
- official SDK support
- streaming
- function / tool calling
- structured outputs / JSON-style output control
- multimodal input across text, image, video and audio depending on the model
- context caching
- batch support on selected models
- Google Search / Maps grounding on selected models

The public docs also show that some models support a 1M token context window and that preview models typically have billing enabled and shorter deprecation windows than stable models.

Source set:
- https://ai.google.dev/gemini-api/docs
- https://ai.google.dev/gemini-api/docs/models
- https://ai.google.dev/gemini-api/docs/pricing

## Terms and usage restrictions

Google's Gemini API terms state that Google AI Studio and the Gemini API are for developers building with Google AI models for professional or business purposes, not for consumer use.

The same terms also state that when making API clients available to users in the European Economic Area, Switzerland, or the United Kingdom, only Paid Services may be used.

For iGentic, that means the free / unpaid path must be treated as disallowed for any user-facing deployment in those regions.

Source set:
- https://ai.google.dev/gemini-api/terms

## Pricing snapshot

The pricing page shows that the free tier is available for selected models, but the exact catalog and numbers change over time. A few current examples from the reviewed page:

| Model / tier example | Free tier | Paid tier |
|---|---:|---:|
| Gemini 2.5 Flash | input free, output free | $0.30 input / $2.50 output per 1M tokens |
| Gemini 2.5 Flash-Lite | input free, output free | $0.10 input / $0.40 output per 1M tokens |
| Gemini 3.5 Flash | input free, output free | $2.70 input / $16.20 output per 1M tokens |

The pricing page also shows that some model families support free-tier grounding with Google Search and/or Maps, while others do not. For Gemini 2.5 Flash, the page shows free-tier Google Search grounding up to 500 RPD shared with Flash-Lite, then paid overage.

Source set:
- https://ai.google.dev/gemini-api/docs/pricing

## Data handling and privacy

The reviewed pricing page explicitly marks free-tier usage as "Used to improve our products" while paid-tier usage is marked "No" for the same row. That makes the free tier unsuitable for privacy-first delegation.

Because this provider document is meant for iGentic delegation, the safe policy conclusion is simple:

- free / unpaid Gemini usage is not acceptable for iGentic delegated requests;
- paid Gemini API or Vertex AI may be acceptable only when the request has already passed policy, approval and data-minimization checks;
- raw restricted-sensitive data should not be sent unless the task-specific policy explicitly allows it.

Source set:
- https://ai.google.dev/gemini-api/docs/pricing
- https://ai.google.dev/gemini-api/terms

## Compliance notes

Google Cloud documents SOC 2 coverage and states that Google Cloud products used with PHI require the Google Business Associate Agreement and aligned compliance controls.

For iGentic, that means compliance is a paid-cloud discussion, not a free-tier discussion.

Source set:
- https://cloud.google.com/security/compliance/soc-2
- https://cloud.google.com/security/compliance/hipaa-compliance
- https://cloud.google.com/security/compliance

## iGentic fit

Recommended role: Tier 3 privacy cloud fallback, but only on paid Gemini API or Vertex AI and only for non-blocked data classes.

Good fit when:

- the task can be delegated explicitly,
- the payload can be minimized,
- billing is enabled and checked before every request,
- the request is not using the free / unpaid path,
- the task does not require local-only execution.

Not a fit when:

- the task is user-facing in the EEA, Switzerland, or the United Kingdom and would rely on free services,
- the task depends on consumer-style usage,
- the task contains restricted-sensitive data that should stay inside the trusted boundary,
- the team cannot keep the product split between AI Studio, Gemini API and Vertex AI clear in code.

## Adapter notes for iGentic

Google should be normalized as a delegated provider with these rules:

- hard-fail if billing is not enabled for the chosen backend;
- record whether the call used Gemini API or Vertex AI;
- treat free / unpaid usage as blocked for iGentic delegation;
- resolve model IDs from the live docs instead of hard-coding unstable preview names;
- treat Google Search / Maps grounding as remote execution, not local tool calling;
- keep preview models behind an explicit stability gate.

## Unverified or not found in the reviewed docs

These items were not confirmed in the official sources reviewed for this file:

- a dedicated reranker endpoint;
- a universal free-tier quota table that stays constant across models;
- any blanket guarantee that free-tier data is never used for product improvement;
- any assumption that AI Studio, Gemini API and Vertex AI share identical privacy terms.

## Decision

Google Gemini is technically strong and may be useful as a paid, policy-gated cloud fallback, but the free / unpaid path is incompatible with iGentic's privacy-first model.
