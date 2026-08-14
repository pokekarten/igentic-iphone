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
                "local-only-local-device",
                "restricted-external-delegation",
                "highly-private-approval",
                "sensitive-data-detection",
            ]
        )
    }

    func testAllCatalogScenariosRunThroughScenarioRunner() {
        let results = ScenarioRunner().runAll(SyntheticScenarioCatalog.all)

        XCTAssertEqual(results.count, SyntheticScenarioCatalog.all.count)
        XCTAssertEqual(results.map(\.scenarioID), SyntheticScenarioCatalog.all.map(\.id))
    }

    func testLocalOnlyLocalDeviceScenarioStaysLocalWithoutApproval() throws {
        let scenario = try XCTUnwrap(
            SyntheticScenarioCatalog.all.first { $0.id == "local-only-local-device" }
        )
        let result = ScenarioRunner().run(scenario)

        XCTAssertEqual(scenario.privacyMode, .localOnly)
        XCTAssertEqual(scenario.task.requestedDelegationTarget, .localDevice)
        XCTAssertEqual(scenario.delegationTarget, .localDevice)
        XCTAssertEqual(
            result.route,
            .localTool(name: "summarizeNote", reason: "Note summarization must stay local unless policy allows delegation.")
        )
        XCTAssertTrue(result.policyDecision.isAllowed)
        XCTAssertFalse(result.policyDecision.requiresApproval)
        XCTAssertEqual(result.policyDecision.reasonCode, .allowedWithCurrentSafeguards)
        XCTAssertEqual(result.approvalStatus, .notRequired)
        XCTAssertEqual(
            result.delegationDecision,
            .allowedMetadataOnly(reason: "Allowed as metadata-only delegation decision.")
        )
    }

    func testRestrictedDataIsBlockedFromExternalDelegation() throws {
        let scenario = try XCTUnwrap(
            SyntheticScenarioCatalog.all.first { $0.id == "restricted-external-delegation" }
        )
        let result = ScenarioRunner().run(scenario)

        // Restricted data should be stopped by policy before any approval flow can
        // continue into a delegated route.
        XCTAssertEqual(scenario.task.dataClassification.level, .restrictedSensitiveData)
        XCTAssertEqual(result.route, .blocked(reason: "Restricted sensitive data cannot be delegated automatically."))
        XCTAssertFalse(result.policyDecision.isAllowed)
        XCTAssertFalse(result.policyDecision.requiresApproval)
        XCTAssertEqual(result.approvalStatus, .notRequired)
        XCTAssertEqual(
            result.delegationDecision,
            .blocked(reason: "Restricted sensitive data cannot be delegated automatically.")
        )
    }

    func testHighlyPrivateDataRequiresApprovalWithoutRiskOrExternalProviderCause() throws {
        let scenario = try XCTUnwrap(
            SyntheticScenarioCatalog.all.first { $0.id == "highly-private-approval" }
        )
        let result = ScenarioRunner().run(scenario)

        XCTAssertEqual(scenario.task.dataClassification.level, .highlyPrivateData)
        XCTAssertEqual(scenario.task.actionRisk, .read)
        XCTAssertEqual(scenario.task.requestedDelegationTarget, .trustedMac)
        XCTAssertEqual(scenario.delegationTarget, .trustedMac)
        XCTAssertTrue(result.policyDecision.isAllowed)
        XCTAssertTrue(result.policyDecision.requiresApproval)
        XCTAssertEqual(result.policyDecision.reasonCode, .dataRequiresApproval)
        XCTAssertEqual(
            result.route,
            .approvalRequired(reason: "Approval is required before routing.")
        )
        XCTAssertEqual(result.approvalStatus, .pending)
        XCTAssertEqual(
            result.delegationDecision,
            .requiresApproval(reason: "Highly private data requires explicit approval.")
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

        XCTAssertEqual(report.entries.count, 8)
        XCTAssertEqual(summary.components(separatedBy: "\n").count, 8)
        XCTAssertTrue(summary.contains("local-only-local-device"))
        XCTAssertTrue(summary.contains("restricted-external-delegation"))
        XCTAssertTrue(summary.contains("highly-private-approval"))
        XCTAssertTrue(summary.contains("sensitive-data-detection"))
        XCTAssertFalse(summary.contains("Synthetic local-only local-device dry run"))
        XCTAssertFalse(summary.contains("Synthetic restricted metadata delegation dry run"))
        XCTAssertFalse(summary.contains("Synthetic highly private approval dry run"))
        XCTAssertFalse(summary.contains("scenario@example.com"))

        // The report intentionally stores normalized kinds, not the full
        // associated-value payload from the live scenario result.
        let localOnlyLocalDevice = report.entries.first { $0.scenarioID == "local-only-local-device" }
        XCTAssertEqual(localOnlyLocalDevice?.route, .localTool)
        XCTAssertEqual(localOnlyLocalDevice?.delegation, .allowedMetadataOnly)

        let restricted = report.entries.first { $0.scenarioID == "restricted-external-delegation" }
        XCTAssertEqual(restricted?.route, .blocked)
        XCTAssertEqual(restricted?.delegation, .blocked)

        let highlyPrivate = report.entries.first { $0.scenarioID == "highly-private-approval" }
        XCTAssertEqual(highlyPrivate?.route, .approvalRequired)
        XCTAssertEqual(highlyPrivate?.delegation, .approvalRequired)

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
