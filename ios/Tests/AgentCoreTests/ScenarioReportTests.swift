import XCTest
@testable import AgentCore

final class ScenarioReportTests: XCTestCase {
    func testSyntheticScenarioCatalogKeepsStableOrder() {
        XCTAssertEqual(
            SyntheticScenarioCatalog.baseline.map(\.id),
            ["local-only-summary", "critical-reminder", "external-provider-check", "trusted-device-metadata"]
        )
    }

    func testScenarioReportMapsSafetyOutcomes() {
        let report = ScenarioRunner().report()

        XCTAssertEqual(report.entries.count, 4)

        let localOnly = report.entries.first { $0.scenarioID == "local-only-summary" }
        // Local-only privacy mode blocks non-local delegation before routing.
        XCTAssertEqual(localOnly?.route, .blocked)
        XCTAssertEqual(localOnly?.approvalStatus, .notRequired)
        XCTAssertEqual(localOnly?.delegation, .blocked)

        let critical = report.entries.first { $0.scenarioID == "critical-reminder" }
        // Critical actions are allowed only with approval and therefore stop at
        // the approval-required route until the receipt is resolved.
        XCTAssertEqual(critical?.route, .approvalRequired)
        XCTAssertEqual(critical?.policyRequiresApproval, true)
        XCTAssertEqual(critical?.approvalStatus, .pending)
        XCTAssertEqual(critical?.delegation, .approvalRequired)

        let external = report.entries.first { $0.scenarioID == "external-provider-check" }
        XCTAssertEqual(external?.route, .approvalRequired)
        XCTAssertEqual(external?.policyRequiresApproval, true)
        XCTAssertEqual(external?.delegation, .approvalRequired)

        let trustedDevice = report.entries.first { $0.scenarioID == "trusted-device-metadata" }
        XCTAssertEqual(trustedDevice?.route, .localTool)
        XCTAssertEqual(trustedDevice?.delegation, .allowedMetadataOnly)
    }

    func testKernelSeesPropagatedDelegationTargetForSyntheticScenarios() {
        let scenario = SyntheticScenarioCatalog.baseline.first { $0.id == "external-provider-check" }
        XCTAssertNotNil(scenario)
        guard let scenario else { return }

        XCTAssertEqual(scenario.task.requestedDelegationTarget, scenario.delegationTarget)

        let kernel = AgentKernel()
        let propagatedDecision = kernel.handle(scenario.task, privacyMode: scenario.privacyMode).policyDecision

        let localDeviceTask = TaskRequest(
            userText: scenario.task.userText,
            intent: scenario.task.intent,
            dataClassification: scenario.task.dataClassification,
            actionRisk: scenario.task.actionRisk,
            requestedDelegationTarget: .localDevice
        )
        let localDeviceDecision = kernel.handle(localDeviceTask, privacyMode: scenario.privacyMode).policyDecision

        XCTAssertNotEqual(propagatedDecision, localDeviceDecision)
        XCTAssertEqual(propagatedDecision.reasonCode, .externalProviderRequiresApproval)
        XCTAssertEqual(propagatedDecision.requiresApproval, true)
        XCTAssertEqual(localDeviceDecision.reasonCode, .allowedWithCurrentSafeguards)
        XCTAssertEqual(localDeviceDecision.requiresApproval, false)
    }

    func testScenarioReportSummaryIsDeterministicAndMetadataOnly() {
        let summary = ScenarioRunner().report().textSummary

        XCTAssertEqual(summary.components(separatedBy: "\n").count, 4)
        XCTAssertTrue(summary.contains("local-only-summary: route=blocked"))
        XCTAssertTrue(summary.contains("critical-reminder: route=approvalRequired"))
        XCTAssertTrue(summary.contains("external-provider-check: route=approvalRequired"))
        XCTAssertTrue(summary.contains("trusted-device-metadata: route=localTool"))
        XCTAssertFalse(summary.contains("Synthetic local summary dry run"))
        XCTAssertFalse(summary.contains("Synthetic critical reminder dry run"))
    }
}
