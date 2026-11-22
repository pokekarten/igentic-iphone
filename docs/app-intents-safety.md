# App Intents safety notes

Status: safety guidance with a read-only iOS 27 App Intents implementation in the integration PR stack. Device-specific behavior still requires physical iPhone acceptance.

## Purpose

This document defines the safety boundary for future App Intents work in iGentic. It does not authorize real actions. The first implementation must remain draft-first, approval-first, local-first, synthetic and auditable.

## Platform boundary

Apple describes App Intents as the framework for exposing app actions and content to system experiences such as Shortcuts and Siri. In iGentic, that platform integration is only the outer action interface. The repository's own policy, data-classification, approval and audit layers remain authoritative.

An `AppIntent` implementation performs work through its `perform()` method. iGentic must treat entry into real side-effecting work as an execution boundary, not as permission to act.

Apple also provides platform concepts for user-facing intent dialogs and authentication policy. These can support communication and authentication, but they do not replace iGentic's explicit risk decision, approval receipt or audit record.

## Required draft-first flow

Future action work must follow this order:

1. Parse the request without executing an external or destructive action.
2. Classify the data and action risk through the iGentic policy layer.
3. Build a local, side-effect-free draft or preview.
4. Show the exact intended action, target and meaningful consequences.
5. Request explicit approval for critical, destructive, privacy-sensitive or externally visible actions.
6. Re-check that the approved draft still matches the current action immediately before execution.
7. Execute only the narrow approved action.
8. Write a metadata-minimized audit result containing the decision, approval state and outcome.

Approval must never be inferred from opening the app, invoking Siri, selecting a shortcut, or previously approving a similar action.

## Safety rules

- Draft creation and action execution must be separate operations.
- A draft must not send, publish, delete, purchase, transfer, share or delegate anything.
- Critical actions require a fresh approval tied to the exact draft.
- A changed target, payload, recipient, destination or risk level invalidates earlier approval.
- Level 4 data remains blocked from automatic external delegation.
- Examples, tests and screenshots must use synthetic data only.
- Logs should contain metadata and decisions, not raw private content.
- Authentication and approval are separate checks: device authentication does not by itself mean the user approved the exact action.
- Failure, cancellation or missing approval must produce no external side effect.

## Synthetic examples

### Draft a message

Allowed research flow:

- Create a local draft addressed to `example-contact` with synthetic text.
- Display the draft and its intended destination.
- Stop before sending.

Not allowed in the first slice:

- Reading real contacts or messages.
- Sending automatically.
- Treating draft creation as send approval.

### Destructive action

A synthetic request to delete `example-record-001` must remain blocked until the policy layer classifies it, the user sees the exact record identifier and consequence, and a fresh approval is recorded. Cancellation or mismatch leaves the synthetic record unchanged.

### Sensitive external action

A request containing synthetic health, financial, identity or credential-like data must not be delegated externally. The safe outcome is a local block or a local draft that removes sensitive content before any later review.

## First implementation constraints

The first App Intents code slice, when separately approved, should be limited to one non-destructive synthetic demo intent. It must not add networking, persistence, provider calls, real message sending, real deletion, purchases, financial operations, health actions, credential access or external delegation.

Before any real-action work, the implementation must define:

- the exact action and side effect,
- the data classification,
- the risk level,
- the approval UI and receipt,
- cancellation behavior,
- audit fields,
- tests proving that missing or stale approval blocks execution,
- device-test evidence for any iPhone-specific claim.

## Implemented versus not implemented

In the current iOS 27 integration draft, `AgentCore` has a local draft/approval pipeline, and the diagnostic app registers two read-only system App Intents plus an `AppShortcutsProvider`: a static diagnostic response and an Apple on-device language-model **availability** check. Both use the local `PolicyEngine` read gate. The second only inspects whether the installed system model is eligible/ready; no user prompt, generated text or network request is used. System-level simulator tests verify the registration and dispatch but cannot establish physical-device eligibility or Siri voice behavior.

Still **not implemented**: any remotely authorized generic iPhone action, Shortcut-driven persistent write, action-specific approval receipt for a system write, enterprise management, hosted model fallback, automatic signing, or verified physical iPhone App Intents behavior. No real messages, contacts, calendars, files, health data or financial data are accessed by these read-only intents.

## Review checklist

A future App Intents pull request is not ready unless all answers are yes:

- Is the action synthetic or non-destructive?
- Is draft creation separate from execution?
- Does the iGentic policy layer run before execution?
- Is approval tied to the exact current draft?
- Does cancellation guarantee no side effect?
- Are logs metadata-minimized?
- Are tests synthetic and free of private data?
- Are platform claims linked to Apple documentation or real device evidence?
- Does the pull request avoid signing, entitlements and unrelated integrations?

## Official Apple references

- App Intents framework: https://developer.apple.com/documentation/appintents
- `AppIntent`: https://developer.apple.com/documentation/appintents/appintent
- `IntentDialog`: https://developer.apple.com/documentation/appintents/intentdialog
- `IntentAuthenticationPolicy`: https://developer.apple.com/documentation/appintents/intentauthenticationpolicy
- App Shortcuts: https://developer.apple.com/documentation/appintents/app-shortcuts

These references describe platform capabilities. iGentic's stricter approval, privacy and audit requirements are project safety policy, not claims that Apple enforces the complete iGentic flow automatically.
