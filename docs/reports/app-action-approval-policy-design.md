# App Action approval policy design note

Status: planning note

## Why this exists

`AppActionCoordinator` now follows the policy engine gate: approval is only requested when `decision.requiresApproval` is true. The next project step is to make that behavior configurable in setup and in an admin/settings area, instead of hiding it in runtime defaults.

Related source-backed decisions:
- Issue #185 records the owner decision that app actions should **not** be universally approval-required.
- `AgentKernel.handle(...)` already treats `requiresApproval` as the approval gate.
- `AppActionCoordinator` has now been aligned with the same rule.

## Recommended product shape

Keep the user-facing policy small and explicit:

- per action kind or action family
- clear approval requirement on/off state
- separate admin review/edit surface
- no hidden fallback that silently changes approval semantics

The policy should be readable by the runtime, but the runtime should not invent policy on its own.

## Suggested implementation order

1. Define the policy model and persistence location.
2. Add a setup step that creates or confirms the policy.
3. Add an admin/settings screen for later changes.
4. Wire `AppActionCoordinator` / `AgentKernel` to consume the stored policy.
5. Add tests for:
   - approval required
   - approval not required
   - blocked action

## Stop rules

- Do not add network-backed configuration.
- Do not make approval semantics depend on undocumented runtime heuristics.
- Do not widen the policy surface before the basic setup/admin flow exists.

## File references

- `ios/Sources/AgentCore/AppActionCoordinator.swift`
- `ios/Sources/AgentCore/AgentKernel.swift`
- `ios/Sources/AgentCore/PolicyEngine.swift`
- `docs/reports/issue-status-matrix.md`
- `docs/reports/approval-receipt-integration-decision.md`
- `docs/reports/runtime-budget-assessor-follow-up.md`
- `issues/185`