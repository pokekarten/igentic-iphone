# Live issue-status matrix

Status: living audit companion

| Issue | Current GitHub status | Risk | Recommendation |
| --- | --- | --- | --- |
| #120 | closed / completed | low | MemoryStore classification/retention design is documented; keep closed. |
| #122 | closed / completed | low | RuntimeBudgetAssessor direction is complete; keep estimator non-authoritative. |
| #137 | closed / completed | low | ToolRegistry integration boundary is documented and reconciled with the implemented read-only wiring. |
| #121 | closed / completed | low | ToolRegistry diagnostic-only kernel wiring is implemented and covered by `AgentKernelToolRegistryWiringTests`. |
| #101 | resolved / closed | medium | Regression coverage exists for restricted-data bypass, pending approval, and approved-critical-action routing. |
| #103 | in progress | medium | Deterministic model-selection fixtures and validator exist; broader safety/language coverage remains separate work. |
| #114 | open | low | Keep as a docs-only starter issue. |
| #117 | open | low | Keep as a content-only starter issue. |
| #136 | open | low | Treat as UX polish; no behavior change required. |
| #144 | closed / completed | low | Decision-trace schema v1 is documented and aligned with the current selection engine. |
| #145 | open | medium | Diagnostics preview should consume the trace contract without changing selection behavior. |
| #146 | open | medium | Next implementation slice: deterministic trace value type and generator; no policy/runtime wiring. |
| #147 | open | low | Add renderer regression coverage after the trace model exists. |
| #148 | open | low | Add compact read-only SwiftUI trace panel after the trace model exists. |
| #149 | open | low | Pin trace-panel rendering once the UI surface exists. |
| #156 | resolved / closed | low | Diagnostic view regression coverage exists; docs-only cleanup is validated by repo structure checks. |
| #158 | resolved / closed | medium | App-action coordinator regression coverage exists for sensitive-payload escalation and approval blocking. |
| #175 | resolved / closed | low | Diagnostic snapshot regression coverage exists for the live `critical-reminder` synthetic snapshot. |
| #176 | resolved / closed | low | Diagnostic model-selection preview coverage exists. |
| #181 | closed / completed | low | RuntimeBudgetAssessor estimator is implemented; keep it non-authoritative. |
| #185 | open / planned | medium | Approval policy remains a later Phase 3 product/configuration lane: local setup defaults, settings/admin editing, then runtime consumption. |
| #142 | closed / completed | low | MemoryStore classification/retention design is documented; keep closed. |

## Maintenance rule

Update this file whenever an issue changes state, gets blocked, or becomes the
next implementation target. Keep it short and source-backed.