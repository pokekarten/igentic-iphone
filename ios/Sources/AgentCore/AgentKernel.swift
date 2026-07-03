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
        let effectiveClassification = task.dataClassification.raised(byDetected: detection.suggestedDataClassification)
        let effectiveTask = TaskRequest(
            userText: task.userText,
            intent: task.intent,
            dataClassification: effectiveClassification,
            actionRisk: task.actionRisk
        )

        auditLog.record(AuditEvent(type: .taskReceived, message: "Task received.", dataSensitivity: effectiveClassification.level))

        let decision = policyEngine.decide(
            PolicyRequest(
                privacyMode: privacyMode,
                dataClassification: effectiveClassification,
                actionRisk: task.actionRisk,
                requestedDelegationTarget: .localDevice,
                sensitiveDataFindings: detection.findings
            )
        )

        auditLog.record(AuditEvent(type: decision.isAllowed ? .policyDecision : .blocked, message: decision.reason, dataSensitivity: effectiveClassification.level))

        guard decision.isAllowed else {
            return AgentResponse(route: .blocked(reason: decision.reason), policyDecision: decision)
        }

        var approvalStatus: ApprovalStatus = .notRequired

        if decision.requiresApproval {
            approvalStatus = approvalManager.requestApproval(
                ApprovalRequest(
                    taskSummary: task.userText,
                    dataClassification: effectiveClassification,
                    actionRisk: task.actionRisk,
                    reason: decision.reason
                )
            )

            auditLog.record(AuditEvent(type: .approvalRequired, message: "Approval status: \(approvalStatus.rawValue)", dataSensitivity: effectiveClassification.level))

            guard approvalStatus == .approved else {
                return AgentResponse(
                    route: .approvalRequired(reason: "Approval is required before routing."),
                    policyDecision: decision,
                    approvalStatus: approvalStatus
                )
            }
        }

        let route = taskRouter.route(effectiveTask, privacyMode: privacyMode)
        auditLog.record(AuditEvent(type: .routeSelected, message: String(describing: route), dataSensitivity: effectiveClassification.level))

        return AgentResponse(route: route, policyDecision: decision, approvalStatus: approvalStatus)
    }

    public func auditEvents() -> [AuditEvent] {
        auditLog.allEvents()
    }
}
