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

        let response = kernel.handle(task, privacyMode: .localOnly)

        XCTAssertEqual(response.approvalStatus, .notRequired)
        if case let .localTool(name, reason) = response.route {
            XCTAssertEqual(name, "summarizeNote")
            XCTAssertFalse(reason.contains(rawTaskText))
        } else {
            XCTFail("Expected local summarizeNote route.")
        }

        let events = kernel.auditEvents()
        let taskReceived = try XCTUnwrap(
            events.first { $0.type == .taskReceived }
        )

        XCTAssertEqual(events.filter { $0.type == .taskReceived }.count, 1)
        XCTAssertEqual(taskReceived.message, "Task received.")
        XCTAssertEqual(taskReceived.dataSensitivity, classification.level)
        XCTAssertFalse(taskReceived.message.contains(rawTaskText))
        XCTAssertFalse(events.contains { $0.message.contains(rawTaskText) })
    }

    func testSensitiveTextUpgradesClassificationAndTriggersApproval() throws {
        let rawTaskText = "Please review IBAN DE44 5001 0517 5407 3249 31 before routing."
        let kernel = AgentKernel()
        let task = TaskRequest(
            userText: rawTaskText,
            intent: .requestApproval,
            dataClassification: .publicDefault,
            actionRisk: .read
        )

        let response = kernel.handle(task, privacyMode: .localOnly)
        let events = kernel.auditEvents()
        let taskReceived = try XCTUnwrap(events.first { $0.type == .taskReceived })
        let policyDecision = try XCTUnwrap(events.first { $0.type == .policyDecision })
        let approvalEvent = try XCTUnwrap(events.first { $0.type == .approvalRequired })

        XCTAssertEqual(response.policyDecision.requiresApproval, true)
        XCTAssertEqual(response.approvalStatus, .pending)
        if case let .approvalRequired(reason) = response.route {
            XCTAssertEqual(reason, "Approval is required before routing.")
        } else {
            XCTFail("Expected approvalRequired route.")
        }
        XCTAssertEqual(taskReceived.dataSensitivity, .restrictedSensitiveData)
        XCTAssertEqual(policyDecision.dataSensitivity, .restrictedSensitiveData)
        XCTAssertEqual(approvalEvent.dataSensitivity, .restrictedSensitiveData)
        XCTAssertFalse(events.contains { $0.message.contains(rawTaskText) })
        XCTAssertFalse(events.contains { $0.message.contains("DE44 5001 0517 5407 3249 31") })
        XCTAssertFalse(events.contains { $0.message.contains("Please review") })
    }

    func testDetectorDoesNotDowngradeHigherCallerClassification() throws {
        let rawTaskText = "Reach me at max.mustermann@example.com for the next step."
        let higherClassification = DataClassification(
            level: .restrictedSensitiveData,
            reason: "Caller supplied a higher classification."
        )
        let kernel = AgentKernel()
        let task = TaskRequest(
            userText: rawTaskText,
            intent: .requestApproval,
            dataClassification: higherClassification,
            actionRisk: .read
        )

        let response = kernel.handle(task, privacyMode: .localOnly)
        let events = kernel.auditEvents()

        XCTAssertEqual(response.approvalStatus, .pending)
        XCTAssertEqual(response.policyDecision.requiresApproval, true)
        XCTAssertEqual(events.filter { $0.type == .taskReceived }.first?.dataSensitivity, .restrictedSensitiveData)
        XCTAssertEqual(events.filter { $0.type == .policyDecision }.first?.dataSensitivity, .restrictedSensitiveData)
        XCTAssertEqual(events.filter { $0.type == .approvalRequired }.first?.dataSensitivity, .restrictedSensitiveData)
        XCTAssertFalse(events.contains { $0.message.contains(rawTaskText) })
        XCTAssertFalse(events.contains { $0.message.contains("max.mustermann@example.com") })
    }

    func testLongDigitRunDoesNotTriggerPhoneDetection() {
        let detector = SensitiveDataDetector()
        let longDigitRun = String(repeating: "1234567890", count: 50)
        let result = detector.detect(in: "prefix \(longDigitRun) suffix")

        XCTAssertFalse(result.hasFindings)
        XCTAssertTrue(result.findings.isEmpty)
    }
}
