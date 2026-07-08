# Groq Provider Assessment

Status: source-backed provider assessment
Last reviewed: 2026-07-08

Groq is an external AI provider for iGentic. It is best treated as a high-speed delegated cloud fallback, not as a local runtime.

## What Groq is

GroqCloud provides hosted inference over openly available models on Groq's own LPU infrastructure. The current public model catalog includes models such as Llama 3.1 8B, Llama 3.3 70B, GPT OSS 120B, GPT OSS 20B, Llama 4 Scout 17B, Whisper Large V3, Whisper Large V3 Turbo, Qwen3-32B and Groq Compound systems. The public docs present Groq as an inference platform rather than a vendor of proprietary foundation models.

Source set:
- https://console.groq.com/docs/overview
- https://console.groq.com/docs/models
- https://groq.com/

## API surface

Verified public API capabilities:

- OpenAI-compatible Chat Completions endpoint at `https://api.groq.com/openai/v1/chat/completions`.
- Responses API support, described by Groq as OpenAI-compatible and currently in beta.
- Streaming support.
- Function / tool calling support.
- Vision support on supported models.
- Speech-to-text and text-to-speech endpoints.
- Built-in tools for agentic workflows.
- MCP-based tool discovery / execution support.

Source set:
- https://console.groq.com/docs/api-reference
- https://console.groq.com/docs/changelog
- https://console.groq.com/docs/vision
- https://console.groq.com/docs/speech-to-text
- https://console.groq.com/docs/tool-use/overview

## Built-in tools

Groq documents two compound systems:

- `groq/compound` — full-featured system with up to 10 tool calls per request.
- `groq/compound-mini` — streamlined system with up to 1 tool call and lower latency.

Groq's built-in tools documentation also covers web search, code execution, website visiting, browser automation, and Wolfram Alpha integration. Groq states that built-in tools are server-side and require zero orchestration from the caller.

Source set:
- https://console.groq.com/docs/compound
- https://console.groq.com/docs/compound/systems
- https://console.groq.com/docs/tool-use/built-in-tools
- https://console.groq.com/docs/tool-use/built-in-tools/web-search
- https://console.groq.com/docs/tool-use/built-in-tools/wolfram-alpha
- https://groq.com/pricing

## Models, speed and prices

The public models page lists both speed and Developer-plan pricing for active models. Examples from the current docs include:

| Model | Speed | Context | Price |
|---|---:|---:|---|
| Llama 3.1 8B Instant | ~560 tps | 131,072 | $0.05 input / $0.08 output per 1M tokens |
| Llama 3.3 70B Versatile | ~280 tps | 131,072 | $0.59 input / $0.79 output per 1M tokens |
| GPT OSS 120B | ~500 tps | 131,072 | $0.15 input / $0.60 output per 1M tokens |
| GPT OSS 20B | ~1000 tps | 131,072 | $0.075 input / $0.30 output per 1M tokens |
| Llama 4 Scout 17B 16E | ~750 tps | 131,072 | $0.11 input / $0.34 output per 1M tokens |
| Whisper Large V3 | n/a | n/a | $0.111 per hour |
| Whisper Large V3 Turbo | n/a | n/a | $0.04 per hour |
| Groq Compound / Compound Mini | ~450 tps | 131,072 | priced through underlying models and tools |

The exact catalog changes frequently, so implementation code should resolve model IDs from the live models endpoint instead of hard-coding assumptions.

Source set:
- https://console.groq.com/docs/models
- https://groq.com/pricing
- https://console.groq.com/docs/models.md

## Authentication and rate limits

Groq uses API keys for access. The public docs state that rate limits apply at the organization level, not per individual user, and that cached tokens do not count toward rate limits. The exact current limits for a specific account are visible in the account limits page.

Source set:
- https://console.groq.com/docs/quickstart
- https://console.groq.com/docs/rate-limits

## Data handling and privacy

Groq's public data page states:

- inference requests are not retained by default;
- Zero Data Retention (ZDR) can be enabled in Data Controls;
- batch jobs and fine-tuning require retained application state;
- temporary logs may be kept for reliability or abuse investigations for up to 30 days;
- customer data is retained in Google Cloud Platform buckets in the United States;
- SCCs are referenced for cross-border transfers where applicable.

This makes Groq usable as a privacy-controlled cloud fallback, but it is still US-hosted cloud processing and not a local-only path.

Source set:
- https://console.groq.com/docs/your-data
- https://console.groq.com/docs/legal/customer-data-processing-addendum

## Contractual and compliance notes

Groq's services agreement says customers are responsible for authorizing any agentic access to data, applications and systems, and for complying with legal or regulatory requirements that apply to use of agentic features.

Groq's compound-system docs state that `groq/compound` and `groq/compound-mini` should not be used for processing protected health information and are not HIPAA Covered Cloud Services under Groq's Business Associate Addendum at this time.

For iGentic, that means Groq must not be treated as HIPAA-ready by default, even if a third-party product marketing page claims otherwise.

Source set:
- https://console.groq.com/docs/legal/services-agreement
- https://console.groq.com/docs/compound/systems/compound
- https://console.groq.com/docs/compound/systems/compound-mini
- https://console.groq.com/docs/legal

## iGentic fit

Recommended role: Tier 3 privacy cloud fallback for non-restricted data.

Good fit when:

- the task can be delegated explicitly,
- the prompt can be minimized,
- ZDR is enabled where appropriate,
- the data class is below restricted-sensitive scope,
- fast responses are more important than EU-hosting.

Not a fit when:

- the task requires local-only execution,
- the task involves restricted sensitive data that must not leave the trusted boundary,
- the use case depends on EU data residency by default,
- the workflow needs embedding or reranking support from Groq specifically.

## Adapter notes for iGentic

Groq should be normalized as a delegated provider with these rules:

- treat built-in tools as remote execution, not local tool calling;
- inspect org-level rate limits before scheduling parallel requests;
- gate batch use behind a separate approval path, because batch retention is different from inference;
- record whether ZDR is enabled before any escalation;
- resolve model IDs from the live Groq catalog instead of baking prices or limits into code.

## Unverified or not found in the reviewed docs

These items were not confirmed in the official sources reviewed for this file:

- a dedicated embeddings endpoint;
- a dedicated reranker endpoint;
- a stable free-tier rate table in the docs excerpts;
- any claim about ownership changes or an NVIDIA partnership.

## Decision

Groq is a strong speed-first delegated provider and a good secondary cloud fallback for iGentic, provided that privacy controls, ZDR status, data class and HIPAA constraints are enforced by the adapter and approval layer.
