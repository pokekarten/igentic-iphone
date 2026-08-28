import Foundation

public struct DiagnosticSnapshotProducer: Sendable {
    private let approvalManager: ApprovalManager
    private let riskScorer: RiskScorer
    private let delegationBroker: DelegationBroker
    private let sensitiveDataDetector: (any SensitiveDataDetecting)?
    private let runtimeBudgetAssessor: RuntimeBudgetAssessor

    public init(
        approvalManager: ApprovalManager = ApprovalManager(),
        riskScorer: RiskScorer = RiskScorer(),
        delegationBroker: DelegationBroker = DelegationBroker(),
        sensitiveDataDetector: (any SensitiveDataDetecting)? = nil,
        runtimeBudgetAssessor: RuntimeBudgetAssessor = RuntimeBudgetAssessor()
    ) {
        self.approvalManager = approvalManager
        self.riskScorer = riskScorer
        self.delegationBroker = delegationBroker
        self.sensitiveDataDetector = sensitiveDataDetector
        self.runtimeBudgetAssessor = runtimeBudgetAssessor
    }

    public func produceSnapshot(
        for task: TaskRequest,
        privacyMode: PrivacyMode,
        generatedAt: Date = Date()
    ) -> DiagnosticSnapshot {
        let detection = requiredSensitiveDataDetection(
            in: task.userText,
            supplementalDetector: sensitiveDataDetector
        )
        let effectiveDataClassification = DataClassification.effectiveClassification(
            baseClassification: task.dataClassification,
            detectorResult: detection
        )

        let kernel = AgentKernel(
            approvalManager: approvalManager,
            runtimeBudgetAssessor: runtimeBudgetAssessor
        )
        let response = kernel.handle(task, privacyMode: privacyMode, precomputedDetection: detection)
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

        let approvalStatusSummary: ApprovalStatusSummary
        if let approvalReceipt = response.approvalReceipt {
            approvalStatusSummary = ApprovalStatusSummary(approvalReceipt)
        } else {
            approvalStatusSummary = ApprovalStatusSummary(
                status: response.approvalStatus,
                mayContinueRouting: response.approvalStatus == .approved || response.approvalStatus == .notRequired
            )
        }

        return DiagnosticSnapshot(
            generatedAt: generatedAt,
            privacyMode: privacyMode,
            policy: PolicyDecisionSummary(response.policyDecision),
            approval: approvalStatusSummary,
            audit: AuditSummary(events: auditEvents),
            delegation: DelegationDecisionSummary(delegationDecision),
            risk: RiskScoreSummary(riskScore),
            runtimeBudget: response.runtimeBudgetSummary
        )
    }
}