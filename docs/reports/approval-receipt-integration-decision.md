# ApprovalReceipt integration decision

Status: decided — integrated into live AgentKernel path

## Decision

`ApprovalReceipt` is returned by `AgentKernel.handle()` whenever approval is evaluated, and is `nil` only on the fast path where no approval is required. `DiagnosticSnapshotProducer` reads the same receipt object through `ApprovalStatusSummary`; it does not reconstruct approval state independently.

## Rationale

- Prevents the diagnostic snapshot's approval view from drifting out of sync with the live kernel decision.
- Preserves a single source of truth for approval metadata after the live wiring was added.
- Records the resolved state of the earlier audit finding without authorizing any new runtime work.

## Test coverage

Existing regression coverage already exercises this integration boundary in:

- `AgentKernelApprovalReceiptWiringTests.swift`
- `ApprovalReceiptTests.swift`

## Follow-up

No follow-up work is required for `ApprovalReceipt` itself. This document exists only to close the documentation gap and does not authorize additional implementation.
