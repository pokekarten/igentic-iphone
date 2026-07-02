import AgentCore
import XCTest
@testable import iGenticApp

final class DiagnosticViewStateTests: XCTestCase {
    func testDiagnosticViewStateMapsSyntheticScenarioReport() {
        let state = DiagnosticViewState(report: ScenarioRunner().report())

        XCTAssertEqual(state.rows.count, 4)
        XCTAssertEqual(state.privacyNotice, "No private content")
        XCTAssertEqual(state.auditStatus, "Synthetic metadata only")

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
}
