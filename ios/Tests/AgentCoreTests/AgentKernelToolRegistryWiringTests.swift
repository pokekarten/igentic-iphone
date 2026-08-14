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

    func testMissingRequiredToolFailsClosedWithoutRouteSelectedOrMetadataLeak() {
        let privateTaskText = "Synthetic private task sentinel must not appear in audit output."
        let unrelatedDescription = "Synthetic unrelated tool description must not appear in audit output."
        let registry = ToolRegistry(
            tools: [
                ToolDefinition(
                    name: "summarizeNote",
                    requiredDataLevel: .publicData,
                    actionRisk: .read,
                    description: unrelatedDescription
                )
            ]
        )
        let kernel = AgentKernel(toolRegistry: registry)

        let response = kernel.handle(
            TaskRequest(
                userText: privateTaskText,
                intent: .createReminder,
                dataClassification: .publicDefault,
                actionRisk: .prepare
            ),
            privacyMode: .localOnly
        )

        let events = kernel.auditEvents()

        XCTAssertEqual(
            response.route,
            .blocked(reason: "Required local tool is unavailable.")
        )
        XCTAssertEqual(events.filter { $0.type == .blocked }.count, 1)
        XCTAssertEqual(
            events.first(where: { $0.type == .blocked })?.message,
            "Required local tool is unavailable."
        )
        XCTAssertEqual(
            events.first(where: { $0.type == .blocked })?.dataSensitivity,
            .publicData
        )
        XCTAssertFalse(events.contains { $0.type == .routeSelected })
        XCTAssertFalse(events.contains { $0.message.contains(privateTaskText) })
        XCTAssertFalse(events.contains { $0.message.contains(unrelatedDescription) })
        XCTAssertFalse(events.contains { $0.message.contains("summarizeNote") })
        XCTAssertFalse(events.contains { $0.message.contains("createReminder") })
    }

    func testUnknownIntentClarifiesWithoutRegistryFailure() {
        let kernel = AgentKernel(toolRegistry: ToolRegistry())

        let response = kernel.handle(
            TaskRequest(
                userText: "Synthetic unclear task.",
                intent: .unknown,
                dataClassification: .publicDefault,
                actionRisk: .read
            ),
            privacyMode: .localOnly
        )

        let events = kernel.auditEvents()

        XCTAssertEqual(
            response.route,
            .askClarification(reason: "Intent is unclear.")
        )
        XCTAssertFalse(
            events.contains {
                $0.type == .blocked && $0.message == "Required local tool is unavailable."
            }
        )
        XCTAssertEqual(events.filter { $0.type == .routeSelected }.count, 1)
    }

    func testPolicyDenialPrecedesRegistryAvailability() {
        let kernel = AgentKernel(toolRegistry: ToolRegistry())

        let response = kernel.handle(
            TaskRequest(
                userText: "Synthetic non-local reminder request.",
                intent: .createReminder,
                dataClassification: .publicDefault,
                actionRisk: .prepare,
                requestedDelegationTarget: .trustedMac
            ),
            privacyMode: .localOnly
        )

        let events = kernel.auditEvents()

        XCTAssertEqual(
            response.route,
            .blocked(reason: "Local Only blocks non-local delegation.")
        )
        XCTAssertFalse(
            events.contains {
                $0.message == "Required local tool is unavailable."
            }
        )
        XCTAssertFalse(events.contains { $0.type == .routeSelected })
    }

    func testPendingApprovalPrecedesRegistryAvailability() {
        let kernel = AgentKernel(
            approvalManager: ApprovalManager(defaultStatus: .pending),
            toolRegistry: ToolRegistry()
        )

        let response = kernel.handle(
            TaskRequest(
                userText: "Synthetic critical reminder request.",
                intent: .createReminder,
                dataClassification: .publicDefault,
                actionRisk: .critical
            ),
            privacyMode: .trustedDevices
        )

        let events = kernel.auditEvents()

        XCTAssertEqual(
            response.route,
            .approvalRequired(reason: "Approval is required before routing.")
        )
        XCTAssertEqual(response.approvalStatus, .pending)
        XCTAssertFalse(
            events.contains {
                $0.message == "Required local tool is unavailable."
            }
        )
        XCTAssertFalse(events.contains { $0.type == .routeSelected })
    }
}
