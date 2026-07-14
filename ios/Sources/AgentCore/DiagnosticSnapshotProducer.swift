import Foundation

public struct DiagnosticSnapshotProducer: Sendable {
    private let approvalManager: ApprovalManager
    private let riskScorer: RiskScorer
    private let delegationBroker: DelegationBroker
    private let sensitiveDataDetector: SensitiveDataDetector

    public init(
        approvalManager: ApprovalManager = ApprovalManager(),
        riskScorer: RiskScorer = RiskScorer(),
        delegationBroker: DelegationBroker = DelegationBroker(),
        sensitiveDataDetector: SensitiveDataDetector = SensitiveDataDetector()
    ) {
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

        let kernel = AgentKernel(approvalManager: approvalManager)
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

        let approvalStatus = response.approvalReceipt.map(ApprovalStatusSummary.init)
            ?? ApprovalStatusSummary(
                status: response.approvalStatus,
                mayContinueRouting: response.approvalStatus == .approved || response.approvalStatus == .notRequired
            )

        return DiagnosticSnapshot(
            generatedAt: generatedAt,
            privacyMode: privacyMode,
            policy: PolicyDecisionSummary(response.policyDecision),
            approval: approvalStatus,
            audit: AuditSummary(events: auditEvents),
            delegation: DelegationDecisionSummary(delegationDecision),
            risk: RiskScoreSummary(riskScore)
        )
    }
}