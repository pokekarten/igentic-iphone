# Live issue-status matrix

Status: living audit companion

| Issue | Current GitHub status | Risk | Recommendation |
| --- | --- | --- | --- |
| #120 | closed / completed | low | MemoryStore classification/retention design is documented; keep closed. |
| #137 | closed / completed | low | ToolRegistry integration boundaries are documented; keep the kernel wiring blocked until a new implementation scope is justified. |
| #121 | closed / completed | low | ToolRegistry diagnostic-only kernel wiring is implemented and covered by `AgentKernelToolRegistryWiringTests`. |
| #122 | closed / completed | low | RuntimeBudgetAssessor direction is complete; keep estimator non-authoritative. |
| #101 | resolved / closed | medium | Regression coverage exists for restricted-data bypass, pending approval, and approved-critical-action routing. |
| #103 | in progress | medium | Deterministic model-selection fixtures and validator exist; broader safety/language coverage remains separate work. |
| #114 | open | low | Keep as a docs-only starter issue. |
| #117 | open | low | Keep as a content-only starter issue. |
| #136 | closed / completed | low | Diagnostic snapshot labels are now clearer; the blocked + requires-approval case reads unambiguously. |
| #144 | closed / completed | low | Decision-trace schema v1 is documented and aligned with the current selection engine. |
| #145 | open | medium | Diagnostics preview should consume the trace contract without changing selection behavior. |
| #146 | closed / completed | medium | Trace value type and generator are implemented and tested. |
| #147 | open | low | Add renderer regression coverage after the trace model exists. |
| #148 | open | low | Add compact read-only SwiftUI trace panel after the trace model exists. |
| #149 | open | low | Pin trace-panel rendering once the UI surface exists. |
| #156 | resolved / closed | low | Diagnostic view regression coverage exists; docs-only cleanup is validated by repo structure checks. |
| #157 | closed / completed | medium | Shared effective-classification logic and AppActionCoordinator sensitive-data scanning are implemented and tested. |
| #158 | resolved / closed | medium | App-action coordinator regression coverage exists for sensitive-payload escalation and approval blocking. |
| #175 | resolved / closed | low | Diagnostic snapshot regression coverage exists for the live `critical-reminder` synthetic snapshot. |
| #176 | resolved / closed | low | Diagnostic model-selection preview coverage exists. |
| #181 | closed / completed | low | RuntimeBudgetAssessor estimator is implemented; keep it non-authoritative. |
| #185 | closed / completed | low | Local approval-policy persistence, editing, settings consumption and first-run confirmation are complete; keep this configuration lane closed and scope any future AppAction execution separately. |
| #207 | closed / completed | low | MemoryStore sensitivity hardening is merged in PR #208. |
| #142 | closed / completed | low | MemoryStore classification/retention design is documented; keep closed. |

## Maintenance rule

Update this file whenever an issue changes state, gets blocked, or becomes the
next implementation target. Keep it short and source-backed.
