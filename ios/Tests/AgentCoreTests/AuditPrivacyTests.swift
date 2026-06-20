import XCTest
@testable import AgentCore

final class AuditPrivacyTests: XCTestCase {
    func testTaskReceivedAuditEventDoesNotRetainRawTaskText() throws {
        let rawTaskText = "Synthetic private task text that must not enter the audit log."
        let classification = DataClassification(
            level: .contextualPrivateData,
            reason: "Synthetic test classification."
        )
        let kernel = AgentKernel()
        let task = TaskRequest(
            userText: rawTaskText,
            intent: .summarizeNote,
            dataClassification: classification,
            actionRisk: .read
        )

        _ = kernel.handle(task, privacyMode: .localOnly)

        let taskReceived = try XCTUnwrap(
            kernel.auditEvents().first { $0.type == .taskReceived }
        )

        XCTAssertEqual(taskReceived.message, "Task received.")
        XCTAssertEqual(taskReceived.dataSensitivity, classification.level)
        XCTAssertFalse(taskReceived.message.contains(rawTaskText))
        XCTAssertFalse(kernel.auditEvents().contains { $0.message.contains(rawTaskText) })
    }
}
