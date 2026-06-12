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

    public init(
        policyEngine: PolicyEngine = PolicyEngine(),
        taskRouter: TaskRouter = TaskRouter(),
        auditLog: AuditLog = AuditLog(),
        approvalManager: ApprovalManager = ApprovalManager()
    ) {
        self.policyEngine = policyEngine
        self.taskRouter = taskRouter
        self.auditLog = auditLog
        self.approvalManager = approvalManager
    }

    public func handle(_ task: TaskRequest, privacyMode: PrivacyMode) -> AgentResponse {
        auditLog.record(AuditEvent(type: .taskReceived, message: task.userText, dataSensitivity: task.dataClassification.level))

        let decision = policyEngine.decide(
            PolicyRequest(
                privacyMode: privacyMode,
                dataClassification: task.dataClassification,
                actionRisk: task.actionRisk,
                requestedDelegationTarget: .localDevice
            )
        )

        auditLog.record(AuditEvent(type: decision.isAllowed ? .policyDecision : .blocked, message: decision.reason, dataSensitivity: task.dataClassification.level))

        guard decision.isAllowed else {
            return AgentResponse(route: .blocked(reason: decision.reason), policyDecision: decision)
        }

        var approvalStatus: ApprovalStatus = .notRequired

        if decision.requiresApproval {
            approvalStatus = approvalManager.requestApproval(
                ApprovalRequest(
                    taskSummary: task.userText,
                    dataClassification: task.dataClassification,
                    actionRisk: task.actionRisk,
                    reason: decision.reason
                )
            )

            auditLog.record(AuditEvent(type: .approvalRequired, message: "Approval status: \(approvalStatus.rawValue)", dataSensitivity: task.dataClassification.level))

            guard approvalStatus == .approved else {
                return AgentResponse(
                    route: .approvalRequired(reason: "Approval is required before routing."),
                    policyDecision: decision,
                    approvalStatus: approvalStatus
                )
            }
        }

        let route = taskRouter.route(task, privacyMode: privacyMode)
        auditLog.record(AuditEvent(type: .routeSelected, message: String(describing: route), dataSensitivity: task.dataClassification.level))

        return AgentResponse(route: route, policyDecision: decision, approvalStatus: approvalStatus)
    }

    public func auditEvents() -> [AuditEvent] {
        auditLog.allEvents()
    }
}
