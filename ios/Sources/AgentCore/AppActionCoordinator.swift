import Foundation

public struct AppActionApprovalReceipt: Equatable, Sendable {
    public let draftID: UUID
    public let fingerprint: String
    public let approvalReceipt: ApprovalReceipt
    public func matches(_ draft: AppActionDraft) -> Bool { draftID == draft.id && fingerprint == draft.fingerprint }
}

public enum AppActionApprovalEvaluation: Equatable, Sendable {
    case blocked(reason: String)
    case notRequired
    case required(AppActionApprovalReceipt)
}

public enum AppActionCoordinatorOutcome: Equatable, Sendable { case blockedPendingApproval, approved(AppActionApprovalReceipt), rejected }

public final class AppActionCoordinator: @unchecked Sendable {
    private let policyEngine: PolicyEngine
    private let approvalManager: ApprovalManager
    private let auditLog: AuditLog
    private let sensitiveDataDetector: any SensitiveDataDetecting
    private let approvalPolicy: AppActionApprovalPolicy?

    private struct PolicyContext {
        let decision: PolicyDecision
        let effectiveClassification: DataClassification
        let findings: [SensitiveDataFinding]
    }

    public init(
        riskScorer: RiskScorer = RiskScorer(),
        approvalManager: ApprovalManager = ApprovalManager(),
        auditLog: AuditLog = AuditLog(),
        sensitiveDataDetector: any SensitiveDataDetecting = SensitiveDataDetector(),
        approvalPolicy: AppActionApprovalPolicy? = nil
    ) {
        policyEngine = PolicyEngine(riskScorer: riskScorer)
        self.approvalManager = approvalManager
        self.auditLog = auditLog
        self.sensitiveDataDetector = sensitiveDataDetector
        self.approvalPolicy = approvalPolicy
    }

    public func auditEvents() -> [AuditEvent] { auditLog.allEvents() }

    public func approvalEvaluation(for draft: AppActionDraft, privacyMode: PrivacyMode) -> AppActionApprovalEvaluation {
        let context = policyContext(for: draft, privacyMode: privacyMode)
        auditLog.record(.init(type: .taskReceived, message: "Draft received: \(draft.actionKind.rawValue).", dataSensitivity: context.effectiveClassification.level))
        guard context.decision.isAllowed else {
            auditLog.record(.init(type: .blocked, message: context.decision.reason, dataSensitivity: context.effectiveClassification.level))
            return .blocked(reason: context.decision.reason)
        }
        guard approvalRequired(for: draft, decision: context.decision) else {
            auditLog.record(.init(type: .policyDecision, message: "Approval not required.", dataSensitivity: context.effectiveClassification.level))
            return .notRequired
        }
        let receipt = approvalManager.approvalReceipt(for: .init(taskSummary: "kind=\(draft.actionKind.rawValue),classification=\(context.effectiveClassification.level.rawValue),risk=\(draft.actionRisk.rawValue)", dataClassification: context.effectiveClassification, actionRisk: draft.actionRisk, reason: context.decision.reason))
        auditLog.record(.init(type: .approvalRequired, message: "Approval evaluated: \(receipt.status.rawValue).", dataSensitivity: context.effectiveClassification.level))
        guard receipt.mayContinueRouting else { return .blocked(reason: "Approval receipt denied.") }
        return .required(.init(draftID: draft.id, fingerprint: draft.fingerprint, approvalReceipt: receipt))
    }

    public func approvalReceipt(for draft: AppActionDraft, privacyMode: PrivacyMode) -> AppActionApprovalReceipt? {
        if case .required(let receipt) = approvalEvaluation(for: draft, privacyMode: privacyMode) {
            return receipt
        }
        return nil
    }

    public func perform(_ draft: AppActionDraft, privacyMode: PrivacyMode, approvalReceipt: AppActionApprovalReceipt? = nil) -> AppActionCoordinatorOutcome {
        let context = policyContext(for: draft, privacyMode: privacyMode)
        auditLog.record(.init(type: .taskReceived, message: "Draft evaluated: \(draft.actionKind.rawValue).", dataSensitivity: context.effectiveClassification.level))
        guard context.decision.isAllowed else { auditLog.record(.init(type: .blocked, message: context.decision.reason, dataSensitivity: context.effectiveClassification.level)); return .rejected }

        if approvalRequired(for: draft, decision: context.decision) {
            guard let approvalReceipt, approvalReceipt.matches(draft), approvalReceipt.approvalReceipt.mayContinueRouting else { auditLog.record(.init(type: .approvalRequired, message: "Approval receipt is stale or missing.", dataSensitivity: context.effectiveClassification.level)); return .blockedPendingApproval }
            auditLog.record(.init(type: .policyDecision, message: "Draft approved without execution.", dataSensitivity: context.effectiveClassification.level))
            return .approved(approvalReceipt)
        }

        let notRequiredReceipt = AppActionApprovalReceipt(
            draftID: draft.id,
            fingerprint: draft.fingerprint,
            approvalReceipt: .init(
                status: .notRequired,
                requestID: UUID().uuidString,
                reasonCode: context.decision.reason,
                mayContinueRouting: true
            )
        )
        auditLog.record(.init(type: .policyDecision, message: "Draft approved without execution.", dataSensitivity: context.effectiveClassification.level))
        return .approved(notRequiredReceipt)
    }

    private func approvalRequired(for draft: AppActionDraft, decision: PolicyDecision) -> Bool {
        decision.requiresApproval || (approvalPolicy?.requiresApproval(for: draft.actionKind) ?? false)
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