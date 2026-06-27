import XCTest
@testable import AgentCore

final class ApprovalDecisionPolicyTests: XCTestCase {

    func testFixedApprovalDecisionPolicyReturnsConfiguredDefaultStatus() {
        let policy = FixedApprovalDecisionPolicy(defaultStatus: .pending)
        let request = ApprovalRequest(taskSummary: "t", dataClassification: .publicDefault, actionRisk: .read, reason: "pending")
        let result = policy.decide(request)

        XCTAssertEqual(result, .pending)
    }

    func testApprovalManagerDefaultUsesFixedPolicyAndIsStable() {
        let manager = ApprovalManager()
        let request = ApprovalRequest(taskSummary: "t", dataClassification: .publicDefault, actionRisk: .read, reason: "pending")
        let result = manager.requestApproval(request)

        XCTAssertEqual(result, .pending)
    }

    func testRiskScorePolicyDoesNotCrash() {
        let policy = RiskScoreApprovalPolicy()
        let request = ApprovalRequest(taskSummary: "t", dataClassification: .publicDefault, actionRisk: .read, reason: "pending")
        _ = policy.decide(request)

        XCTAssertTrue(true)
    }
}