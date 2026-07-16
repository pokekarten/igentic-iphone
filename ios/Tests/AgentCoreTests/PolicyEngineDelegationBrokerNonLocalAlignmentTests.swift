import XCTest
@testable import AgentCore

final class PolicyEngineDelegationBrokerNonLocalAlignmentTests: XCTestCase {
    private let policyEngine = PolicyEngine()
    private let broker = DelegationBroker()
    private let nonLocalTargets: [DelegationTarget] = [.trustedMac, .homeServer, .privateCloudCompute, .externalProvider]

    func testRestrictedDataOnNonLocalTargetsAgreesOnApprovalFlag() {
        for target in nonLocalTargets {
            let restricted = DataClassification(level: .restrictedSensitiveData, reason: "test fixture")
            let policyDecision = policyEngine.decide(PolicyRequest(privacyMode: .trustedDevices, dataClassification: restricted, actionRisk: .prepare, requestedDelegationTarget: target))
            let delegationDecision = broker.decide(DelegationRequest(privacyMode: .trustedDevices, target: target, dataClassification: restricted, actionRisk: .prepare))
            XCTAssertFalse(policyDecision.isAllowed, "target: \(target)")
            XCTAssertFalse(policyDecision.requiresApproval, "target: \(target)")
            XCTAssertFalse(delegationDecision.isAllowed, "target: \(target)")
            XCTAssertFalse(delegationDecision.requiresExplicitApproval, "target: \(target)")
        }
    }
}