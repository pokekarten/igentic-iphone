import XCTest
@testable import AgentCore

final class AgentKernelSensitiveDataWiringTests: XCTestCase {
    func testKernelRaisesIBANClassificationBeforeAuditAndRouting() {
        let kernel = AgentKernel(approvalManager: ApprovalManager(defaultStatus: .approved))
        let iban = ["DE", "44", "5001", "0517", "5407", "3249", "31"].joined()
        let task = TaskRequest(
            userText: "Please check IBAN \(iban) for routing.",
            intent: .createReminder,
            dataClassification: .publicDefault,
            actionRisk: .prepare
        )

        let response = kernel.handle(task, privacyMode: .trustedDevices)
        let events = kernel.auditEvents()

        XCTAssertTrue(response.policyDecision.isAllowed)
        XCTAssertTrue(response.policyDecision.requiresApproval)
        XCTAssertEqual(response.approvalStatus, .approved)
        XCTAssertEqual(response.route, .localTool(name: "createReminder", reason: "Reminder creation is a typed local action."))
        XCTAssertEqual(response.policyDecision.riskScore.value, 8)
        XCTAssertTrue(response.policyDecision.riskScore.reasons.contains { $0.contains("Sensitive category contributes 3 point(s): iban.") })

        let taskReceived = events.first { $0.type == .taskReceived }
        let approvalRequired = events.first { $0.type == .approvalRequired }
        let routeSelected = events.first { $0.type == .routeSelected }

        XCTAssertEqual(taskReceived?.dataSensitivity, .restrictedSensitiveData)
        XCTAssertEqual(approvalRequired?.dataSensitivity, .restrictedSensitiveData)
        XCTAssertEqual(routeSelected?.dataSensitivity, .restrictedSensitiveData)
        XCTAssertFalse(events.contains { $0.message.contains(iban) })
    }

    func testKernelKeepsStricterCallerClassificationWhenDetectorIsLower() {
        let kernel = AgentKernel(approvalManager: ApprovalManager(defaultStatus: .approved))
        let email = ["test", "@", "example.com"].joined()
        let task = TaskRequest(
            userText: "Contact \(email) before execution.",
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
        XCTAssertEqual(response.policyDecision.riskScore.value, 7)

        let taskReceived = events.first { $0.type == .taskReceived }
        let approvalRequired = events.first { $0.type == .approvalRequired }
        let routeSelected = events.first { $0.type == .routeSelected }

        XCTAssertEqual(taskReceived?.dataSensitivity, .highlyPrivateData)
        XCTAssertEqual(approvalRequired?.dataSensitivity, .highlyPrivateData)
        XCTAssertEqual(routeSelected?.dataSensitivity, .highlyPrivateData)
        XCTAssertFalse(events.contains { $0.message.contains(email) })
    }

    func testPolicyEngineUsesSensitiveDataFindingsInRiskScore() {
        let detector = SensitiveDataDetector()
        let email = ["test", "@", "example.com"].joined()
        let findings = detector.detect(in: "Contact \(email)").findings
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