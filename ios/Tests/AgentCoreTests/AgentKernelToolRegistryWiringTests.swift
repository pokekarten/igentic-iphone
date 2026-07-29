import XCTest
@testable import AgentCore

final class AgentKernelToolRegistryWiringTests: XCTestCase {
    func testHandleRecordsRegistryCountWithoutChangingRouting() {
        let registry = ToolRegistry(
            tools: [
                ToolDefinition(
                    name: "createReminder",
                    requiredDataLevel: .contextualPrivateData,
                    actionRisk: .prepare,
                    description: "Prepare a synthetic reminder tool."
                ),
                ToolDefinition(
                    name: "summarizeNote",
                    requiredDataLevel: .publicData,
                    actionRisk: .read,
                    description: "Summarize a synthetic note."
                ),
            ]
        )
        let kernel = AgentKernel(toolRegistry: registry)

        let response = kernel.handle(
            TaskRequest(
                userText: "Please create a reminder for the project.",
                intent: .createReminder,
                dataClassification: .publicDefault,
                actionRisk: .prepare
            ),
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
        XCTAssertEqual(events.first?.type, .taskReceived)
        XCTAssertEqual(
            events.first(where: { $0.type == .toolRegistrySnapshot })?.message,
            "toolRegistryToolCount=2"
        )
        XCTAssertEqual(events.filter { $0.type == .toolRegistrySnapshot }.count, 1)
        XCTAssertFalse(events.contains { $0.message.contains("createReminder") && $0.type != .routeSelected })
        XCTAssertFalse(events.contains { $0.message.contains("summarizeNote") })
    }

    func testHandleDoesNotRecordRegistrySnapshotWhenRegistryIsMissing() {
        let kernel = AgentKernel()

        let response = kernel.handle(
            TaskRequest(
                userText: "Please create a reminder for the project.",
                intent: .createReminder,
                dataClassification: .publicDefault,
                actionRisk: .prepare
            ),
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
        XCTAssertFalse(events.contains { $0.type == .toolRegistrySnapshot })
        XCTAssertEqual(events.filter { $0.type == .taskReceived }.count, 1)
        XCTAssertEqual(events.filter { $0.type == .routeSelected }.count, 1)
    }
}