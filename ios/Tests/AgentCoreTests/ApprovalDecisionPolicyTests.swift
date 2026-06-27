import XCTest
@testable import AgentCore

final class ApprovalDecisionPolicyTests: XCTestCase {

    private func sampleRequest() -> ApprovalRequest {
        ApprovalRequest(
            taskSummary: "Sample task",
            dataClassification: .publicDefault,
            actionRisk: .execute,
            reason: "test"
        )
    }

    func testFixedApprovalDecisionPolicyReturnsConfiguredDefaultStatus() {
        let policy = FixedApprovalDecisionPolicy(defaultStatus: .pending)
        XCTAssertEqual(policy.decide(sampleRequest()), .pending)
    }

    func testApprovalManagerDefaultIsStableAndUsesFixedPolicy() {
        let manager = ApprovalManager()
        XCTAssertEqual(manager.requestApproval(sampleRequest()), .pending)
    }

    func testRiskScorePolicyDoesNotCrash() {
        let policy = RiskScoreApprovalPolicy()
        _ = policy.decide(sampleRequest())
    }
}
