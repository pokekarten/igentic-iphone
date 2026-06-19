# iGentic Glossary

This glossary explains iGentic privacy and runtime terms for new contributors. iGentic is an experimental, privacy-first research prototype; these terms describe the current safety model and planning language, not production readiness.

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

## Audit Log

A metadata-only record of meaningful safety decisions. Audit entries should help explain what happened without storing raw private user content.

## Data Classification

The category that describes how sensitive input or metadata is. Classification helps decide whether work can stay local, needs approval or must be blocked.

## Action Risk

The risk level of an intended action. Higher-risk actions require stronger policy checks and may require approval before routing continues.

## Synthetic Data

Artificial test data created only for validation and examples. Synthetic data must not contain real private messages, credentials, health data, financial data or other personal records.

## PolicyEngine

The AgentCore component that evaluates whether a request is allowed, blocked or requires approval based on policy inputs.

## ApprovalManager

The component that records the current approval status and exposes whether routing may continue.

## DelegationBroker

The component that represents whether metadata-only delegation is blocked, requires approval or is allowed under the current safety rules.

## MemoryStore

The current in-memory storage stub. It is volatile and does not add persistence, databases or file storage.

## RiskScorer

The component that summarizes risk as a bounded score with reasons so tests and diagnostic views can explain why approval may be required.

## RuntimeBudget

A metadata-only planning model for execution class, expected locality and estimated memory class. It does not measure hardware, load models or prove iPhone performance.
