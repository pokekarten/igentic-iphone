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

    func testAuditLogRecordsEvents() {
        let log = AuditLog()
        let event = AuditEvent(
            type: .taskReceived,
            message: "test event",
            dataSensitivity: .publicData
        )

        log.record(event)

        XCTAssertEqual(log.allEvents(), [event])
    }

    func testAuditLogReturnsSnapshot() {
        let log = AuditLog()
        log.record(
            AuditEvent(
                type: .taskReceived,
                message: "first",
                dataSensitivity: .publicData
            )
        )

        let snapshot = log.allEvents()
        log.record(
            AuditEvent(
                type: .routeSelected,
                message: "second",
                dataSensitivity: .publicData
            )
        )

        XCTAssertEqual(snapshot.count, 1)
        XCTAssertEqual(log.allEvents().count, 2)
    }

    func testAgentKernelStopsWhenApprovalIsPending() {
        let kernel = AgentKernel(
            approvalManager: ApprovalManager(defaultStatus: .pending)
        )
        let task = TaskRequest(
            userText: "Prepare reviewed task",
            intent: .createReminder,
            actionRisk: .execute
        )

        let response = kernel.handle(task, privacyMode: .localOnly)

        XCTAssertEqual(response.approvalStatus, .pending)
        XCTAssertEqual(response.route, .approvalRequired(reason: "Approval is required before routing."))
    }

    func testAgentKernelRoutesWhenApprovalIsApproved() {
        let kernel = AgentKernel(
            approvalManager: ApprovalManager(defaultStatus: .approved)
        )
        let task = TaskRequest(
            userText: "Prepare reviewed task",
            intent: .createReminder,
            actionRisk: .execute
        )

        let response = kernel.handle(task, privacyMode: .localOnly)

        XCTAssertEqual(response.approvalStatus, .approved)
        XCTAssertEqual(response.route, .localTool(name: "createReminder", reason: "Reminder creation is a typed local action."))
    }
}
