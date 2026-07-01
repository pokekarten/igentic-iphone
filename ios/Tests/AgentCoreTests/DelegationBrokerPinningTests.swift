import XCTest
@testable import AgentCore

final class DelegationBrokerPinningTests: XCTestCase {
    func testAgentKernelResponseDoesNotExposeDelegationDecision() {
        let kernel = AgentKernel(
            approvalManager: ApprovalManager(defaultStatus: .approved)
        )
        let task = TaskRequest(
            userText: "Kernel contract pin",
            intent: .summarizeNote,
            actionRisk: .read,
            requestedDelegationTarget: .trustedMac
        )

        let response = kernel.handle(task, privacyMode: .trustedDevices)

        XCTAssertEqual(
            Mirror(reflecting: response).children.compactMap(\.label),
            ["route", "policyDecision", "approvalStatus"]
        )
    }
}
