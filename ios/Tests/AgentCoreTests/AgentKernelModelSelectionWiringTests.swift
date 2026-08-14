import XCTest
@testable import AgentCore

final class AgentKernelModelSelectionWiringTests: XCTestCase {
    func testNilProposalInputPreservesRouteAndEmitsNoProposal() {
        let kernel = AgentKernel()

        let response = kernel.handle(makeReminderTask(), privacyMode: .localOnly)
        let events = kernel.auditEvents()

        XCTAssertEqual(response.route, expectedReminderRoute)
        XCTAssertFalse(events.contains { $0.type == .modelSelectionProposal })
        XCTAssertEqual(events.filter { $0.type == .routeSelected }.count, 1)
    }

    func testExplicitEligibleInputEmitsProposalWithoutChangingRoute() {
        let kernel = AgentKernel()
        let input = ModelSelectionProposalInput(
            request: ModelSelectionRequest(
                latencyBudget: .low,
                contextSize: 1024,
                toolUsageRequired: false
            ),
            candidates: [eligibleCandidate(modelID: "model-alpha")]
        )

        let response = kernel.handle(
            makeReminderTask(),
            privacyMode: .localOnly,
            modelSelectionProposalInput: input
        )
        let events = kernel.auditEvents()
        let proposalEvents = events.filter { $0.type == .modelSelectionProposal }

        XCTAssertEqual(response.route, expectedReminderRoute)
        XCTAssertEqual(proposalEvents.count, 1)
        XCTAssertEqual(
            proposalEvents.first?.message,
            "selectedModelID=model-alpha,selectionReason=highestWeightedScore,eligibleCandidateCount=1,fallbackReason=none"
        )
        XCTAssertEqual(proposalEvents.first?.dataSensitivity, .publicData)
        XCTAssertEqual(events.filter { $0.type == .routeSelected }.count, 1)
    }

    func testNoEligibleCandidatesProducesSafeRefusalProposalWithoutBlockingRoute() {
        let kernel = AgentKernel()
        let input = ModelSelectionProposalInput(
            request: ModelSelectionRequest(
                latencyBudget: .low,
                contextSize: 4096,
                toolUsageRequired: true
            ),
            candidates: [
                ModelCandidate(
                    modelID: "model-too-small",
                    evaluationScore: 0.99,
                    latencyScore: 0.99,
                    capabilityMatch: 0.99,
                    latencyMS: 10,
                    contextSize: 4096,
                    maxContextTokens: 1024,
                    latencyBudgetClass: .high,
                    toolUsageSupported: false
                )
            ]
        )

        let response = kernel.handle(
            makeReminderTask(),
            privacyMode: .localOnly,
            modelSelectionProposalInput: input
        )
        let events = kernel.auditEvents()
        let proposalEvent = events.first { $0.type == .modelSelectionProposal }

        XCTAssertEqual(response.route, expectedReminderRoute)
        XCTAssertEqual(
            proposalEvent?.message,
            "selectedModelID=model-safe-refusal,selectionReason=safeRefusalModel,eligibleCandidateCount=0,fallbackReason=noEligibleCandidates"
        )
        XCTAssertFalse(events.contains { $0.type == .blocked })
        XCTAssertEqual(events.filter { $0.type == .routeSelected }.count, 1)
    }

    func testPolicyDenialPrecedesProposalGeneration() {
        let kernel = AgentKernel()
        let task = TaskRequest(
            userText: "Synthetic non-local reminder request.",
            intent: .createReminder,
            dataClassification: .publicDefault,
            actionRisk: .prepare,
            requestedDelegationTarget: .trustedMac
        )

        let response = kernel.handle(
            task,
            privacyMode: .localOnly,
            modelSelectionProposalInput: eligibleInput
        )
        let events = kernel.auditEvents()

        XCTAssertEqual(response.route, .blocked(reason: "Local Only blocks non-local delegation."))
        XCTAssertFalse(events.contains { $0.type == .modelSelectionProposal })
        XCTAssertFalse(events.contains { $0.type == .routeSelected })
    }

