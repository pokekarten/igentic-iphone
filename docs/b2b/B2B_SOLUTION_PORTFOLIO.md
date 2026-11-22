# iGentic B2B solution portfolio — evidence-first proposal

**Scope:** product architecture and synthetic, locally browsable discovery content. **As of:** 2026-11-22. **Status:** proposed, not a commercial offering or release.

## Strategy

iGentic can become a **privacy-first mobile agent trust layer** plus domain-specific workbenches. The iPhone owns user-facing intent, policy evaluation and action approval. Each enterprise domain owns its data, authorization decisions, model validation and business transactions in its **own** service. An LLM suggests; deterministic code decides.

Do not confuse a GitHub repository, successful fixture test, simulator build or research result with a customer-ready B2B solution. This public catalog intentionally omits private repository internals and customer information.

## Six business hypotheses and proof levels

| Solution | Potential buyer / job | Reusable evidence in this repository | Still missing / not claimed | Priority |
| --- | --- | --- | --- | --- |
| **Enterprise Agent Trust** | Enterprise developers and regulated operations: user-visible, approval-gated mobile workflows | Swift PolicyEngine, approval/draft/receipt boundaries and deterministic tests; App Intents preview in the iOS 27 integration PR | Tenant separation, SSO/RBAC, managed configuration, external SDK/API, security assessment, production audit/export | **P0 platform** |
| **Fieldglass Field Evidence** | Inspectors, property managers and loss-adjustment teams: capture and review synthetic field findings | Standalone Fieldglass workbench in #394, simulator-based Vision/OCR, editable draft, receipts and MCP fixture tests | Production capture privacy model, consent, actual physical deployment, evidence provenance, retention/access policy, backend connection | **P0 vertical pilot** |
| **Insurance Risk Assistant** | Underwriting and CAT-risk teams: turn a permissioned property survey into a bounded risk-review draft | Agent policy/draft mechanics plus separate insurance research/data engines outside this repository | No iPhone-to-domain integration, no calibrated risk result, no coverage decision or regulatory capital claim, source licenses and model/version approval | **P1 design** |
| **Managed Device Diagnostics** | IT/fleet operators: inspect a designated owned diagnostic app through approved support flows | iPhone Connect fixed-app MCP diagnostics, tool schema validation, leases and synthetic receipts | Real connected iPhone ChatGPT invocation, fleet identity and enrollment, MDM permissions, remote-network reliability, admin audit | **P1 pilot** |
| **Private Model Evaluation** | Enterprise AI teams: compare locally eligible models under fixed guardrails | Apple Foundation Models preview, file-admission tests, fixed synthetic evaluations and local research | Production model rollout, hardware eligibility matrix, data-processing contracts, signed artifact chain and accuracy/security benchmarks | **P1 pilot** |
| **Retail Inventory Assistant** | Card shops and distributors: provenance-aware catalog lookup and inventory review | Generic local review/discovery UI; separate domain catalog/market-data research exists | No catalog adapter, rights clearance, merchant identity, actual scan/stock/POS integration or write approval | **P2 research** |

A domain connection is **never authorized** merely because its research repository exists. Treat private repositories as independently controlled products; the public iGentic tree does not copy their internals, credentials, private examples, source datasets or model weights.

## Recommended product architecture

```text
Enterprise user / owned iOS application
  -> App Intent or in-app task (only declared app-owned actions)
  -> local data classification and minimal context
  -> model produces a typed *proposal*, never an execution command
  -> deterministic PolicyEngine / scope / risk / tenant gate
  -> human review + explicit scoped approval for any write
  -> independently authorized business adapter (future, allowlisted)
  -> external domain service validates tenant, role and request again
  -> idempotency and tamper-evident result/evidence receipt
  -> app verifies outcome and exposes bounded audit to its owner
```

**Trust boundaries:** the mobile app is not a replacement for server-side authorization. No cross-app generic device control, no background iPhone supervision promises, no assumption that Apple Intelligence is available solely from iOS version. Tenant context, identities, role assignment, permitted datasets, model choice and retention policy must not be inferred from model output. Fail closed on missing identity, authorization, destination, device readiness, network receipt or human confirmation.

## Proposed portable enterprise contract (not implemented)

A future versioned adapter would need *at minimum*: `tenantContext`, `actorRole`, `actionType`, `inputDataClassification`, `scopeId`, `policyVersion`, `proposalFingerprint`, `approvalReceipt`, `idempotencyKey`, `executionReceipt`, `expiresAt` and a bounded audit record. These are **design fields**, not currently exposed iGentic APIs. Reject forged cross-tenant input, stale approval, unlisted tool, replay, lost response and unsupported offline execution in negative tests before piloting. Keep personal/regulated data out of fixtures and logs.

## Practical rollout and evidence gates

1. **P0, common trust layer:** test a synthetic read-only corporate case in the native app; add explicit local tenant/role fixtures and verify deny-by-default on missing or mismatched scope. No enterprise SSO or audit-export marketing before implementation.
2. **P0, Fieldglass vertical:** inspect one synthetic property finding, edit a draft, cancel it, and verify a privacy-minimized receipt through a fixed-owned-app tool. Repeat on a signed physical device with owner authorization. No personal photos or claims data.
3. **P1, insurance proof:** a fictional building survey moves from an approved draft to a mocked domain service which validates the same tenant and returns a synthetic risk-review **draft only**. No live exposure location, premium, solvency or claim decisions.
4. **P1, managed device:** prove an authorized read-only device/app state via USB before separate wireless/cellular tests; evaluate Apple managed app configuration and enterprise enrollment, never imply MDM bypass or unrestricted taps.
5. **P1, model evaluation:** benchmark supported locale/device combinations; freeze synthetic datasets and licenses; prove proposed actions remain downstream of Swift policy independent of model backend.
6. **P2, commerce:** permissioned, rights-cleared catalog lookup first; defer merchant inventory changes, payments and sensitive account access.

Commercial packaging is a **hypothesis**: Trust SDK/API, Field Evidence workbench, and domain adapters as separately licensed modules. Do not assert revenue, customers, certifications, SLA, enterprise readiness or GDPR/AI Act compliance without evidence and legal review.

## Platform research references (capability is not adoption)

- Apple App Intents: https://developer.apple.com/documentation/appintents
- Apple Foundation Models and device availability: https://developer.apple.com/documentation/foundationmodels
- Managed app distribution, app configuration and per-app networking: https://support.apple.com/guide/deployment/distribute-managed-apps-dep575bfed86/web
- Public source-governance example: https://github.com/pokekarten/OpenCatastrophe-data
- Current implementation scope: [iGentic iOS 27 integration PR #395](https://github.com/pokekarten/igentic-iphone/pull/395) and [Fieldglass/iPhone Connect PR #394](https://github.com/pokekarten/igentic-iphone/pull/394)
