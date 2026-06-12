import XCTest
@testable import AgentCore

final class SmokeTests: XCTestCase {
    func testPolicyAllowsLocalRead() {
        let engine = PolicyEngine()
        let decision = engine.decide(
            PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: .publicDefault,
                actionRisk: .read,
                requestedDelegationTarget: .localDevice
            )
        )

        XCTAssertTrue(decision.isAllowed)
    }
}
