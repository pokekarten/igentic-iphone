import XCTest
@testable import AgentCore

final class AgentKernelPhase2LifecycleTests: XCTestCase {
    func testIntegratedLifecyclePreservesAuthorityAndAuditOrdering() {
        let privateTaskText = "Synthetic highly private lifecycle sentinel must not appear in audit output."
        let privateToolDescription = "Synthetic private tool description must not appear in audit output."
        let kernel = makeKernel(
            approvalStatus: .approved,
            toolDescription: privateToolDescription
        )

        let response = kernel.handle(
            makeTask(userText: privateTaskText),
            privacyMode: .trustedDevices,
            modelSelectionProposalInput: makeModelSelectionInput()
        )
        let events = kernel.auditEvents()

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

        XCTAssertEqual(
            events.map(\.type),
            [
                .taskReceived,
                .toolRegistrySnapshot,
                .policyDecision,
                .approvalRequired,
                .runtimeBudgetSnapshot,
                .modelSelectionProposal,
                .routeSelected,
            ]
        )

        for type in [
            AuditEventType.taskReceived,
            .toolRegistrySnapshot,
            .policyDecision,
            .approvalRequired,
            .runtimeBudgetSnapshot,
            .modelSelectionProposal,
            .routeSelected,
        ] {
            XCTAssertEqual(events.filter { $0.type == type }.count, 1)
        }

        XCTAssertTrue(events.allSatisfy { $0.dataSensitivity == .highlyPrivateData })
        XCTAssertFalse(events.contains { $0.type == .blocked })
        XCTAssertEqual(
            events.first(where: { $0.type == .modelSelectionProposal })?.message,
            "selectedModelID=model-phase2,selectionReason=highestWeightedScore,eligibleCandidateCount=1,fallbackReason=none"
        )
        XCTAssertEqual(
            events.first(where: { $0.type == .toolRegistrySnapshot })?.message,
            "toolRegistryToolCount=1"
        )
        XCTAssertFalse(events.contains { $0.message.contains(privateTaskText) })
        XCTAssertFalse(events.contains { $0.message.contains(privateToolDescription) })
    }

    func testPendingApprovalStopsEveryDownstreamAdvisoryAndRoutingStage() {
        let kernel = makeKernel(
            approvalStatus: .pending,
            toolDescription: "Synthetic reminder tool."
        )

        let response = kernel.handle(
            makeTask(userText: "Synthetic pending approval lifecycle task."),
            privacyMode: .trustedDevices,
            modelSelectionProposalInput: makeModelSelectionInput()
        )
        let events = kernel.auditEvents()

        XCTAssertEqual(
            response.route,
            .approvalRequired(reason: "Approval is required before routing.")
        )
        XCTAssertEqual(response.approvalStatus, .pending)
        XCTAssertEqual(
            events.map(\.type),
            [
                .taskReceived,
                .toolRegistrySnapshot,
                .policyDecision,
                .approvalRequired,
            ]
        )
        XCTAssertFalse(events.contains { $0.type == .runtimeBudgetSnapshot })
        XCTAssertFalse(events.contains { $0.type == .modelSelectionProposal })
        XCTAssertFalse(events.contains { $0.type == .routeSelected })
        XCTAssertTrue(events.allSatisfy { $0.dataSensitivity == .highlyPrivateData })
    }

    private func makeKernel(
        approvalStatus: ApprovalStatus,
        toolDescription: String
    ) -> AgentKernel {
        let registry = ToolRegistry(
            tools: [
                ToolDefinition(
                    name: "createReminder",
                    requiredDataLevel: .highlyPrivateData,
                    actionRisk: .execute,
                    description: toolDescription
                )
            ]
        )

        return AgentKernel(
            approvalManager: ApprovalManager(defaultStatus: approvalStatus),
            runtimeBudgetAssessor: RuntimeBudgetAssessor(),
            toolRegistry: registry
        )
    }

    private func makeTask(userText: String) -> TaskRequest {
        TaskRequest(
            userText: userText,
            intent: .createReminder,
            dataClassification: DataClassification(
                level: .highlyPrivateData,
                reason: "Synthetic Phase 2 lifecycle classification."
            ),
            actionRisk: .execute
        )
    }

    private func makeModelSelectionInput() -> ModelSelectionProposalInput {
        ModelSelectionProposalInput(
            request: ModelSelectionRequest(
                latencyBudget: .low,
                contextSize: 1024,
                toolUsageRequired: true
            ),
            candidates: [
                ModelCandidate(
                    modelID: "model-phase2",
                    evaluationScore: 0.90,
                    latencyScore: 0.85,
                    capabilityMatch: 0.95,
                    latencyMS: 40,
                    contextSize: 1024,
                    maxContextTokens: 4096,
                    latencyBudgetClass: .high,
                    toolUsageSupported: true
                )
            ]
        )
    }
}
