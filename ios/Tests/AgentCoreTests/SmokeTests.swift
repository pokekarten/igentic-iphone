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

    /// Pins the contract that `DelegationBroker` matches `PolicyEngine` for
    /// `privacyMode: .localOnly` when the target stays local.
    func testDelegationBrokerAllowsLocalOnlyForLocalTargets() {
        let broker = DelegationBroker()

        for target in [DelegationTarget.none, .localDevice] {
            let request = DelegationRequest(
                privacyMode: .localOnly,
                target: target,
                dataClassification: .publicDefault,
                actionRisk: .prepare
            )

            let decision = broker.decide(request)

            XCTAssertEqual(
                decision,
                .allowedMetadataOnly(reason: "Allowed as metadata-only delegation decision.")
            )
            XCTAssertTrue(decision.isAllowed)
            XCTAssertFalse(decision.requiresExplicitApproval)
        }
    }

    /// Pins the remaining Local Only guard: non-local targets still fail.
    func testDelegationBrokerBlocksLocalOnlyForNonLocalTargets() {
        let broker = DelegationBroker()
        let request = DelegationRequest(
            privacyMode: .localOnly,
            target: .externalProvider,
            dataClassification: .publicDefault,
            actionRisk: .prepare
        )

        let decision = broker.decide(request)

        XCTAssertEqual(
            decision,
            .blocked(reason: "Local Only blocks non-local delegation.")
        )
        XCTAssertFalse(decision.isAllowed)
        XCTAssertFalse(decision.requiresExplicitApproval)
    }
}
