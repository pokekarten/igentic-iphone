import XCTest
@testable import AgentCore

final class AgentKernelMemoryStoreWiringTests: XCTestCase {
    func testHandleRecordsOnlyAggregateMemoryCounts() throws {
        let sessionKey = "private-session-key-sentinel"
        let sessionValue = "private-session-value-sentinel"
        let taskKey = "private-task-key-sentinel"
        let taskValue = "private-task-value-sentinel"
        let store = MemoryStore()
        _ = try store.save(
            key: sessionKey,
            value: sessionValue,
            scope: .session,
            dataSensitivity: .lowRiskAppData
        )
        _ = try store.save(
            key: taskKey,
            value: taskValue,
            scope: .task,
            dataSensitivity: .contextualPrivateData
        )
        let kernel = AgentKernel(memoryStore: store)

        let response = kernel.handle(
            makeReminderTask(),
            privacyMode: .localOnly
        )
        let events = kernel.auditEvents()
        let memoryEvents = events.filter { $0.type == .memoryStoreSnapshot }

        XCTAssertEqual(
            response.route,
            .localTool(
                name: "createReminder",
                reason: "Reminder creation is a typed local action."
            )
        )
        XCTAssertEqual(memoryEvents.count, 1)
        XCTAssertEqual(
            memoryEvents.first?.message,
            "memoryStoreSessionCount=1,memoryStoreTaskCount=1"
        )
        XCTAssertEqual(memoryEvents.first?.dataSensitivity, .publicData)

        for sentinel in [sessionKey, sessionValue, taskKey, taskValue] {
            XCTAssertFalse(events.contains { $0.message.contains(sentinel) })
        }
    }

    func testMissingMemoryStoreEmitsNoMemorySnapshot() {
        let kernel = AgentKernel()

        let response = kernel.handle(
            makeReminderTask(),
            privacyMode: .localOnly
        )
        let events = kernel.auditEvents()

        XCTAssertEqual(
            response.route,
            .localTool(
                name: "createReminder",
                reason: "Reminder creation is a typed local action."
            )
        )
        XCTAssertFalse(events.contains { $0.type == .memoryStoreSnapshot })
    }

    func testMemoryPresenceDoesNotChangeKernelResponse() throws {
        let store = MemoryStore()
        _ = try store.save(
            key: "preference",
            value: "synthetic-value",
            scope: .session,
            dataSensitivity: .lowRiskAppData
        )
        let task = makeReminderTask()
        let kernelWithoutMemory = AgentKernel()
        let kernelWithMemory = AgentKernel(memoryStore: store)

        let responseWithoutMemory = kernelWithoutMemory.handle(
            task,
            privacyMode: .localOnly
        )
        let responseWithMemory = kernelWithMemory.handle(
            task,
            privacyMode: .localOnly
        )

        XCTAssertEqual(responseWithMemory, responseWithoutMemory)
        XCTAssertEqual(responseWithMemory.approvalStatus, .notRequired)
        XCTAssertNil(responseWithMemory.approvalReceipt)
    }

    func testPendingApprovalStillStopsBeforeAdvisoryAndRoutingStages() throws {
        let store = MemoryStore()
        _ = try store.save(
            key: "memory-cannot-authorize",
            value: "synthetic-value",
            scope: .task,
            dataSensitivity: .highlyPrivateData
        )
        let kernel = AgentKernel(
            approvalManager: ApprovalManager(defaultStatus: .pending),
            runtimeBudgetAssessor: RuntimeBudgetAssessor(),
            memoryStore: store
        )
        let task = TaskRequest(
            userText: "Synthetic critical reminder request.",
            intent: .createReminder,
            dataClassification: .publicDefault,
            actionRisk: .critical
        )

        let response = kernel.handle(task, privacyMode: .trustedDevices)
        let events = kernel.auditEvents()

        XCTAssertEqual(
            response.route,
            .approvalRequired(reason: "Approval is required before routing.")
        )
        XCTAssertEqual(response.approvalStatus, .pending)
        XCTAssertEqual(events.filter { $0.type == .memoryStoreSnapshot }.count, 1)
        XCTAssertEqual(
            events.first(where: { $0.type == .memoryStoreSnapshot })?.message,
            "memoryStoreSessionCount=0,memoryStoreTaskCount=1"
        )
        XCTAssertFalse(events.contains { $0.type == .runtimeBudgetSnapshot })
        XCTAssertFalse(events.contains { $0.type == .modelSelectionProposal })
        XCTAssertFalse(events.contains { $0.type == .routeSelected })
    }

    private func makeReminderTask() -> TaskRequest {
        TaskRequest(
            userText: "Please create a synthetic reminder for the project.",
            intent: .createReminder,
            dataClassification: .publicDefault,
            actionRisk: .prepare
        )
    }
}
