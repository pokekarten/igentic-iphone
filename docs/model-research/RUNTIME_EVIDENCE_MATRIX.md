# iGentic Runtime Evidence Matrix

Status: evidence contract, no runtime or device claim  
Parent: Issue #83  
Last reviewed: 2026-08-03

## Purpose

This document defines how iGentic records runtime compatibility evidence for Apple system backends and custom-model artifacts. It prevents source-code support, conversion success, host execution, simulator execution and physical iPhone Air measurements from being treated as equivalent evidence.

Models remain proposal generators only. `PolicyEngine`, `ApprovalManager`, schema validation, audit and execution remain deterministic Swift authority.

## Non-interchangeable evidence classes

| Evidence class | What it proves | What it does not prove |
| --- | --- | --- |
| `source_claim` | A primary source or model/runtime publisher states that a capability exists. | Compile success, local execution or iPhone Air behavior. |
| `software_contract` | Repository code, schemas or tests define an expected interface or safety boundary. | That a model artifact compiles or runs. |
| `compile_result` | One exact artifact was converted or compiled with one exact toolchain. | Host, simulator or physical-device execution. |
| `host_runtime_result` | One exact artifact executed on the recorded non-iPhone host. | Simulator behavior or physical iPhone Air performance. |
| `simulator_result` | One exact build and artifact executed in an Apple simulator. | Physical-device memory, latency, battery, thermal or crash behavior. |
| `physical_device_result` | One exact build and artifact was measured on the recorded physical iPhone under the device protocol. | Generalization to another device, OS, artifact or configuration. |
| `assumption` | A clearly labeled hypothesis guides the next test. | Any verified capability or measurement. |

Evidence may advance only in this order when applicable:

```text
source claim or software contract
→ compile result
→ host runtime result
→ simulator result
→ physical device result
```

Skipping a class is allowed only when it is technically inapplicable and the reason is recorded. A later class must never be inferred from an earlier one.

## Status vocabulary

Use only these values for execution stages:

- `not_assessed`
- `planned`
- `blocked`
- `failed`
- `passed`
- `not_applicable`

Use `unknown` for a field that cannot yet be established. Do not use optimistic terms such as “supported” or “ready” without a linked evidence record.

## Required record fields

Every backend/artifact combination must have a separate record. A record contains:

- stable record ID;
- evidence class and review status;
- backend ID and exact backend version;
- model ID and immutable model revision, or `system_managed` for an Apple-provided model whose revision is not exposed;
- license name, exact reference and gate status;
- tokenizer ID, tokenizer revision and file hashes where applicable;
- prompt, chat and tool-template revision;
- source artifact format;
- export and quantization format;
- exporter/converter ID and version;
- runtime implementation status;
- compile status;
- host runtime status;
- simulator status;
- physical-device status;
- supported capabilities actually tested;
- context and output limits actually used;
- decoding settings used;
- cancellation behavior and measured cancellation latency when available;
- timeout behavior and configured timeout;
- known unsupported operators, kernels or features;
- failure and recovery observations;
- deterministic rollback or fallback path;
- artifact hash and package size where an artifact exists;
- app/build revision for simulator or device evidence;
- exact evidence source, result artifact and date;
- reviewer and limitations.

Unknown values remain explicit. An absent field must not be interpreted as success.

## Artifact identity rules

A runtime result is valid only for the exact recorded combination of:

- model revision;
- tokenizer and template revisions;
- exported artifact bytes and SHA-256;
- quantization configuration;
- exporter and runtime versions;
- app/build revision;
- context, output and decoding configuration;
- execution environment.

Changing any one of these creates a new evidence record or a new revision linked to the previous record. A filename alone is not artifact identity.

## Backend categories

### Apple system backend

Apple Foundation Models is recorded independently from custom-model runtimes. The model may be system-managed, but the record must still identify:

- OS and SDK version;
- framework/API version where exposed;
- availability result;
- locale and device requirements checked by the app;
- structured-output or generation capabilities actually exercised;
- cancellation, timeout and fallback behavior;
- physical-device evidence only when measured under the device protocol.

System availability does not imply the same behavior across OS versions, locales or hardware.

### Custom-model runtime

Each custom artifact and backend pair is separate, for example:

- FunctionGemma 270M + GGUF + llama.cpp;
- Qwen3 0.6B + GGUF + llama.cpp;
- FunctionGemma 270M + ExecuTorch artifact;
- Qwen3 0.6B + Core ML artifact.

A runtime repository supporting a model family is only a `source_claim` until the exact pinned artifact is converted and tested.

## Initial planning matrix

These rows are planning records only. They contain no compile, runtime, simulator or physical-device result.

