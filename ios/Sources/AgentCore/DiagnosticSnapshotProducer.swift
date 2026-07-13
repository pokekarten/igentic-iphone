import Foundation

public struct DiagnosticSnapshotProducer: Sendable {
    private let kernel: AgentKernel
    private let approvalManager: ApprovalManager
    private let riskScorer: RiskScorer
    private let delegationBroker: DelegationBroker
    private let sensitiveDataDetector: SensitiveDataDetector

    public init(
        kernel: AgentKernel = AgentKernel(),
        approvalManager: ApprovalManager = ApprovalManager(),
        riskScorer: RiskScorer = RiskScorer(),
        delegationBroker: DelegationBroker = DelegationBroker(),
        sensitiveDataDetector: SensitiveDataDetector = SensitiveDataDetector()
    ) {
        self.kernel = kernel
        self.approvalManager = approvalManager
        self.riskScorer = riskScorer
        self.delegationBroker = delegationBroker
        self.sensitiveDataDetector = sensitiveDataDetector
    }

    public func produceSnapshot(
        for task: TaskRequest,
        privacyMode: PrivacyMode,
        generatedAt: Date = Date()
    ) -> DiagnosticSnapshot {
        let detection = sensitiveDataDetector.detect(in: task.userText)
        let effectiveDataClassification = max(task.dataClassification.level, detection.suggestedDataClassification.level)
            == task.dataClassification.level
            ? task.dataClassification
            : detection.suggestedDataClassification

        let response = kernel.handle(task, privacyMode: privacyMode)
        let auditEvents = kernel.auditEvents()

        let riskScore = riskScorer.score(
            RiskScoringRequest(
                privacyMode: privacyMode,
                dataClassification: effectiveDataClassification,
                actionRisk: task.actionRisk,
                delegationTarget: task.requestedDelegationTarget,
                sensitiveDataFindings: detection.findings
            )
        )

        let delegationDecision = delegationBroker.decide(
            DelegationRequest(
                privacyMode: privacyMode,
                target: task.requestedDelegationTarget,
                dataClassification: effectiveDataClassification,
                actionRisk: task.actionRisk,
                reason: "live diagnostic snapshot"
            )
        )

        let approvalReceipt: ApprovalReceipt
        if response.policyDecision.requiresApproval {
            approvalReceipt = approvalManager.approvalReceipt(
                for: ApprovalRequest(
                    taskSummary: "classification=\(effectiveDataClassification.level), risk=\(task.actionRisk)",
                    dataClassification: effectiveDataClassification,
                    actionRisk: task.actionRisk,
                    reason: response.policyDecision.reason
                )
            )
        } else {
            approvalReceipt = ApprovalReceipt(
                status: response.approvalStatus,
                requestID: UUID().uuidString,
                reasonCode: response.policyDecision.reasonCode.rawValue,
                mayContinueRouting: true
            )
        }

        return DiagnosticSnapshot(
            generatedAt: generatedAt,
            privacyMode: privacyMode,
            policy: PolicyDecisionSummary(response.policyDecision),
            approval: ApprovalStatusSummary(approvalReceipt),
            audit: AuditSummary(events: auditEvents),
            delegation: DelegationDecisionSummary(delegationDecision),
            risk: RiskScoreSummary(riskScore)
        )
    }
}
