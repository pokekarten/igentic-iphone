import Foundation

public struct AgentResponse: Equatable, Sendable {
    public let route: TaskRoute
    public let policyDecision: PolicyDecision
    public let approvalStatus: ApprovalStatus
    /// Full approval receipt for this task, if approval was evaluated.
    /// `nil` only when approval was never required (fast path).
    public let approvalReceipt: ApprovalReceipt?
    /// Metadata-only RuntimeBudget planning result when the kernel reached that
    /// advisory lifecycle stage. This summary has no authorization authority.
    public let runtimeBudgetSummary: RuntimeBudgetSummary?

    public init(
        route: TaskRoute,
        policyDecision: PolicyDecision,
        approvalStatus: ApprovalStatus = .notRequired,
        approvalReceipt: ApprovalReceipt? = nil,
        runtimeBudgetSummary: RuntimeBudgetSummary? = nil
    ) {
        self.route = route
        self.policyDecision = policyDecision
        self.approvalStatus = approvalStatus
        self.approvalReceipt = approvalReceipt
        self.runtimeBudgetSummary = runtimeBudgetSummary
    }
}

public final class AgentKernel: @unchecked Sendable {
    private let policyEngine: PolicyEngine
    private let taskRouter: TaskRouter
    private let auditLog: AuditLog
    private let approvalManager: ApprovalManager
    private let sensitiveDataDetector: any SensitiveDataDetecting
    private let runtimeBudgetAssessor: RuntimeBudgetAssessor?
    private let localModelRuntime: LocalModelRuntime?
    private let toolRegistry: ToolRegistry?

    public init(
        policyEngine: PolicyEngine = PolicyEngine(),
        taskRouter: TaskRouter = TaskRouter(),
        auditLog: AuditLog = AuditLog(),
        approvalManager: ApprovalManager = ApprovalManager(),
        sensitiveDataDetector: any SensitiveDataDetecting = SensitiveDataDetector(),
        runtimeBudgetAssessor: RuntimeBudgetAssessor? = nil,
        localModelRuntime: LocalModelRuntime? = nil,
        toolRegistry: ToolRegistry? = nil
    ) {
        self.policyEngine = policyEngine
        self.taskRouter = taskRouter
        self.auditLog = auditLog
        self.approvalManager = approvalManager
        self.sensitiveDataDetector = sensitiveDataDetector
        self.runtimeBudgetAssessor = runtimeBudgetAssessor
        self.localModelRuntime = localModelRuntime
        self.toolRegistry = toolRegistry
    }

    private func requiredLocalModelCapability(for intent: TaskIntent) -> LocalModelCapability? {
        switch intent {
        case .summarizeNote:
            return .summarization
        case .createReminder, .findFile, .requestApproval, .unknown:
            return nil
        }
    }

    private func runtimeBudgetInput(
        from task: TaskRequest,
        effectiveDataClassification: DataClassification
    ) -> TaskRequest {
        TaskRequest(
            userText: task.userText,
            intent: task.intent,
            dataClassification: effectiveDataClassification,
            actionRisk: task.actionRisk,
            requestedDelegationTarget: task.requestedDelegationTarget
        )
    }

    private func runtimeBudgetMessage(_ budget: RuntimeBudget) -> String {
        [
            "executionClass=\(budget.executionClass.rawValue)",
            "expectedLocality=\(budget.expectedLocality.rawValue)",
            "estimatedMemoryClass=\(budget.estimatedMemoryClass.rawValue)",
            "reasonCount=\(budget.reasons.count)",
        ].joined(separator: ",")
    }

    private func modelSelectionReasonCode(_ reason: ModelSelectionReason) -> String {
        switch reason {
        case .highestWeightedScore:
            return "highestWeightedScore"
        case .lowestLatencyValidModel:
            return "lowestLatencyValidModel"
        case .safeRefusalModel:
            return "safeRefusalModel"
        }
    }

    private func modelSelectionProposalMessage(_ trace: ModelSelectionDecisionTrace) -> String {
        let eligibleCandidateCount = trace.candidates.lazy.filter(\.eligible).count
        let fallbackReason = trace.fallbackReason?.rawValue ?? "none"
        return [
            "selectedModelID=\(trace.selectedModelID)",
            "selectionReason=\(modelSelectionReasonCode(trace.selectionReason))",
            "eligibleCandidateCount=\(eligibleCandidateCount)",
            "fallbackReason=\(fallbackReason)",
        ].joined(separator: ",")
    }

