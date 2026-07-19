import Foundation

public struct AppActionApprovalReceipt: Equatable, Sendable {
    public let draftID: UUID
    public let fingerprint: String
    public let approvalReceipt: ApprovalReceipt
    public func matches(_ draft: AppActionDraft) -> Bool { draftID == draft.id && fingerprint == draft.fingerprint }
}

public enum AppActionCoordinatorOutcome: Equatable, Sendable { case blockedPendingApproval, approved(AppActionApprovalReceipt), rejected }

public final class AppActionCoordinator: @unchecked Sendable {
    private let policyEngine: PolicyEngine, approvalManager: ApprovalManager, auditLog: AuditLog
    public init(riskScorer: RiskScorer = RiskScorer(), approvalManager: ApprovalManager = ApprovalManager(), auditLog: AuditLog = AuditLog()) {
        policyEngine = PolicyEngine(riskScorer: riskScorer); self.approvalManager = approvalManager; self.auditLog = auditLog
    }
    public func auditEvents() -> [AuditEvent] { auditLog.allEvents() }

    public func approvalReceipt(for draft: AppActionDraft, privacyMode: PrivacyMode) -> AppActionApprovalReceipt? {
        let decision = policyDecision(for: draft, privacyMode: privacyMode)
        auditLog.record(.init(type: .taskReceived, message: "Draft received: \(draft.actionKind.rawValue).", dataSensitivity: draft.dataClassification.level))
        guard decision.isAllowed else { auditLog.record(.init(type: .blocked, message: decision.reason, dataSensitivity: draft.dataClassification.level)); return nil }
        let receipt = approvalManager.approvalReceipt(for: .init(taskSummary: "kind=\(draft.actionKind.rawValue),classification=\(draft.dataClassification.level.rawValue),risk=\(draft.actionRisk.rawValue)", dataClassification: draft.dataClassification, actionRisk: draft.actionRisk, reason: decision.reason))
        auditLog.record(.init(type: .approvalRequired, message: "Approval evaluated: \(receipt.status.rawValue).", dataSensitivity: draft.dataClassification.level))
        guard receipt.mayContinueRouting else { return nil }
        return .init(draftID: draft.id, fingerprint: draft.fingerprint, approvalReceipt: receipt)
    }

    public func perform(_ draft: AppActionDraft, privacyMode: PrivacyMode, approvalReceipt: AppActionApprovalReceipt? = nil) -> AppActionCoordinatorOutcome {
        let decision = policyDecision(for: draft, privacyMode: privacyMode)
        auditLog.record(.init(type: .taskReceived, message: "Draft evaluated: \(draft.actionKind.rawValue).", dataSensitivity: draft.dataClassification.level))
        guard decision.isAllowed else { auditLog.record(.init(type: .blocked, message: decision.reason, dataSensitivity: draft.dataClassification.level)); return .rejected }
        guard let approvalReceipt, approvalReceipt.matches(draft), approvalReceipt.approvalReceipt.mayContinueRouting else { auditLog.record(.init(type: .approvalRequired, message: "Approval receipt is stale or missing.", dataSensitivity: draft.dataClassification.level)); return .blockedPendingApproval }
        auditLog.record(.init(type: .policyDecision, message: "Draft approved without execution.", dataSensitivity: draft.dataClassification.level))
        return .approved(approvalReceipt)
    }

    private func policyDecision(for draft: AppActionDraft, privacyMode: PrivacyMode) -> PolicyDecision {
        policyEngine.decide(.init(privacyMode: privacyMode, dataClassification: draft.dataClassification, actionRisk: draft.actionRisk, requestedDelegationTarget: draft.requestedDelegationTarget, sensitiveDataFindings: []))
    }
}
