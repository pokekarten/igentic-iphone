import XCTest
@testable import AgentCore

final class ScenarioReportTests: XCTestCase {
    func testSyntheticScenarioCatalogKeepsStableOrder() {
        XCTAssertEqual(
            SyntheticScenarioCatalog.all.map(\.id),
            ["local-only-summary", "critical-reminder", "external-provider-check", "trusted-device-metadata"]
        )
    }

    func testScenarioReportMapsSafetyOutcomes() {
        let report = ScenarioRunner().report()

        XCTAssertEqual(report.entries.count, 4)

        let localOnly = report.entries.first { $0.scenarioID == "local-only-summary" }
        XCTAssertEqual(localOnly?.route, .localTool)
        XCTAssertEqual(localOnly?.approvalStatus, .notRequired)
        XCTAssertEqual(localOnly?.delegation, .blocked)

        let critical = report.entries.first { $0.scenarioID == "critical-reminder" }
        XCTAssertEqual(critical?.route, .approvalRequired)
        XCTAssertEqual(critical?.policyRequiresApproval, true)
        XCTAssertEqual(critical?.approvalStatus, .pending)
        XCTAssertEqual(critical?.delegation, .approvalRequired)

        let external = report.entries.first { $0.scenarioID == "external-provider-check" }
        XCTAssertEqual(external?.route, .localTool)
        XCTAssertEqual(external?.delegation, .approvalRequired)

        let trustedDevice = report.entries.first { $0.scenarioID == "trusted-device-metadata" }
        XCTAssertEqual(trustedDevice?.route, .localTool)
        XCTAssertEqual(trustedDevice?.delegation, .allowedMetadataOnly)
    }

    func testScenarioReportSummaryIsDeterministicAndMetadataOnly() {
        let summary = ScenarioRunner().report().textSummary

        XCTAssertEqual(summary.components(separatedBy: "\n").count, 4)
        XCTAssertTrue(summary.contains("local-only-summary: route=localTool"))
        XCTAssertTrue(summary.contains("critical-reminder: route=approvalRequired"))
        XCTAssertTrue(summary.contains("external-provider-check"))
        XCTAssertTrue(summary.contains("trusted-device-metadata"))
        XCTAssertFalse(summary.contains("Synthetic local summary dry run"))
        XCTAssertFalse(summary.contains("Synthetic critical reminder dry run"))
    }
}
