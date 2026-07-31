import AgentCore
import XCTest
@testable import iGenticApp

final class DiagnosticViewStateTests: XCTestCase {
    func testDiagnosticViewStateMapsSyntheticScenarioReport() {
        let state = DiagnosticViewState()

        XCTAssertEqual(state.rows.count, 4)
        XCTAssertEqual(state.privacyNotice, "No private content")
        XCTAssertEqual(state.auditStatus, "Synthetic metadata only")
        XCTAssertEqual(state.runtimeStatus, "Synthetic preview snapshot loaded")
        XCTAssertEqual(state.snapshotSource, "Synthetic preview result (critical-reminder)")
        XCTAssertEqual(state.auditEventsDescription, "Detailed audit events are not available in this shell")

        let generatedAt = state.snapshotFields.first { $0.label == "Generated at" }
        XCTAssertEqual(generatedAt?.value, "2026-07-07T08:00:00Z")

        let privacyMode = state.snapshotFields.first { $0.label == "Privacy mode" }
        XCTAssertEqual(privacyMode?.value, "Trusted Devices")

        let policyAllowed = state.snapshotFields.first { $0.label == "Policy allow gate" }
        XCTAssertEqual(policyAllowed?.value, "Yes")

        let policyRequiresApproval = state.snapshotFields.first { $0.label == "Approval gate" }
        XCTAssertEqual(policyRequiresApproval?.value, "Yes")

        let approvalStatus = state.snapshotFields.first { $0.label == "Approval status" }
        XCTAssertEqual(approvalStatus?.value, "Pending")

        let approvalMayContinueRouting = state.snapshotFields.first { $0.label == "Approval may continue routing" }
        XCTAssertEqual(approvalMayContinueRouting?.value, "No")

        let auditEventCount = state.snapshotFields.first { $0.label == "Audit event count" }
        XCTAssertEqual(auditEventCount?.value, "3")

        let auditHighestSensitivity = state.snapshotFields.first { $0.label == "Audit highest sensitivity" }
        XCTAssertEqual(auditHighestSensitivity?.value, "Public data")

        let delegationOutcome = state.snapshotFields.first { $0.label == "Delegation outcome" }
        XCTAssertEqual(delegationOutcome?.value, "Requires Approval")

        let riskValue = state.snapshotFields.first { $0.label == "Risk value" }
        XCTAssertEqual(riskValue?.value, "7")

        let riskRequiresApproval = state.snapshotFields.first { $0.label == "Risk requires explicit approval" }
        XCTAssertEqual(riskRequiresApproval?.value, "Yes")

        let riskReasonCount = state.snapshotFields.first { $0.label == "Risk reason count" }
        XCTAssertEqual(riskReasonCount?.value, "3")

        let policySchema = state.approvalPolicyFields.first { $0.label == "Policy schema" }
        XCTAssertEqual(policySchema?.value, "v1")

        let sendMessageApproval = state.approvalPolicyFields.first { $0.label == "Send message approval required" }
        XCTAssertEqual(sendMessageApproval?.value, "No")

        let deleteRecordApproval = state.approvalPolicyFields.first { $0.label == "Delete record approval required" }
        XCTAssertEqual(deleteRecordApproval?.value, "Yes")

        let updateRecordApproval = state.approvalPolicyFields.first { $0.label == "Update record approval required" }
        XCTAssertEqual(updateRecordApproval?.value, "Yes")

        let exportDataApproval = state.approvalPolicyFields.first { $0.label == "Export data approval required" }
        XCTAssertEqual(exportDataApproval?.value, "Yes")

        let traceSchema = state.modelSelectionFields.first { $0.label == "Trace schema" }
        XCTAssertEqual(traceSchema?.value, "v1")

        let request = state.modelSelectionFields.first { $0.label == "Selection request" }
        XCTAssertEqual(request?.value, "latencyBudget=Low, contextSize=2048, toolUsageRequired=Yes")

        let modelSelectionSelected = state.modelSelectionFields.first { $0.label == "Selected model id" }
        XCTAssertEqual(modelSelectionSelected?.value, "model-beta")

        let modelSelectionReason = state.modelSelectionFields.first { $0.label == "Selection reason" }
        XCTAssertEqual(modelSelectionReason?.value, "Lowest Latency Valid Model")

        let modelSelectionScore = state.modelSelectionFields.first { $0.label == "Selected score" }
        XCTAssertEqual(modelSelectionScore?.value, "0.73")

        let fallbackReason = state.modelSelectionFields.first { $0.label == "Fallback reason" }
        XCTAssertEqual(fallbackReason?.value, "None")

        let modelAlpha = state.modelSelectionFields.first { $0.label == "Candidate: model-alpha" }
        XCTAssertEqual(modelAlpha?.value, "Eligible · Score 0.73 · Components: eval 0.45, latency 0.16, capability 0.12 · Latency 120 ms")

        let modelDelta = state.modelSelectionFields.first { $0.label == "Candidate: model-delta" }
        XCTAssertEqual(modelDelta?.value, "Rejected · Reasons: Context Size Exceeds Max Context Tokens, Tool Usage Required But Unsupported · Latency 30 ms")

        let localOnly = state.rows.first { $0.id == "local-only-summary" }
        XCTAssertEqual(localOnly?.route, "Blocked")
        XCTAssertEqual(localOnly?.policy, "Blocked")
        XCTAssertEqual(localOnly?.approval, "Not Required")
        XCTAssertEqual(localOnly?.delegation, "Blocked")

        let critical = state.rows.first { $0.id == "critical-reminder" }
        XCTAssertEqual(critical?.route, "Approval Required")
        XCTAssertEqual(critical?.policy, "Approval required")
        XCTAssertEqual(critical?.approval, "Pending")
        XCTAssertEqual(critical?.delegation, "Approval Required")

        let external = state.rows.first { $0.id == "external-provider-check" }
        XCTAssertEqual(external?.route, "Approval Required")
        XCTAssertEqual(external?.policy, "Approval required")
        XCTAssertEqual(external?.approval, "Pending")
        XCTAssertEqual(external?.delegation, "Approval Required")

        let trustedDevice = state.rows.first { $0.id == "trusted-device-metadata" }
        XCTAssertEqual(trustedDevice?.route, "Local Tool")
        XCTAssertEqual(trustedDevice?.policy, "Allowed")
        XCTAssertEqual(trustedDevice?.approval, "Not Required")
        XCTAssertEqual(trustedDevice?.delegation, "Allowed Metadata Only")
    }

