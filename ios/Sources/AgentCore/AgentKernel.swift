import Foundation

public struct AgentResponse: Equatable, Sendable {
    public let route: TaskRoute
    public let policyDecision: PolicyDecision
    public let approvalStatus: ApprovalStatus
    /// Full approval receipt for this task, if approval was evaluated.
    /// `nil` only when approval was never required (fast path).
    public let approvalReceipt: ApprovalReceipt?

    public init(
        route: TaskRoute,
        policyDecision: PolicyDecision,
        approvalStatus: ApprovalStatus = .notRequired,
        approvalReceipt: ApprovalReceipt? = nil
    ) {
        self.route = route
        self.policyDecision = policyDecision
        self.approvalStatus = approvalStatus
        self.approvalReceipt = approvalReceipt
    }
}

public final class AgentKernel: @unchecked Sendable {
    private let policyEngine: PolicyEngine
    private let taskRouter: TaskRouter
    private let auditLog: AuditLog
    private let approvalManager: ApprovalManager
    private let sensitiveDataDetector: any SensitiveDataDetecting
    private let localModelRuntime: LocalModelRuntime?

    public init(
        policyEngine: PolicyEngine = PolicyEngine(),
        taskRouter: TaskRouter = TaskRouter(),
        auditLog: AuditLog = AuditLog(),
        approvalManager: ApprovalManager = ApprovalManager(),
        sensitiveDataDetector: any SensitiveDataDetecting = SensitiveDataDetector(),
        localModelRuntime: LocalModelRuntime? = nil
    ) {
        self.policyEngine = policyEngine
        self.taskRouter = taskRouter
        self.auditLog = auditLog
        self.approvalManager = approvalManager
        self.sensitiveDataDetector = sensitiveDataDetector
        self.localModelRuntime = localModelRuntime
    }

    private func requiredLocalModelCapability(for intent: TaskIntent) -> LocalModelCapability? {
        switch intent {
        case .summarizeNote:
            return .summarization
        case .createReminder, .findFile, .requestApproval, .unknown:
            return nil
        }
    }

    public func handle(_ task: TaskRequest, privacyMode: PrivacyMode) -> AgentResponse {
        let detection = sensitiveDataDetector.detect(in: task.userText)
        let effectiveDataClassification = DataClassification.effectiveClassification(
            baseClassification: task.dataClassification,
            detectorResult: detection
        )

        auditLog.record(AuditEvent(type: .taskReceived, message: "Task received.", dataSensitivity: effectiveDataClassification.level))

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
                    approvalReceipt: approvalReceipt
                )
            }
        }

        let route = taskRouter.route(task)
        auditLog.record(AuditEvent(type: .routeSelected, message: String(describing: route), dataSensitivity: effectiveDataClassification.level))

        return AgentResponse(route: route, policyDecision: decision, approvalStatus: approvalStatus, approvalReceipt: approvalReceipt)
    }

    public func auditEvents() -> [AuditEvent] {
        auditLog.allEvents()
    }
}
