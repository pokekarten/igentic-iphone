import Foundation

public struct AppActionApprovalReceipt: Equatable, Sendable {
    public let draftID: UUID
    public let fingerprint: String
    public let approvalReceipt: ApprovalReceipt
    public func matches(_ draft: AppActionDraft) -> Bool { draftID == draft.id && fingerprint == draft.fingerprint }
}

public enum AppActionCoordinatorOutcome: Equatable, Sendable { case blockedPendingApproval, approved(AppActionApprovalReceipt), rejected }

public final class AppActionCoordinator: @unchecked Sendable {
    private let policyEngine: PolicyEngine
    private let approvalManager: ApprovalManager
    private let auditLog: AuditLog
    private let sensitiveDataDetector: any SensitiveDataDetecting

    private struct PolicyContext {
        let decision: PolicyDecision
        let effectiveClassification: DataClassification
        let findings: [SensitiveDataFinding]
    }

    public init(
        riskScorer: RiskScorer = RiskScorer(),
        approvalManager: ApprovalManager = ApprovalManager(),
        auditLog: AuditLog = AuditLog(),
        sensitiveDataDetector: any SensitiveDataDetecting = SensitiveDataDetector()
    ) {
        policyEngine = PolicyEngine(riskScorer: riskScorer)
        self.approvalManager = approvalManager
        self.auditLog = auditLog
        self.sensitiveDataDetector = sensitiveDataDetector
    }

    public func auditEvents() -> [AuditEvent] { auditLog.allEvents() }

    public func approvalReceipt(for draft: AppActionDraft, privacyMode: PrivacyMode) -> AppActionApprovalReceipt? {
        let context = policyContext(for: draft, privacyMode: privacyMode)
        auditLog.record(.init(type: .taskReceived, message: "Draft received: \(draft.actionKind.rawValue).", dataSensitivity: context.effectiveClassification.level))
        guard context.decision.isAllowed else { auditLog.record(.init(type: .blocked, message: context.decision.reason, dataSensitivity: context.effectiveClassification.level)); return nil }
        let receipt = approvalManager.approvalReceipt(for: .init(taskSummary: "kind=\(draft.actionKind.rawValue),classification=\(context.effectiveClassification.level.rawValue),risk=\(draft.actionRisk.rawValue)", dataClassification: context.effectiveClassification, actionRisk: draft.actionRisk, reason: context.decision.reason))
        auditLog.record(.init(type: .approvalRequired, message: "Approval evaluated: \(receipt.status.rawValue).", dataSensitivity: context.effectiveClassification.level))
        guard receipt.mayContinueRouting else { return nil }
        return .init(draftID: draft.id, fingerprint: draft.fingerprint, approvalReceipt: receipt)
    }

    public func perform(_ draft: AppActionDraft, privacyMode: PrivacyMode, approvalReceipt: AppActionApprovalReceipt? = nil) -> AppActionCoordinatorOutcome {
        let context = policyContext(for: draft, privacyMode: privacyMode)
        auditLog.record(.init(type: .taskReceived, message: "Draft evaluated: \(draft.actionKind.rawValue).", dataSensitivity: context.effectiveClassification.level))
        guard context.decision.isAllowed else { auditLog.record(.init(type: .blocked, message: context.decision.reason, dataSensitivity: context.effectiveClassification.level)); return .rejected }
        guard let approvalReceipt, approvalReceipt.matches(draft), approvalReceipt.approvalReceipt.mayContinueRouting else { auditLog.record(.init(type: .approvalRequired, message: "Approval receipt is stale or missing.", dataSensitivity: context.effectiveClassification.level)); return .blockedPendingApproval }
        auditLog.record(.init(type: .policyDecision, message: "Draft approved without execution.", dataSensitivity: context.effectiveClassification.level))
        return .approved(approvalReceipt)
    }

    private func policyContext(for draft: AppActionDraft, privacyMode: PrivacyMode) -> PolicyContext {
        let payloadDetection = sensitiveDataDetector.detect(in: draft.payloadSummary)
        let targetDetection = sensitiveDataDetector.detect(in: draft.targetDescription)
        let findings = payloadDetection.findings + targetDetection.findings
        let effectiveClassification = DataClassification.effectiveClassification(
            baseClassification: draft.dataClassification,
            detectorResult: SensitiveDataDetectionResult(findings: findings)
        )
        let decision = policyEngine.decide(
            .init(
                privacyMode: privacyMode,
                dataClassification: effectiveClassification,
                actionRisk: draft.actionRisk,
                requestedDelegationTarget: draft.requestedDelegationTarget,
                sensitiveDataFindings: findings
            )
        )
        return PolicyContext(decision: decision, effectiveClassification: effectiveClassification, findings: findings)
    }
}