    func testDiagnosticViewStateDoesNotExposeSyntheticTaskText() {
        let state = DiagnosticViewState(report: ScenarioRunner().report())
        let visibleText = state.rows
            .flatMap { [$0.title, $0.route, $0.policy, $0.approval, $0.delegation] }
            .joined(separator: " ")

        XCTAssertFalse(visibleText.contains("Synthetic local summary dry run"))
        XCTAssertFalse(visibleText.contains("Synthetic critical reminder dry run"))
        XCTAssertFalse(visibleText.contains("Synthetic external provider dry run"))
        XCTAssertFalse(visibleText.contains("Synthetic trusted-device metadata dry run"))
    }

    func testDiagnosticViewStateHandlesMissingSnapshotValues() {
        let state = DiagnosticViewState(report: ScenarioRunner().report(), snapshot: nil)

        XCTAssertEqual(state.runtimeStatus, "No live diagnostic snapshot available")
        XCTAssertEqual(state.snapshotSource, "Not available")
        XCTAssertEqual(state.auditEventsDescription, "Not available")
        XCTAssertEqual(state.snapshotFields.first { $0.label == "Generated at" }?.value, "—")
        XCTAssertEqual(state.snapshotFields.first { $0.label == "Risk reason count" }?.value, "—")
        XCTAssertEqual(state.approvalPolicyFields.first { $0.label == "Policy schema" }?.value, "v1")
        XCTAssertEqual(state.approvalPolicyFields.first { $0.label == "Export data approval required" }?.value, "Yes")
        XCTAssertEqual(state.modelSelectionFields.first { $0.label == "Selected model id" }?.value, "model-beta")
        XCTAssertEqual(state.modelSelectionFields.first { $0.label == "Fallback reason" }?.value, "None")
    }
}
