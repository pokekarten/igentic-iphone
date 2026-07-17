import XCTest
@testable import AgentCore

final class PolicyDecisionReasonTests: XCTestCase {
    private let engine = PolicyEngine()

    func testLocalOnlyNonLocalDelegationUsesStableBlockReason() {
        let decision = engine.decide(
            PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: .publicDefault,
                actionRisk: .read,
                requestedDelegationTarget: .trustedMac
            )
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertFalse(decision.requiresApproval)
        XCTAssertEqual(decision.reasonCode, .localOnlyBlocksNonLocalDelegation)
    }

    func testRestrictedExternalDelegationUsesStableBlockReason() {
        let decision = engine.decide(
            PolicyRequest(
                privacyMode: .trustedDevices,
                dataClassification: DataClassification(
                    level: .restrictedSensitiveData,
                    reason: "Synthetic restricted classification."
                ),
                actionRisk: .prepare,
                requestedDelegationTarget: .externalProvider
            )
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertFalse(decision.requiresApproval)
        XCTAssertEqual(
            decision.reasonCode,
            .restrictedDataBlocksAutomaticExternalDelegation
        )
    }

    func testLowRiskLocalPathUsesStableAllowReason() {
        let decision = engine.decide(
            PolicyRequest(
                privacyMode: .trustedDevices,
                dataClassification: .publicDefault,
                actionRisk: .read,
                requestedDelegationTarget: .localDevice
            )
        )

        XCTAssertTrue(decision.isAllowed)
        XCTAssertFalse(decision.requiresApproval)
        XCTAssertEqual(decision.reasonCode, .allowedWithCurrentSafeguards)
    }

    func testSensitiveDataApprovalUsesStableReason() {
        let decision = engine.decide(
            PolicyRequest(
                privacyMode: .trustedDevices,
                dataClassification: DataClassification(
                    level: .highlyPrivateData,
                    reason: "Synthetic highly private classification."
                ),
                actionRisk: .read,
                requestedDelegationTarget: .localDevice
            )
        )

        XCTAssertTrue(decision.isAllowed)
        XCTAssertTrue(decision.requiresApproval)
        XCTAssertEqual(decision.reasonCode, .dataRequiresApproval)
    }

    func testRiskyActionApprovalUsesStableReason() {
        let decision = engine.decide(
            PolicyRequest(
                privacyMode: .trustedDevices,
                dataClassification: .publicDefault,
                actionRisk: .critical,
                requestedDelegationTarget: .localDevice
            )
        )

        XCTAssertTrue(decision.isAllowed)
        XCTAssertTrue(decision.requiresApproval)
        XCTAssertEqual(decision.reasonCode, .actionRequiresApproval)
    }

    func testSensitiveDataAndRiskyActionUseCombinedReason() {
        let decision = engine.decide(
            PolicyRequest(
                privacyMode: .trustedDevices,
                dataClassification: DataClassification(
                    level: .highlyPrivateData,
                    reason: "Synthetic highly private classification."
                ),
                actionRisk: .critical,
                requestedDelegationTarget: .localDevice
            )
        )

        XCTAssertTrue(decision.isAllowed)
        XCTAssertTrue(decision.requiresApproval)
        XCTAssertEqual(decision.reasonCode, .dataAndActionRequireApproval)
    }

    func testManualDecisionInitializerKeepsBackwardCompatibleDefault() {
        let decision = PolicyDecision(
            isAllowed: true,
            requiresApproval: false,
            reason: "Synthetic direct construction."
        )

        XCTAssertEqual(decision.reasonCode, .unspecified)
    }
}
