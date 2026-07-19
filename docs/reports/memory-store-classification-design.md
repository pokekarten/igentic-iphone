# MemoryStore classification and retention design

Status: draft decision for issue #142

## Decision

Before `MemoryStore` is wired into `AgentKernel`, each stored value must receive a
classification at write time, and the store must define whether highly sensitive
values may be persisted at all.

## Proposed model

- `MemoryEntry` should gain a `dataSensitivity: DataSensitivityLevel` field.
- The value should be assigned when the entry is written, using the same
  classification logic pattern that `AgentKernel.handle` uses for its effective
  classification: take the higher of the task classification and the detector
  result.
- `.session` and `.task` isolation alone are not sufficient to replace data
  classification.

## Open questions that must be resolved by implementation follow-up

1. Should restricted sensitive data be rejected at write time rather than stored?
2. Should retention/deletion behavior differ by `dataSensitivity`?
3. What minimum test set is required before any wiring:
   - classification-threshold tests
   - scope-isolation tests
   - rejection-path tests, if storage blocking is chosen

## Non-goals

- No code changes in this document.
- No wiring of `MemoryStore` into `AgentKernel`.
- No change to `AuditEvent` or `DataClassification` in this issue.

## Next step

Once this design is reviewed, open a separate implementation issue that wires
`MemoryStore` into `AgentKernel` against the agreed threshold and retention
rules.
