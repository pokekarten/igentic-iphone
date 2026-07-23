import AgentCore
import XCTest
@testable import iGenticApp

final class DiagnosticViewStateTests: XCTestCase {
    func testDiagnosticViewStateMapsSyntheticScenarioReport() {
        let state = DiagnosticViewState()

        XCTAssertEqual(state.rows.count, 4)
        XCTAssertEqual(state.privacyNotice, "No private content")
        XCTAssertEqual(state.auditStatus, "Synthetic metadata only")
        XCTAssertEqual(state.runtimeStatus, "Preview snapshot loaded")
        XCTAssertEqual(state.snapshotSource, "Synthetic scenario result (critical-reminder)")
        XCTAssertEqual(state.auditEventsDescription, "Detailed audit events are not available in this shell")

        let generatedAt = state.snapshotFields.first { $0.label == "Generated at" }
        XCTAssertEqual(generatedAt?.value, "2026-07-07T08:00:00Z")

        let privacyMode = state.snapshotFields.first { $0.label == "Privacy mode" }
        XCTAssertEqual(privacyMode?.value, "Trusted Devices")

        let policyAllowed = state.snapshotFields.first { $0.label == "Policy is allowed" }
        XCTAssertEqual(policyAllowed?.value, "Yes")

        let policyRequiresApproval = state.snapshotFields.first { $0.label == "Policy requires approval" }
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
    }
}