import XCTest
@testable import AgentCore

final class AgentKernelSensitiveDataWiringTests: XCTestCase {
    func testKernelRaisesIBANClassificationBeforeAuditAndRouting() {
        let kernel = AgentKernel(approvalManager: ApprovalManager(defaultStatus: .approved))
        let task = TaskRequest(
            userText: "Please check IBAN DE44500105175407324931 for routing.",
            intent: .summarizeNote,
            dataClassification: .publicDefault,
            actionRisk: .prepare
        )

        let response = kernel.handle(task, privacyMode: .trustedDevices)
        let events = kernel.auditEvents()

        XCTAssertTrue(response.policyDecision.isAllowed)
        XCTAssertTrue(response.policyDecision.requiresApproval)
        XCTAssertEqual(response.approvalStatus, .approved)
        XCTAssertEqual(response.route, .localTool(name: "summarizeNote", reason: "Note summarization must stay local unless policy allows delegation."))

        let taskReceived = events.first { $0.type == .taskReceived }
        let approvalRequired = events.first { $0.type == .approvalRequired }
        let routeSelected = events.first { $0.type == .routeSelected }

        XCTAssertEqual(taskReceived?.dataSensitivity, .restrictedSensitiveData)
        XCTAssertEqual(approvalRequired?.dataSensitivity, .restrictedSensitiveData)
        XCTAssertEqual(routeSelected?.dataSensitivity, .restrictedSensitiveData)
        XCTAssertFalse(events.contains { $0.message.contains("DE44500105175407324931") })
    }

    func testKernelKeepsStricterCallerClassificationWhenDetectorIsLower() {
        let kernel = AgentKernel(approvalManager: ApprovalManager(defaultStatus: .approved))
        let task = TaskRequest(
            userText: "Contact test@example.com before execution.",
            intent: .createReminder,
            dataClassification: DataClassification(level: .highlyPrivateData, reason: "Caller-supplied strict classification."),
            actionRisk: .execute
        )

        let response = kernel.handle(task, privacyMode: .trustedDevices)
        let events = kernel.auditEvents()

        XCTAssertTrue(response.policyDecision.isAllowed)
        XCTAssertTrue(response.policyDecision.requiresApproval)
        XCTAssertEqual(response.approvalStatus, .approved)
        XCTAssertEqual(response.route, .localTool(name: "createReminder", reason: "Reminder creation is a typed local action."))

        let taskReceived = events.first { $0.type == .taskReceived }
        let approvalRequired = events.first { $0.type == .approvalRequired }
        let routeSelected = events.first { $0.type == .routeSelected }

        XCTAssertEqual(taskReceived?.dataSensitivity, .highlyPrivateData)
        XCTAssertEqual(approvalRequired?.dataSensitivity, .highlyPrivateData)
        XCTAssertEqual(routeSelected?.dataSensitivity, .highlyPrivateData)
        XCTAssertFalse(events.contains { $0.message.contains("test@example.com") })
    }

    func testPolicyEngineUsesSensitiveDataFindingsInRiskScore() {
        let detector = SensitiveDataDetector()
        let findings = detector.detect(in: "Contact test@example.com").findings
        let engine = PolicyEngine()

        let baseline = engine.decide(
            PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: .publicDefault,
                actionRisk: .read,
                requestedDelegationTarget: .localDevice
            )
        )

        let withFindings = engine.decide(
            PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: .publicDefault,
                actionRisk: .read,
                requestedDelegationTarget: .localDevice,
                sensitiveDataFindings: findings
            )
        )

        XCTAssertGreaterThan(withFindings.riskScore.value, baseline.riskScore.value)
        XCTAssertEqual(withFindings.riskScore.value, baseline.riskScore.value + 1)
        XCTAssertTrue(withFindings.riskScore.reasons.contains { $0.contains("Sensitive category contributes 1 point(s): emailAddress.") })
    }
}
