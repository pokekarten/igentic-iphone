import XCTest
@testable import AgentCore

final class SyntheticScenarioCatalogCompletionTests: XCTestCase {
    func testCompleteCatalogKeepsStableReadableOrder() {
        XCTAssertEqual(
            SyntheticScenarioCatalog.baseline.map(\.id),
            ["local-only-summary", "critical-reminder", "external-provider-check", "trusted-device-metadata"]
        )
        XCTAssertEqual(
            SyntheticScenarioCatalog.all.map(\.id),
            [
                "local-only-summary",
                "critical-reminder",
                "external-provider-check",
                "trusted-device-metadata",
                "restricted-external-delegation",
                "sensitive-data-detection",
            ]
        )
    }

    func testAllCatalogScenariosRunThroughScenarioRunner() {
        let results = ScenarioRunner().runAll(SyntheticScenarioCatalog.all)

        XCTAssertEqual(results.count, SyntheticScenarioCatalog.all.count)
        XCTAssertEqual(results.map(\.scenarioID), SyntheticScenarioCatalog.all.map(\.id))
    }

    func testRestrictedDataIsBlockedFromExternalDelegation() throws {
        let scenario = try XCTUnwrap(
            SyntheticScenarioCatalog.all.first { $0.id == "restricted-external-delegation" }
        )
        let result = ScenarioRunner().run(scenario)

        XCTAssertEqual(scenario.task.dataClassification.level, .restrictedSensitiveData)
        XCTAssertEqual(result.route, .blocked(reason: "Restricted sensitive data cannot be delegated automatically."))
        XCTAssertFalse(result.policyDecision.isAllowed)
        XCTAssertTrue(result.policyDecision.requiresApproval)
        XCTAssertEqual(result.approvalStatus, .notRequired)
        XCTAssertEqual(
            result.delegationDecision,
            .blocked(reason: "Restricted sensitive data cannot be delegated automatically.")
        )
    }

    func testSensitiveDataScenarioUsesDetectorClassificationWithoutRetainingRawValue() throws {
        let scenario = try XCTUnwrap(
            SyntheticScenarioCatalog.all.first { $0.id == "sensitive-data-detection" }
        )
        let detection = SensitiveDataDetector().detect(in: scenario.task.userText)
        let result = ScenarioRunner().run(scenario)

        XCTAssertEqual(detection.findings.map(\.category), [.emailAddress])
        XCTAssertEqual(scenario.task.dataClassification, detection.suggestedDataClassification)
        XCTAssertEqual(scenario.task.dataClassification.level, .contextualPrivateData)
        XCTAssertFalse(scenario.task.dataClassification.reason.contains("scenario@example.com"))
        XCTAssertEqual(
            result.route,
            .localTool(name: "summarizeNote", reason: "Note summarization must stay local unless policy allows delegation.")
        )
        XCTAssertEqual(
            result.delegationDecision,
            .allowedMetadataOnly(reason: "Allowed as metadata-only delegation decision.")
        )
    }

    func testCompleteScenarioReportIsDeterministicAndMetadataOnly() {
        let report = ScenarioRunner().report(SyntheticScenarioCatalog.all)
        let summary = report.textSummary

        XCTAssertEqual(report.entries.count, 6)
        XCTAssertEqual(summary.components(separatedBy: "\n").count, 6)
        XCTAssertTrue(summary.contains("restricted-external-delegation"))
        XCTAssertTrue(summary.contains("sensitive-data-detection"))
        XCTAssertFalse(summary.contains("Synthetic restricted metadata delegation dry run"))
        XCTAssertFalse(summary.contains("scenario@example.com"))

        let restricted = report.entries.first { $0.scenarioID == "restricted-external-delegation" }
        XCTAssertEqual(restricted?.route, .blocked)
        XCTAssertEqual(restricted?.delegation, .blocked)

        let sensitive = report.entries.first { $0.scenarioID == "sensitive-data-detection" }
        XCTAssertEqual(sensitive?.route, .localTool)
        XCTAssertEqual(sensitive?.delegation, .allowedMetadataOnly)
    }

    func testDelegationBrokerBlocksRestrictedDataBeforeExternalApprovalPath() {
        let decision = DelegationBroker().decide(
            DelegationRequest(
                privacyMode: .trustedDevices,
                target: .externalProvider,
                dataClassification: DataClassification(
                    level: .restrictedSensitiveData,
                    reason: "Synthetic restricted metadata."
                ),
                actionRisk: .prepare
            )
        )

        XCTAssertEqual(
            decision,
            .blocked(reason: "Restricted sensitive data cannot be delegated automatically.")
        )
        XCTAssertFalse(decision.isAllowed)
        XCTAssertFalse(decision.requiresExplicitApproval)
    }
}
