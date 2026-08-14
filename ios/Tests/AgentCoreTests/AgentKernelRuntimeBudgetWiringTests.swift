import XCTest
@testable import AgentCore

final class AgentKernelRuntimeBudgetWiringTests: XCTestCase {
    func testNilAssessorPreservesRouteAndEmitsNoBudgetSnapshot() {
        let kernel = AgentKernel()

        let response = kernel.handle(
            makeReminderTask(userText: "Synthetic reminder task."),
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
        XCTAssertFalse(events.contains { $0.type == .runtimeBudgetSnapshot })
        XCTAssertEqual(events.filter { $0.type == .routeSelected }.count, 1)
    }

    func testAssessorEmitsAdvisorySnapshotWithoutChangingRoute() {
        let kernel = AgentKernel(runtimeBudgetAssessor: RuntimeBudgetAssessor())

        let response = kernel.handle(
            makeReminderTask(userText: "Synthetic reminder task."),
            privacyMode: .localOnly
        )
        let events = kernel.auditEvents()
        let budgetEvents = events.filter { $0.type == .runtimeBudgetSnapshot }

        XCTAssertEqual(
            response.route,
            .localTool(
                name: "createReminder",
                reason: "Reminder creation is a typed local action."
            )
        )
        XCTAssertEqual(budgetEvents.count, 1)
        XCTAssertEqual(
            budgetEvents.first?.message,
            "executionClass=small,expectedLocality=local-only,estimatedMemoryClass=moderate,reasonCount=1"
        )
        XCTAssertEqual(budgetEvents.first?.dataSensitivity, .publicData)
        XCTAssertEqual(events.filter { $0.type == .routeSelected }.count, 1)
    }

    func testBudgetUsesEffectiveClassificationFromSensitiveDetection() {
        let iban = ["DE", "44", "5001", "0517", "5407", "3249", "31"].joined()
        let kernel = AgentKernel(
            approvalManager: ApprovalManager(defaultStatus: .approved),
            runtimeBudgetAssessor: RuntimeBudgetAssessor()
        )

        let response = kernel.handle(
            makeReminderTask(userText: "Please check IBAN \(iban) for this synthetic reminder."),
            privacyMode: .trustedDevices
        )
        let events = kernel.auditEvents()
        let budgetEvent = events.first { $0.type == .runtimeBudgetSnapshot }

        XCTAssertTrue(response.policyDecision.isAllowed)
        XCTAssertTrue(response.policyDecision.requiresApproval)
        XCTAssertEqual(response.approvalStatus, .approved)
        XCTAssertEqual(
            response.route,
            .localTool(
                name: "createReminder",
                reason: "Reminder creation is a typed local action."
            )
        )
        XCTAssertEqual(budgetEvent?.dataSensitivity, .restrictedSensitiveData)
        XCTAssertEqual(
            budgetEvent?.message,
            "executionClass=small,expectedLocality=local-only,estimatedMemoryClass=high,reasonCount=2"
        )
        XCTAssertFalse(events.contains { $0.message.contains(iban) })
    }

    func testPolicyDenialPrecedesBudgetSnapshot() {
        let kernel = AgentKernel(runtimeBudgetAssessor: RuntimeBudgetAssessor())
        let task = TaskRequest(
            userText: "Synthetic non-local reminder request.",
            intent: .createReminder,
            dataClassification: .publicDefault,
            actionRisk: .prepare,
            requestedDelegationTarget: .trustedMac
        )

        let response = kernel.handle(task, privacyMode: .localOnly)
        let events = kernel.auditEvents()

        XCTAssertEqual(
            response.route,
            .blocked(reason: "Local Only blocks non-local delegation.")
        )
        XCTAssertFalse(events.contains { $0.type == .runtimeBudgetSnapshot })
        XCTAssertFalse(events.contains { $0.type == .routeSelected })
    }

    func testPendingApprovalPrecedesBudgetSnapshot() {
        let kernel = AgentKernel(
            approvalManager: ApprovalManager(defaultStatus: .pending),
            runtimeBudgetAssessor: RuntimeBudgetAssessor()
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
        XCTAssertFalse(events.contains { $0.type == .runtimeBudgetSnapshot })
        XCTAssertFalse(events.contains { $0.type == .routeSelected })
    }

    func testBudgetSnapshotDoesNotExposeTaskTextOrAssessorReasons() {
        let privateTaskText = "Synthetic private budget sentinel must not appear in audit output."
        let assessorReason = "Intent family: bounded synthesis -> small."
        let kernel = AgentKernel(runtimeBudgetAssessor: RuntimeBudgetAssessor())

        _ = kernel.handle(
            makeReminderTask(userText: privateTaskText),
            privacyMode: .localOnly
        )

        let budgetEvent = kernel.auditEvents().first { $0.type == .runtimeBudgetSnapshot }

        XCTAssertEqual(
            budgetEvent?.message,
            "executionClass=small,expectedLocality=local-only,estimatedMemoryClass=moderate,reasonCount=1"
        )
        XCTAssertFalse(budgetEvent?.message.contains(privateTaskText) ?? true)
        XCTAssertFalse(budgetEvent?.message.contains(assessorReason) ?? true)
    }

    private func makeReminderTask(userText: String) -> TaskRequest {
        TaskRequest(
            userText: userText,
            intent: .createReminder,
            dataClassification: .publicDefault,
            actionRisk: .prepare
        )
    }
}
