import Foundation

public struct AgentResponse: Equatable, Sendable {
    public let route: TaskRoute
    public let policyDecision: PolicyDecision
    public let approvalStatus: ApprovalStatus

    public init(route: TaskRoute, policyDecision: PolicyDecision, approvalStatus: ApprovalStatus = .notRequired) {
        self.route = route
        self.policyDecision = policyDecision
        self.approvalStatus = approvalStatus
    }
}

public final class AgentKernel: @unchecked Sendable {
    private let policyEngine: PolicyEngine
    private let taskRouter: TaskRouter
    private let auditLog: AuditLog
    private let approvalManager: ApprovalManager
    private let sensitiveDataDetector: SensitiveDataDetector

    public init(
        policyEngine: PolicyEngine = PolicyEngine(),
        taskRouter: TaskRouter = TaskRouter(),
        auditLog: AuditLog = AuditLog(),
        approvalManager: ApprovalManager = ApprovalManager(),
        sensitiveDataDetector: SensitiveDataDetector = SensitiveDataDetector()
    ) {
        self.policyEngine = policyEngine
        self.taskRouter = taskRouter
        self.auditLog = auditLog
        self.approvalManager = approvalManager
        self.sensitiveDataDetector = sensitiveDataDetector
    }

    public func handle(_ task: TaskRequest, privacyMode: PrivacyMode) -> AgentResponse {
        let detection = sensitiveDataDetector.detect(in: task.userText)
        let effectiveDataClassification = task.dataClassification.level >= detection.suggestedDataClassification.level
            ? task.dataClassification
            : detection.suggestedDataClassification

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

        if decision.requiresApproval {
            approvalStatus = approvalManager.requestApproval(
                ApprovalRequest(
                    taskSummary: task.userText,
                    dataClassification: effectiveDataClassification,
                    actionRisk: task.actionRisk,
                    reason: decision.reason
                )
            )

            auditLog.record(AuditEvent(type: .approvalRequired, message: "Approval status: \(approvalStatus.rawValue)", dataSensitivity: effectiveDataClassification.level))

            guard approvalStatus == .approved else {
                return AgentResponse(
                    route: .approvalRequired(reason: "Approval is required before routing."),
                    policyDecision: decision,
                    approvalStatus: approvalStatus
                )
            }
        }

        let route = taskRouter.route(task)
        auditLog.record(AuditEvent(type: .routeSelected, message: String(describing: route), dataSensitivity: effectiveDataClassification.level))

        return AgentResponse(route: route, policyDecision: decision, approvalStatus: approvalStatus)
    }

    public func auditEvents() -> [AuditEvent] {
        auditLog.allEvents()
    }
}