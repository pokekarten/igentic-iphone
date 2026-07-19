import XCTest
@testable import AgentCore

final class AgentKernelTaskRouterBypassRegressionTests: XCTestCase {
    private func makeKernel(defaultApprovalStatus: ApprovalStatus) -> AgentKernel {
        AgentKernel(
            approvalManager: ApprovalManager(defaultStatus: defaultApprovalStatus)
        )
    }

    private func criticalApprovalTask() -> TaskRequest {
        TaskRequest(
            userText: "Create a reminder for tomorrow.",
            intent: .createReminder,
            dataClassification: .publicDefault,
            actionRisk: .critical,
            requestedDelegationTarget: .localDevice
        )
    }

    private func restrictedNonLocalTask() -> TaskRequest {
        TaskRequest(
            userText: "Summarize the private notes and send them to my Mac.",
            intent: .createReminder,
            dataClassification: DataClassification(
                level: .restrictedSensitiveData,
                reason: "Contains restricted sensitive data."
            ),
            actionRisk: .prepare,
            requestedDelegationTarget: .trustedMac
        )
    }

    func testRestrictedDataAndNonLocalTargetBypassesTaskRouterAndBlocksRoute() {
        let kernel = makeKernel(defaultApprovalStatus: .approved)
        let response = kernel.handle(restrictedNonLocalTask(), privacyMode: .localOnly)

        XCTAssertFalse(response.policyDecision.isAllowed)
        XCTAssertEqual(response.route, .blocked(reason: "Restricted sensitive data cannot be delegated automatically."))

        switch response.route {
        case .localTool:
            XCTFail("AgentKernel.handle() must not return .localTool when policyDecision.isAllowed is false.")
        case .askClarification:
            XCTFail("AgentKernel.handle() must not return .askClarification when policyDecision.isAllowed is false.")
        case .approvalRequired, .blocked:
            break
        }
    }

    func testCriticalActionWithPendingApprovalReturnsApprovalRequiredNotLocalTool() {
        let kernel = makeKernel(defaultApprovalStatus: .pending)
        let response = kernel.handle(criticalApprovalTask(), privacyMode: .localOnly)

        XCTAssertTrue(response.policyDecision.isAllowed)
        XCTAssertTrue(response.policyDecision.requiresApproval)
        XCTAssertEqual(response.approvalStatus, .pending)
        XCTAssertEqual(response.route, .approvalRequired(reason: "Approval is required before routing."))

        switch response.route {
        case .localTool:
            XCTFail("AgentKernel.handle() must not return .localTool before approval is granted.")
        case .askClarification:
            XCTFail("AgentKernel.handle() must not return .askClarification before approval is granted.")
        case .approvalRequired:
            break
        case .blocked:
            XCTFail("This control path should remain policy-allowed and approval-gated, not policy-blocked.")
        }
    }

    func testCriticalActionWithApprovedDefaultStatusCanRouteToLocalTool() {
        let kernel = makeKernel(defaultApprovalStatus: .approved)
        let response = kernel.handle(criticalApprovalTask(), privacyMode: .localOnly)

        XCTAssertTrue(response.policyDecision.isAllowed)
        XCTAssertTrue(response.policyDecision.requiresApproval)
        XCTAssertEqual(response.approvalStatus, .approved)

        switch response.route {
        case let .localTool(name, _):
            XCTAssertEqual(name, "createReminder")
        case .askClarification:
            XCTFail("The control case should route locally, not ask for clarification.")
        case .approvalRequired:
            XCTFail("The control case should not remain approval-gated once approval is approved.")
        case .blocked:
            XCTFail("The control case should not be blocked.")
        }
    }
}
