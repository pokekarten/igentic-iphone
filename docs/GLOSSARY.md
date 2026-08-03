# iGentic Glossary

This glossary explains iGentic privacy, control and runtime terms for new contributors. iGentic is an experimental, privacy-first research prototype; these terms describe the current safety model and evidence language, not production readiness.

## Local Only

Work that should stay on the iPhone or inside the local AgentCore boundary. Local-only behavior must not require a network provider or real private data.

## Trusted Devices

User-controlled devices that may later help with larger tasks after policy and approval checks. The current repository records this as planning metadata only; it does not prove device pairing or real delegation.

## External AI

A model or service outside the local trusted-device boundary. External AI must be treated as higher risk and must not receive private data without a separate, explicit policy and approval design.

## Approval Gated

A decision path that pauses before a sensitive or high-risk action and requires an explicit approval state before routing can continue.

## Controlled Delegation

A restricted handoff from the local controller to another runtime only when policy, data sensitivity, action risk and approval state allow it.

## Model Proposal

A structured suggestion produced by a model, such as an intent, clarification, refusal or typed tool-call proposal. A proposal is not authorization and does not execute an action. Deterministic Swift remains authoritative for policy, approval, schema validation, audit and execution.

## Audit Log

A privacy-sensitive record of safety-related events and metadata. Task-received audit events no longer store raw task text, and approval summaries are metadata-only. New audit fields must remain bounded, reviewable and free of private prompt content unless an explicitly approved design says otherwise.

## Data Classification

The category that describes how sensitive input or metadata is. Classification helps decide whether work can stay local, needs approval or must be blocked.

## Action Risk

The risk level of an intended action. Higher-risk actions require stronger policy checks and may require approval before routing continues.

## Synthetic Data

Artificial test data created only for validation and examples. Synthetic data must not contain real private messages, credentials, health data, financial data or other personal records.

## Immutable Benchmark

A versioned test set that must not be edited in place or used to generate, paraphrase, translate or tune training data. The current model-research benchmark is documented in `docs/model-research/IGENTIC_ACTION_BENCHMARK_V0.md`.

## Evidence Class

A label describing what one record can actually prove. iGentic keeps `source_claim`, `software_contract`, `compile_result`, `host_runtime_result`, `simulator_result`, `physical_device_result` and `assumption` separate. A later evidence class must not be inferred from an earlier one.

## Physical-Device Result

A result measured on one exact physical device, app build, backend or model artifact and configuration under `docs/model-research/IPHONE_AIR_DEVICE_EVIDENCE_PROTOCOL.md`. Model cards, conversion success, desktop runs and simulator runs are not physical-device results.

## PolicyEngine

The AgentCore component that evaluates whether a request is allowed, blocked or requires approval based on policy inputs.

## ApprovalManager

The component that records the current approval status and exposes whether routing may continue.

## ApprovalReceipt

The live receipt returned by `AgentKernel.handle()` whenever approval is evaluated, and the single source of truth for `DiagnosticSnapshotProducer`; see `docs/reports/approval-receipt-integration-decision.md`.

## DelegationBroker

The component that represents whether metadata-only delegation is blocked, requires approval or is allowed under the current safety rules.

## MemoryStore

The current in-memory storage stub. It is volatile and does not add persistence, databases or file storage. See `docs/reports/memory-store-integration-decision.md` for the deliberate pre-integration stub decision.

## RiskScorer

The component that summarizes risk as a bounded score with reasons so tests and diagnostic views can explain why approval may be required.

## RuntimeBudget

A metadata-only planning model for execution class, expected locality and estimated memory class. It does not measure hardware, load models or prove iPhone performance. See `docs/reports/runtime-budget-integration-decision.md` for the deliberate pre-integration stub decision.