    func testPendingApprovalPrecedesProposalGeneration() {
        let kernel = AgentKernel(approvalManager: ApprovalManager(defaultStatus: .pending))
        let task = TaskRequest(
            userText: "Synthetic critical reminder request.",
            intent: .createReminder,
            dataClassification: .publicDefault,
            actionRisk: .critical
        )

        let response = kernel.handle(
            task,
            privacyMode: .trustedDevices,
            modelSelectionProposalInput: eligibleInput
        )
        let events = kernel.auditEvents()

        XCTAssertEqual(
            response.route,
            .approvalRequired(reason: "Approval is required before routing.")
        )
        XCTAssertEqual(response.approvalStatus, .pending)
        XCTAssertFalse(events.contains { $0.type == .modelSelectionProposal })
        XCTAssertFalse(events.contains { $0.type == .routeSelected })
    }

    func testRuntimeBudgetSnapshotPrecedesModelSelectionProposal() throws {
        let kernel = AgentKernel(runtimeBudgetAssessor: RuntimeBudgetAssessor())

        _ = kernel.handle(
            makeReminderTask(),
            privacyMode: .localOnly,
            modelSelectionProposalInput: eligibleInput
        )

        let events = kernel.auditEvents()
        let budgetIndex = try XCTUnwrap(events.firstIndex { $0.type == .runtimeBudgetSnapshot })
        let proposalIndex = try XCTUnwrap(events.firstIndex { $0.type == .modelSelectionProposal })

        XCTAssertLessThan(budgetIndex, proposalIndex)
    }

    func testProposalAuditMetadataExcludesTaskTextAndScoreComponents() {
        let privateTaskText = "Synthetic private selection sentinel must not appear in proposal audit."
        let input = ModelSelectionProposalInput(
            request: ModelSelectionRequest(
                latencyBudget: .low,
                contextSize: 1024,
                toolUsageRequired: false
            ),
            candidates: [
                ModelCandidate(
                    modelID: "model-alpha",
                    evaluationScore: 0.123456,
                    latencyScore: 0.654321,
                    capabilityMatch: 0.345678,
                    latencyMS: 42,
                    contextSize: 1024,
                    maxContextTokens: 4096,
                    latencyBudgetClass: .high,
                    toolUsageSupported: true
                )
            ]
        )
        let kernel = AgentKernel()

        _ = kernel.handle(
            TaskRequest(
                userText: privateTaskText,
                intent: .createReminder,
                dataClassification: .publicDefault,
                actionRisk: .prepare
            ),
            privacyMode: .localOnly,
            modelSelectionProposalInput: input
        )

        let proposalEvent = kernel.auditEvents().first { $0.type == .modelSelectionProposal }

        XCTAssertEqual(
            proposalEvent?.message,
            "selectedModelID=model-alpha,selectionReason=highestWeightedScore,eligibleCandidateCount=1,fallbackReason=none"
        )
        XCTAssertFalse(proposalEvent?.message.contains(privateTaskText) ?? true)
        XCTAssertFalse(proposalEvent?.message.contains("0.123456") ?? true)
        XCTAssertFalse(proposalEvent?.message.contains("0.654321") ?? true)
        XCTAssertFalse(proposalEvent?.message.contains("0.345678") ?? true)
    }

    private var eligibleInput: ModelSelectionProposalInput {
        ModelSelectionProposalInput(
            request: ModelSelectionRequest(
                latencyBudget: .low,
                contextSize: 1024,
                toolUsageRequired: false
            ),
            candidates: [eligibleCandidate(modelID: "model-alpha")]
        )
    }

    private var expectedReminderRoute: TaskRoute {
        .localTool(
            name: "createReminder",
            reason: "Reminder creation is a typed local action."
        )
    }

    private func makeReminderTask() -> TaskRequest {
        TaskRequest(
            userText: "Synthetic reminder task.",
            intent: .createReminder,
            dataClassification: .publicDefault,
            actionRisk: .prepare
        )
    }

    private func eligibleCandidate(modelID: String) -> ModelCandidate {
        ModelCandidate(
            modelID: modelID,
            evaluationScore: 0.90,
            latencyScore: 0.80,
            capabilityMatch: 0.85,
            latencyMS: 50,
            contextSize: 1024,
            maxContextTokens: 4096,
            latencyBudgetClass: .high,
            toolUsageSupported: true
        )
    }
}