    public func handle(
        _ task: TaskRequest,
        privacyMode: PrivacyMode,
        precomputedDetection: SensitiveDataDetectionResult? = nil,
        modelSelectionProposalInput: ModelSelectionProposalInput? = nil
    ) -> AgentResponse {
        let detection = precomputedDetection ?? sensitiveDataDetector.detect(in: task.userText)
        let effectiveDataClassification = DataClassification.effectiveClassification(
            baseClassification: task.dataClassification,
            detectorResult: detection
        )

        auditLog.record(AuditEvent(type: .taskReceived, message: "Task received.", dataSensitivity: effectiveDataClassification.level))

        if let toolRegistry {
            auditLog.record(
                AuditEvent(
                    type: .toolRegistrySnapshot,
                    message: "toolRegistryToolCount=\(toolRegistry.allTools().count)",
                    dataSensitivity: effectiveDataClassification.level
                )
            )
        }

        let decision = policyEngine.decide(
            PolicyRequest(
                privacyMode: privacyMode,
                dataClassification: effectiveDataClassification,
                actionRisk: task.actionRisk,
                requestedDelegationTarget: task.requestedDelegationTarget,
                sensitiveDataFindings: detection.findings
            )
        )

        auditLog.record(AuditEvent(type: decision.isAllowed ? .policyDecision : .blocked, message: decision.reason, dataSensitivity: effectiveDataClassification.level))

        guard decision.isAllowed else {
            return AgentResponse(route: .blocked(reason: decision.reason), policyDecision: decision)
        }

        var approvalStatus: ApprovalStatus = .notRequired
        var approvalReceipt: ApprovalReceipt?

        if decision.requiresApproval {
            // Single source of truth: ask ApprovalManager for a full receipt
            // (status + requestID + reasonCode) instead of just a bare status.
            // Diagnostics used to reconstruct this receipt independently,
            // which risked drifting out of sync with the live decision.
            let receipt = approvalManager.approvalReceipt(
                for: ApprovalRequest(
                    taskSummary: "classification=\(effectiveDataClassification.level), risk=\(task.actionRisk)",
                    dataClassification: effectiveDataClassification,
                    actionRisk: task.actionRisk,
                    reason: decision.reason
                )
            )
            approvalReceipt = receipt
            approvalStatus = receipt.status

            auditLog.record(AuditEvent(type: .approvalRequired, message: "Approval status: \(approvalStatus.rawValue)", dataSensitivity: effectiveDataClassification.level))

            guard approvalStatus == .approved else {
                return AgentResponse(
                    route: .approvalRequired(reason: "Approval is required before routing."),
                    policyDecision: decision,
                    approvalStatus: approvalStatus,
                    approvalReceipt: approvalReceipt
                )
            }
        }

        var runtimeBudgetSummary: RuntimeBudgetSummary?
        if let runtimeBudgetAssessor {
            let budget = runtimeBudgetAssessor.assess(
                runtimeBudgetInput(
                    from: task,
                    effectiveDataClassification: effectiveDataClassification
                ),
                privacyMode: privacyMode
            )
            runtimeBudgetSummary = RuntimeBudgetSummary(budget)
            auditLog.record(
                AuditEvent(
                    type: .runtimeBudgetSnapshot,
                    message: runtimeBudgetMessage(budget),
                    dataSensitivity: effectiveDataClassification.level
                )
            )
        }

        if let modelSelectionProposalInput {
            let trace = ModelSelectionDecisionTraceGenerator.makeTrace(
                candidates: modelSelectionProposalInput.candidates,
                request: modelSelectionProposalInput.request,
                policy: modelSelectionProposalInput.policy
            )
            auditLog.record(
                AuditEvent(
                    type: .modelSelectionProposal,
                    message: modelSelectionProposalMessage(trace),
                    dataSensitivity: effectiveDataClassification.level
                )
            )
        }

        if let localModelRuntime,
           let requiredCapability = requiredLocalModelCapability(for: task.intent) {
            let modelDecision = localModelRuntime.assess(
                LocalModelRequest(capability: requiredCapability, dataSensitivity: effectiveDataClassification.level)
            )

            if case let .rejected(reason) = modelDecision {
                auditLog.record(
                    AuditEvent(
                        type: .blocked,
                        message: "Local model runtime rejected request: \(reason)",
                        dataSensitivity: effectiveDataClassification.level
                    )
                )
                return AgentResponse(
                    route: .blocked(reason: "Local model runtime unavailable for this capability."),
                    policyDecision: decision,
                    approvalStatus: approvalStatus,
                    approvalReceipt: approvalReceipt,
                    runtimeBudgetSummary: runtimeBudgetSummary
                )
            }
        }

        let route = taskRouter.route(task)

        if let toolRegistry,
           case let .localTool(name, _) = route,
           toolRegistry.tool(named: name) == nil {
            let reason = "Required local tool is unavailable."
            auditLog.record(
                AuditEvent(
                    type: .blocked,
                    message: reason,
                    dataSensitivity: effectiveDataClassification.level
                )
            )
            return AgentResponse(
                route: .blocked(reason: reason),
                policyDecision: decision,
                approvalStatus: approvalStatus,
                approvalReceipt: approvalReceipt,
                runtimeBudgetSummary: runtimeBudgetSummary
            )
        }

        auditLog.record(AuditEvent(type: .routeSelected, message: String(describing: route), dataSensitivity: effectiveDataClassification.level))

        return AgentResponse(
            route: route,
            policyDecision: decision,
            approvalStatus: approvalStatus,
            approvalReceipt: approvalReceipt,
            runtimeBudgetSummary: runtimeBudgetSummary
        )
    }

    public func auditEvents() -> [AuditEvent] {
        auditLog.allEvents()
    }
}
