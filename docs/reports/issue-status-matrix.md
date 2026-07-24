# Live issue-status matrix

Status: living audit companion

| Issue | Current GitHub status | Risk | Recommendation |
| --- | --- | --- | --- |
| #120 | open | high | Close the gap with a dedicated classification/retention decision before any MemoryStore wiring. |
| #137 | open / blocked | high | Keep as the gating spec for ToolRegistry integration. |
| #121 | open / blocked | high | Do not implement until #137 is settled. |
| #101 | resolved / closed | medium | Regression coverage exists in `ios/Tests/AgentCoreTests/AgentKernelTaskRouterBypassRegressionTests.swift` (restricted-data bypass block, pending-approval block, approved-critical-action routing). No further action. |
| #103 | in progress | medium | Deterministic model-selection tie-break fixtures and the standalone validator were added under `docs/model-selection/` and `scripts/`. |
| #114 | open | low | Keep as a docs-only starter issue. |
| #117 | open | low | Keep as a content-only starter issue. |
| #136 | open | low | Treat as UX polish; no behavior change required. |
| #156 | resolved / closed | low | Regression coverage lives in `ios/Tests/iGenticAppTests/DiagnosticViewStateTests.swift`; docs-only cleanup is still validated by `python3 scripts/validate_repo_structure.py`. |
| #158 | resolved / closed | medium | Regression coverage lives in `ios/Tests/AgentCoreTests/AppActionCoordinatorTests.swift`; it exercises sensitive-payload escalation and approval blocking. |
| #175 | resolved / closed | low | Regression coverage lives in `ios/Tests/iGenticAppTests/DiagnosticViewStateTests.swift`; it covers the live `critical-reminder` synthetic snapshot. |
| #176 | resolved / closed | low | Regression coverage lives in `ios/Tests/iGenticAppTests/DiagnosticViewStateTests.swift`; it covers the diagnostic-only model selection preview. |

## Maintenance rule

Update this file whenever an issue changes state, gets blocked, or becomes the
next implementation target. Keep it short and source-backed.
