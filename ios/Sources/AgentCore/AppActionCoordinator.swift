import Foundation

public struct AppActionApprovalReceipt: Equatable, Sendable {
    public let draftID: UUID
    public let draftFingerprint: String
    public let actionKind: AppActionDraft.ActionKind
    public let approvalReceipt: ApprovalReceipt

    public init(
        draftID: UUID,
        draftFingerprint: String,
        actionKind: AppActionDraft.ActionKind,
        approvalReceipt: ApprovalReceipt
    ) {
        self.draftID = draftID
        self.draftFingerprint = draftFingerprint
        self.actionKind = actionKind
        self.approvalReceipt = approvalReceipt
    }

    public func matches(_ draft: AppActionDraft) -> Bool {
        draftID == draft.id && draftFingerprint == Self.fingerprint(for: draft)
    }

    public static func fingerprint(for draft: AppActionDraft) -> String {
        [
            draft.id.uuidString,
            draft.actionKind.rawValue,
            draft.targetDescription,
            draft.payloadSummary,
            String(draft.dataClassification.level.rawValue),
            draft.actionRisk.rawValue
        ]
        .joined(separator: "|")
    }
}

public enum AppActionCoordinatorOutcome: Equatable, Sendable {
    case blockedPendingApproval
    case approved(AppActionApprovalReceipt)
    case rejected
}

public final class AppActionCoordinator: @unchecked Sendable {
    private let policyEngine: PolicyEngine
    private let approvalManager: ApprovalManager
    private let auditLog: AuditLog

    public init(
        riskScorer: RiskScorer = RiskScorer(),
        approvalManager: ApprovalManager = ApprovalManager(),
        auditLog: AuditLog = AuditLog()
    ) {
        self.policyEngine = PolicyEngine(riskScorer: riskScorer)
        self.approvalManager = approvalManager
        self.auditLog = auditLog
    }

    public func auditEvents() -> [AuditEvent] {
        auditLog.allEvents()
    }

    public func approvalReceipt(
        for draft: AppActionDraft,
        privacyMode: PrivacyMode
    ) -> AppActionApprovalReceipt? {
        let decision = policyDecision(for: draft, privacyMode: privacyMode)

        auditLog.record(
            AuditEvent(
                type: .taskReceived,
                message: "Draft received: \(draft.actionKind.rawValue).",
                dataSensitivity: draft.dataClassification.level
            )
        )

        guard decision.isAllowed else {
            auditLog.record(
                AuditEvent(
                    type: .blocked,
                    message: decision.reason,
                    dataSensitivity: draft.dataClassification.level
                )
            )
            return nil
        }

        let approvalRequest = ApprovalRequest(
            taskSummary: "kind=\(draft.actionKind.rawValue),classification=\(draft.dataClassification.level.rawValue),risk=\(draft.actionRisk.rawValue)",
            dataClassification: draft.dataClassification,
            actionRisk: draft.actionRisk,
            reason: decision.reason
        )
        let receipt = approvalManager.approvalReceipt(for: approvalRequest)

        auditLog.record(
            AuditEvent(
                type: .approvalRequired,
                message: "Approval evaluated: \(receipt.status.rawValue).",
                dataSensitivity: draft.dataClassification.level
            )
        )

        guard receipt.status == .approved || receipt.status == .notRequired else {
            return nil
        }

        return AppActionApprovalReceipt(
            draftID: draft.id,
            draftFingerprint: AppActionApprovalReceipt.fingerprint(for: draft),
            actionKind: draft.actionKind,
            approvalReceipt: receipt
        )
    }

    public func perform(
        _ draft: AppActionDraft,
        privacyMode: PrivacyMode,
        approvalReceipt: AppActionApprovalReceipt? = nil
    ) -> AppActionCoordinatorOutcome {
        let decision = policyDecision(for: draft, privacyMode: privacyMode)

        auditLog.record(
            AuditEvent(
                type: .taskReceived,
                message: "Draft evaluated: \(draft.actionKind.rawValue).",
                dataSensitivity: draft.dataClassification.level
            )
        )

        guard decision.isAllowed else {
            auditLog.record(
                AuditEvent(
                    type: .blocked,
                    message: decision.reason,
                    dataSensitivity: draft.dataClassification.level
                )
            )
            return .rejected
        }

        guard let approvalReceipt else {
            auditLog.record(
                AuditEvent(
                    type: .approvalRequired,
                    message: "Draft requires a matching approval receipt.",
                    dataSensitivity: draft.dataClassification.level
                )
            )
            return .blockedPendingApproval
        }

        guard approvalReceipt.matches(draft), approvalReceipt.approvalReceipt.mayContinueRouting else {
            auditLog.record(
                AuditEvent(
                    type: .approvalRequired,
                    message: "Approval receipt is stale or invalid.",
                    dataSensitivity: draft.dataClassification.level
                )
            )
            return .blockedPendingApproval
        }

        auditLog.record(
            AuditEvent(
                type: .policyDecision,
                message: "Draft approved without execution.",
                dataSensitivity: draft.dataClassification.level
            )
        )

        return .approved(approvalReceipt)
    }

    private func policyDecision(for draft: AppActionDraft, privacyMode: PrivacyMode) -> PolicyDecision {
        policyEngine.decide(
            PolicyRequest(
                privacyMode: privacyMode,
                dataClassification: draft.dataClassification,
                actionRisk: draft.actionRisk,
                requestedDelegationTarget: requestedDelegationTarget(for: draft),
                sensitiveDataFindings: []
            )
        )
    }

    private func requestedDelegationTarget(for draft: AppActionDraft) -> DelegationTarget {
        switch draft.actionKind {
        case .sendMessage:
            return .externalProvider
        case .deleteRecord:
            return .none
        case .updateRecord:
            return .localDevice
        case .exportData:
            return .trustedMac
        }
    }
}
