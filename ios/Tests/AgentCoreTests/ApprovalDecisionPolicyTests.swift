import XCTest
@testable import AgentCore

final class ApprovalDecisionPolicyTests: XCTestCase {

    func testFixedApprovalDecisionPolicyReturnsConfiguredDefaultStatus() {
        let policy = FixedApprovalDecisionPolicy(defaultStatus: .pending)
        let request = ApprovalRequest()
        let result = policy.decide(request)
        
        XCTAssertEqual(result, .pending)
    }

    func testApprovalManagerDefaultUsesFixedPolicyAndIsStable() {
        let manager = ApprovalManager()
        let request = ApprovalRequest()
        let result = manager.evaluate(request)
        
        XCTAssertEqual(result, .pending)
    }

    func testRiskScorePolicyDoesNotCrash() {
        let policy = RiskScoreApprovalPolicy()
        let request = ApprovalRequest()
        _ = policy.decide(request)
        
        XCTAssertTrue(true)
    }
}
