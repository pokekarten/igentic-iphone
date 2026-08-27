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

    func testApprovalDecisionPolicyDefaultIsIntentional() {
        let manager = ApprovalManager(defaultStatus: .rejected)
        XCTAssertEqual(manager.requestApproval(sampleRequest()), .rejected)
    }

    func testApprovalManagerDefaultIsStableAndUsesFixedPolicy() {
        let manager = ApprovalManager()
        XCTAssertEqual(manager.requestApproval(sampleRequest()), .pending)
    }

    func testRiskScorePolicyCannotAutoApproveAdvisoryScore() {
        let policy = RiskScoreApprovalPolicy()
        XCTAssertEqual(policy.decide(sampleRequest()), .pending)
    }

    func testRiskScorePolicyCannotSatisfyExplicitExternalProviderApproval() {
        let kernel = AgentKernel(
            approvalManager: ApprovalManager(policy: RiskScoreApprovalPolicy())
        )
        let response = kernel.handle(
            TaskRequest(
                userText: "Synthetic external provider approval boundary.",
                intent: .summarizeNote,
                dataClassification: .publicDefault,
                actionRisk: .prepare,
                requestedDelegationTarget: .externalProvider
            ),
            privacyMode: .trustedDevices
        )

        XCTAssertTrue(response.policyDecision.isAllowed)
        XCTAssertTrue(response.policyDecision.requiresApproval)
        XCTAssertEqual(response.policyDecision.reasonCode, .externalProviderRequiresApproval)
        XCTAssertEqual(response.approvalStatus, .pending)
        XCTAssertEqual(
            response.route,
            .approvalRequired(reason: "Approval is required before routing.")
        )
    }
}
