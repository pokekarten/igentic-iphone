import XCTest
@testable import AgentCore

final class SmokeTests: XCTestCase {
    func testCatalogScenariosRunEndToEndInStableOrder() {
        let results = ScenarioRunner().runAll()

        XCTAssertEqual(
            results.map(\.scenarioID),
            ["local-only-summary", "critical-reminder", "external-provider-check", "trusted-device-metadata"]
        )
    }

    /// Pins that `RiskScore` stays informational metadata and never adds an
    /// approval requirement by itself.
    ///
    /// Referenced by name in `PolicyEngine.swift` (see the doc comment on
    /// `PolicyDecision.riskScore`). If this test's name or assertions change,
    /// update that comment too — it exists specifically to catch a future
    /// change that lets `riskScore` influence `isAllowed`/`requiresApproval`.
    func testPolicyRiskScoreDoesNotAddApprovalByItself() {
        let request = PolicyRequest(
            privacyMode: .trustedDevices,
            dataClassification: DataClassification(
                level: .contextualPrivateData,
                reason: "Synthetic contextual classification for risk-score pinning."
            ),
            actionRisk: .prepare,
            requestedDelegationTarget: .privateCloudCompute,
            sensitiveDataFindings: [
                SensitiveDataFinding(category: .iban, reason: SensitiveDataCategory.iban.detectionReason),
                SensitiveDataFinding(category: .emailAddress, reason: SensitiveDataCategory.emailAddress.detectionReason)
            ]
        )

        let decision = PolicyEngine().decide(request)

        XCTAssertTrue(decision.riskScore.requiresExplicitApproval, "Test setup should produce a high risk score.")
        XCTAssertTrue(decision.isAllowed)
        XCTAssertFalse(
            decision.requiresApproval,
            "riskScore must stay informational; only dataClassification/actionRisk/delegationTarget may require approval."
        )
        XCTAssertEqual(decision.reasonCode, .allowedWithCurrentSafeguards)
    }
}
