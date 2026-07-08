# OpenRouter Provider Assessment

Status: source-backed provider assessment
Last reviewed: 2026-07-08

OpenRouter is an external routing layer for iGentic. It should be treated as a delegated cloud broker, not as a local runtime or a model vendor.

## What OpenRouter is

OpenRouter provides a unified API and marketplace for many third-party models. It routes a request to one of many downstream providers and returns a normalized response. The important distinction for iGentic is that OpenRouter does not itself host a foundation model; privacy and retention behavior depend on the downstream provider selected for the request.

Source set:
- https://openrouter.ai/docs
- https://openrouter.ai/enterprise
- https://openrouter.ai/terms

## API surface

Verified public API capabilities:

- OpenAI-compatible API surface.
- Streaming support.
- Function / tool calling support.
- Structured output support via `response_format`, depending on model.
- Vision support on supported downstream models.
- Routing controls such as `order`, `only`, `ignore`, `allow_fallbacks`, `require_parameters`, `data_collection`, `zdr`, `max_price` and `quantizations`.
- Auto Router, Pareto Router and Fusion-style multi-model routing options.
- Optional PKCE-based user auth flow for end-user connected accounts.
- Enterprise controls for org-level policy enforcement.

Source set:
- https://openrouter.ai/docs/api/reference/overview
- https://openrouter.ai/docs/guides/overview/models
- https://openrouter.ai/openrouter
- https://openrouter.ai/openrouter/auto

## Models and routing

OpenRouter aggregates access to a large catalog of downstream models from multiple vendors. The same logical model family can have different privacy, residency and training behavior depending on the provider, suffix, or routing policy.

Important routing concepts for iGentic:

- `:free` variants may exist for some models.
- `:thinking` and `:nitro` style suffixes can change price, performance or policy behavior.
- Some model entries are documented with very permissive logging or training language, so the model card must be checked before use.
- OpenRouter routing should never be treated as a guarantee that a specific downstream provider will be selected unless the request constrains it explicitly.

Source set:
- https://openrouter.ai/openrouter
- https://openrouter.ai/docs/guides/overview/models

## Authentication and account controls

OpenRouter supports API keys as the standard access method. It also documents a user-facing auth flow for linked user accounts, and enterprise account controls for organization-wide policy settings.

Practical implication for iGentic: account-level privacy settings are not enough on their own; request-level routing must still be constrained by the adapter and approval layer.

Source set:
- https://openrouter.ai/docs
- https://openrouter.ai/enterprise

## Data handling and privacy

OpenRouter's privacy position is more complex than a single-model provider because there are two administrative boundaries:

1. client to OpenRouter;
2. OpenRouter to downstream provider.

Publicly documented controls include zero data retention controls, request-level `data_collection` filtering, enterprise EU-region routing for eligible customers, and guardrails for policy enforcement.

The key iGentic constraint is that OpenRouter privacy guarantees are only as strong as the selected downstream provider and the current routing policy. ZDR must therefore be checked both at OpenRouter and at the effective downstream endpoint.

Source set:
- https://openrouter.ai/docs/guides/features/zdr
- https://openrouter.ai/enterprise
- https://openrouter.ai/blog/insights/ai-data-residency/
- https://openrouter.ai/blog/announcements/guardrails/

## iGentic fit

Recommended role: Tier 3 privacy cloud fallback, but only for carefully constrained non-sensitive or lower-sensitivity requests.

Good fit when:

- the request is explicitly delegated;
- the prompt can be minimized;
- the adapter can pin the provider or enforce a strict allow-list;
- the task does not require a guaranteed single-vendor privacy boundary;
- the workflow benefits from model comparison or automatic failover.

Not a fit when:

- the workflow requires one stable downstream processor;
- the data class is restricted-sensitive;
- the workflow depends on a guaranteed EU-only or ZDR-only path without checking the effective endpoint;
- the task should never transit a broker layer.

## Adapter notes for iGentic

OpenRouter should be normalized as a delegated broker with these rules:

- resolve the current ZDR and data-collection posture before sending sensitive data;
- store both the OpenRouter decision and the actual downstream provider in the AuditLog;
- never assume the default router is safe for sensitive data;
- use explicit provider allow-lists for approved workloads;
- reject free-tier routes that require privacy opt-in or training permission;
- keep the routing layer separate from local runtime logic.

## Unverified or not found in the reviewed docs

These items were not confirmed in the official sources reviewed for this file:

- a dedicated embeddings endpoint;
- a dedicated reranker endpoint;
- a stable public batch API description;
- a public DPA document link.

## Decision

OpenRouter is useful as a controlled broker for non-restricted cloud fallback and model routing experiments, but it should never be treated as a privacy-safe default path. For iGentic, the adapter must enforce explicit policy checks at both the OpenRouter layer and the chosen downstream provider layer.