| Record | Backend/artifact | Evidence class | Compile | Host | Simulator | Physical iPhone Air | Next bounded test |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `apple-fm-system-v0` | Apple Foundation Models, system-managed model | `source_claim` | `not_applicable` | `not_assessed` | `not_assessed` | `not_assessed` | Compile a minimal proposal-only capability probe with deterministic fallback. |
| `functiongemma-llamacpp-gguf-v0` | `google/functiongemma-270m-it`, pinned revision required, GGUF/llama.cpp | `source_claim` | `not_assessed` | `not_assessed` | `not_assessed` | `not_assessed` | Pin license, model, tokenizer and template; then perform a compile/conversion-only check. |
| `qwen3-06b-llamacpp-gguf-v0` | `Qwen/Qwen3-0.6B`, pinned revision required, GGUF/llama.cpp | `source_claim` | `not_assessed` | `not_assessed` | `not_assessed` | `not_assessed` | Produce an untouched normalized baseline before any training or device claim. |
| `functiongemma-coreml-v0` | `google/functiongemma-270m-it`, Core ML candidate | `assumption` | `planned` | `not_assessed` | `not_assessed` | `not_assessed` | Execute only the compile-feasibility scope authorized by Issue #111. |

The rows above are not evidence that conversion will work, that a runtime can execute the artifact, or that the artifact is suitable for the iPhone Air.

## Canonical record template

```yaml
record_id: <stable-id>
record_revision: 1
evidence_class: source_claim
review_status: pending
backend:
  id: <backend-id>
  version: <immutable-version-or-unknown>
model:
  id: <canonical-model-id-or-system-managed>
  revision: <immutable-revision-or-system-managed>
license:
  name: <license>
  reference: <exact-public-reference>
  gate_status: pending
tokenizer:
  id: <id-or-not-applicable>
  revision: <revision-or-not-applicable>
  sha256: {}
templates:
  prompt_revision: <revision>
  chat_revision: <revision>
  tool_revision: <revision>
artifact:
  source_format: <format>
  export_format: <format-or-not-applicable>
  quantization: <exact-config-or-none>
  sha256: <sha256-or-null>
  size_bytes: <integer-or-null>
converter:
  id: <id-or-not-applicable>
  version: <version-or-not-applicable>
stages:
  runtime_implementation: not_assessed
  compile: not_assessed
  host_runtime: not_assessed
  simulator: not_assessed
  physical_device: not_assessed
execution:
  capabilities_tested: []
  context_tokens: null
  maximum_output_tokens: null
  decoding_configuration_sha256: null
  cancellation_status: not_assessed
  cancellation_latency_ms: null
  timeout_seconds: null
  timeout_status: not_assessed
limitations:
  unsupported_operators_or_kernels: []
  known_failures: []
rollback:
  path: deterministic-router
  verified: false
evidence:
  source_references: []
  result_artifact_reference: null
  result_artifact_sha256: null
  observed_at: null
  reviewer: null
  notes: []
```

## Compile evidence

A compile result must record:

- exact input artifact hashes;
- exact converter/toolchain versions;
- complete conversion configuration hash;
- target platform and minimum OS;
- exit status;
- unsupported operators or graph transformations;
- warnings that may affect correctness;
- output artifact hash and size;
- sanitized log reference and hash;
- whether tokenizer and template packaging were included and verified.

A successful compile proves only that the toolchain produced an artifact. It does not prove output quality or runtime execution.

## Runtime, cancellation and timeout evidence

A host, simulator or device result must state what capability was exercised, such as schema-constrained proposal generation. It must separately record:

- load success or failure;
- generation success or failure;
- malformed-output behavior;
- cancellation request point and completion latency;
- timeout configuration and observed outcome;
- memory or resource failure where observable;
- recovery behavior after cancellation, timeout, crash or OOM;
- deterministic fallback behavior.

Cancellation and rollback are first-class gates. An artifact that cannot be stopped safely or leaves the app in an unknown state cannot advance.

## Physical-device boundary

Only a result produced under `docs/model-research/IPHONE_AIR_DEVICE_EVIDENCE_PROTOCOL.md` may set `physical_device: passed` or `physical_device: failed`. The record must link to a validated device-result JSON and its SHA-256.

Do not derive physical-device claims from:

- model parameter count;
- advertised context length;
- Mac, Android or server benchmarks;
- converter success;
- simulator execution;
- runtime source-code support;
- vendor measurements on another device.

## Rollback and fallback

Every record must define a non-model fallback before runtime testing. The default is the deterministic router and existing local safety path. A runtime experiment must not remove or bypass policy, approval, audit or typed routing.

Rollback evidence records whether the app can:

- cancel the active generation;
- release or quarantine the failed runtime;
- return to deterministic behavior;
- avoid replaying a side effect;
- preserve a privacy-safe audit event.

## Evidence sources and dates

Source references must be exact and dated. Repository documents may link to the candidate manifest and primary sources, but a record must identify the specific claim it relies on. Source review dates do not become runtime result dates.

When evidence becomes stale, retain the old record and create a new revision. Do not silently replace a failed or superseded result.

## Publication rules

Public records may include hashes, versions, sanitized logs, aggregate measurements and public-safe prompts. They must not include:

- model weights or gated artifacts;
- credentials or signed URLs;
- private prompts, messages or user data;
- serial numbers, UDIDs or account identifiers;
- screenshots containing personal information;
- unsupported device or production-readiness claims.

A missing measurement remains `null` with status `not_assessed`; it must never be pre-filled from expectation.
