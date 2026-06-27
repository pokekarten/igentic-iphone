import XCTest
@testable import AgentCore

final class ApprovalDecisionPolicyTests: XCTestCase {

    private func sampleRequest(reason: String = "test") -> ApprovalRequest {
        ApprovalRequest(
            taskSummary: "Sample task",
            dataClassification: .publicDefault,
            actionRisk: .execute,
            reason: reason
        )
    }

    func testFixedApprovalDecisionPolicyReturnsConfiguredDefaultStatus() {
        let policy = FixedApprovalDecisionPolicy(defaultStatus: .pending)
        let result = policy.decide(sampleRequest())

        XCTAssertEqual(result, .pending)
    }

    func testApprovalManagerDefaultIsStableAndUsesFixedPolicy() {
        let manager = ApprovalManager()
        let result = manager.requestApproval(sampleRequest())

        XCTAssertEqual(result, .pending)
    }

    func testRiskScorePolicyDoesNotCrash() {
        let policy = RiskScoreApprovalPolicy()
        _ = policy.decide(sampleRequest())
    }
}