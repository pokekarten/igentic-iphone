import Foundation

public struct AgentResponse: Equatable, Sendable {
    public let route: TaskRoute
    public let policyDecision: PolicyDecision

    public init(route: TaskRoute, policyDecision: PolicyDecision) {
        self.route = route
        self.policyDecision = policyDecision
    }
}

public final class AgentKernel: @unchecked Sendable {
    private let policyEngine: PolicyEngine
    private let taskRouter: TaskRouter
    private let auditLog: AuditLog

    public init(
        policyEngine: PolicyEngine = PolicyEngine(),
        taskRouter: TaskRouter = TaskRouter(),
        auditLog: AuditLog = AuditLog()
    ) {
        self.policyEngine = policyEngine
        self.taskRouter = taskRouter
        self.auditLog = auditLog
    }

    public func handle(_ task: TaskRequest, privacyMode: PrivacyMode) -> AgentResponse {
        auditLog.record(
            AuditEvent(
                type: .taskReceived,
                message: task.userText,
                dataSensitivity: task.dataClassification.level
            )
        )

        let decision = policyEngine.decide(
            PolicyRequest(
                privacyMode: privacyMode,
                dataClassification: task.dataClassification,
                actionRisk: task.actionRisk,
                requestedDelegationTarget: .localDevice
            )
        )

        auditLog.record(
            AuditEvent(
                type: decision.isAllowed ? .policyDecision : .blocked,
                message: decision.reason,
                dataSensitivity: task.dataClassification.level
            )
        )

        guard decision.isAllowed else {
            return AgentResponse(route: .blocked(reason: decision.reason), policyDecision: decision)
        }

        let route = taskRouter.route(task, privacyMode: privacyMode)
        auditLog.record(
            AuditEvent(
                type: .routeSelected,
                message: String(describing: route),
                dataSensitivity: task.dataClassification.level
            )
        )

        return AgentResponse(route: route, policyDecision: decision)
    }

    public func auditEvents() -> [AuditEvent] {
        auditLog.allEvents()
    }
}
