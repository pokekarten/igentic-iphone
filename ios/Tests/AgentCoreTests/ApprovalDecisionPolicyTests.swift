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

    func testApprovalRequestDefaultsRemainBackwardsCompatible() {
        let request = sampleRequest()

        XCTAssertEqual(request.privacyMode, .localOnly)
        XCTAssertEqual(request.requestedDelegationTarget, .none)
        XCTAssertTrue(request.sensitiveDataFindings.isEmpty)
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

    func testRiskScorePolicyKeepsBaselineRequestApproved() {
        let policy = RiskScoreApprovalPolicy()
        XCTAssertEqual(policy.decide(sampleRequest()), .approved)
    }

    func testRiskScorePolicyTreatsExternalProviderDelegationAsPending() {
        let policy = RiskScoreApprovalPolicy()
        let request = ApprovalRequest(
            taskSummary: "Share with external provider",
            dataClassification: .publicDefault,
            actionRisk: .read,
            reason: "test",
            privacyMode: .localOnly,
            requestedDelegationTarget: .externalProvider
        )

        XCTAssertEqual(policy.decide(request), .pending)
    }

    func testRiskScorePolicyTreatsIBANFindingAsPending() {
        let policy = RiskScoreApprovalPolicy()
        let request = ApprovalRequest(
            taskSummary: "Process payment details",
            dataClassification: DataClassification(level: .highlyPrivateData, reason: "Sensitive task"),
            actionRisk: .read,
            reason: "test",
            privacyMode: .localOnly,
            requestedDelegationTarget: .none,
            sensitiveDataFindings: [SensitiveDataFinding(category: .iban, reason: "IBAN-like pattern detected.")]
        )

        XCTAssertEqual(policy.decide(request), .pending)
    }
}
