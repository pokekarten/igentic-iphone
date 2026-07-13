import XCTest
@testable import AgentCore

/// Pins that DelegationBroker's approval thresholds match PolicyEngine's
/// for privacyMode: .localOnly with a local target (.none / .localDevice).
/// Regression coverage for the divergence identified in the read-only audit:
/// DelegationBroker previously only required approval for actionRisk ==
/// .critical and never checked dataClassification for local targets.
final class DelegationBrokerPolicyAlignmentTests: XCTestCase {
    private let broker = DelegationBroker()
    private let localTargets: [DelegationTarget] = [.none, .localDevice]

    func testRequiresApprovalForExecuteActionRiskOnLocalTargets() {
        for target in localTargets {
            let decision = broker.decide(
                DelegationRequest(
                    privacyMode: .localOnly,
                    target: target,
                    dataClassification: .publicDefault,
                    actionRisk: .execute
                )
            )
            XCTAssertTrue(decision.requiresExplicitApproval, "target: \(target)")
        }
    }

    func testRequiresApprovalForDestructiveActionRiskOnLocalTargets() {
        for target in localTargets {
            let decision = broker.decide(
                DelegationRequest(
                    privacyMode: .localOnly,
                    target: target,
                    dataClassification: .publicDefault,
                    actionRisk: .destructive
                )
            )
            XCTAssertTrue(decision.requiresExplicitApproval, "target: \(target)")
        }
    }

    func testRequiresApprovalForExternalShareActionRiskOnLocalTargets() {
        for target in localTargets {
            let decision = broker.decide(
                DelegationRequest(
                    privacyMode: .localOnly,
                    target: target,
                    dataClassification: .publicDefault,
                    actionRisk: .externalShare
                )
            )
            XCTAssertTrue(decision.requiresExplicitApproval, "target: \(target)")
        }
    }

    func testRequiresApprovalForHighlyPrivateDataOnLocalTargets() {
        for target in localTargets {
            let decision = broker.decide(
                DelegationRequest(
                    privacyMode: .localOnly,
                    target: target,
                    dataClassification: DataClassification(
                        level: .highlyPrivateData,
                        reason: "test fixture"
                    ),
                    actionRisk: .prepare
                )
            )
            XCTAssertTrue(decision.requiresExplicitApproval, "target: \(target)")
        }
    }

    func testStillAllowsLowRiskPublicDataOnLocalTargets() {
        for target in localTargets {
            let decision = broker.decide(
                DelegationRequest(
                    privacyMode: .localOnly,
                    target: target,
                    dataClassification: .publicDefault,
                    actionRisk: .prepare
                )
            )
            XCTAssertTrue(decision.isAllowed, "target: \(target)")
        }
    }
}
