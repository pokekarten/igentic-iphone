import XCTest
@testable import AgentCore

final class AgentKernelLocalModelRuntimeWiringTests: XCTestCase {
    func testSummarizeNoteRoutesNormallyWhenLocalModelRuntimeIsNil() {
        let kernel = AgentKernel()

        let response = kernel.handle(makeTask(intent: .summarizeNote), privacyMode: .localOnly)

        XCTAssertEqual(
            response.route,
            .localTool(
                name: "summarizeNote",
                reason: "Note summarization must stay local unless policy allows delegation."
            )
        )
        XCTAssertEqual(kernel.auditEvents().last?.type, .routeSelected)
    }

    func testSummarizeNoteIsBlockedWhenLocalModelRuntimeRejects() {
        let kernel = AgentKernel(
            localModelRuntime: FakeLocalModelRuntime(
                availability: .unavailable(.unsupportedPlatform),
                supportedCapabilities: []
            )
        )

        let response = kernel.handle(makeTask(intent: .summarizeNote), privacyMode: .localOnly)
        let events = kernel.auditEvents()

        XCTAssertEqual(
            response.route,
            .blocked(reason: "Local model runtime unavailable for this capability.")
        )
        XCTAssertEqual(events.filter { $0.type == .blocked }.count, 1)
        XCTAssertTrue(
            events.contains {
                $0.type == .blocked && $0.message.hasPrefix("Local model runtime rejected request:")
            }
        )
        XCTAssertFalse(events.contains { $0.type == .routeSelected })
    }

    func testSummarizeNoteRoutesToLocalToolWhenLocalModelRuntimeAccepts() {
        let kernel = AgentKernel(
            localModelRuntime: FakeLocalModelRuntime(
                availability: .available,
                supportedCapabilities: [.summarization]
            )
        )

        let response = kernel.handle(makeTask(intent: .summarizeNote), privacyMode: .localOnly)

        XCTAssertEqual(
            response.route,
            .localTool(
                name: "summarizeNote",
                reason: "Note summarization must stay local unless policy allows delegation."
            )
        )
        XCTAssertEqual(kernel.auditEvents().last?.type, .routeSelected)
    }

    func testCreateReminderIsUnaffectedRegardlessOfRuntimeAvailability() {
        let kernel = AgentKernel(
            localModelRuntime: FakeLocalModelRuntime(
                availability: .unavailable(.unsupportedPlatform),
                supportedCapabilities: []
            )
        )

        let response = kernel.handle(makeTask(intent: .createReminder), privacyMode: .localOnly)
        let events = kernel.auditEvents()

        XCTAssertEqual(
            response.route,
            .localTool(
                name: "createReminder",
                reason: "Reminder creation is a typed local action."
            )
        )
        XCTAssertEqual(events.last?.type, .routeSelected)
        XCTAssertFalse(events.contains { $0.type == .blocked })
    }

    private func makeTask(intent: TaskIntent) -> TaskRequest {
        TaskRequest(
            userText: "Test task for \(intent.rawValue)",
            intent: intent,
            dataClassification: .publicDefault,
            actionRisk: .prepare,
            requestedDelegationTarget: .localDevice
        )
    }
}

private struct FakeLocalModelRuntime: LocalModelRuntime {
    let descriptor: LocalModelRuntimeDescriptor
    let availability: LocalModelRuntimeAvailability

    init(
        availability: LocalModelRuntimeAvailability = .available,
        supportedCapabilities: Set<LocalModelCapability>,
        maximumDataSensitivity: DataSensitivityLevel = .restrictedSensitiveData
    ) {
        self.availability = availability
        self.descriptor = LocalModelRuntimeDescriptor(
            identifier: "synthetic-local-runtime",
            modelFamily: "synthetic-qwen-class",
            executionKind: .local,
            supportedCapabilities: supportedCapabilities,
            maximumDataSensitivity: maximumDataSensitivity,
            contextBudgetClass: .standard,
            memoryBudgetClass: .moderate
        )
    }
}
