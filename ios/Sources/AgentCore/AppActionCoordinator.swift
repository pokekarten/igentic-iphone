import Foundation

/// Side-effect-free authorization evidence for an AppAction draft.
///
/// The exact target/payload binding stays inside the issuing coordinator.
/// `approvalReceipt.requestID` is the opaque process-local lookup identity;
/// the public receipt never carries the clear-text canonical binding.
public struct AppActionApprovalReceipt: Equatable, Sendable {
    public let draftID: UUID
    public let effectiveDataSensitivity: DataSensitivityLevel
    public let approvalReceipt: ApprovalReceipt
}

public enum AppActionApprovalEvaluation: Equatable, Sendable {
    case blocked(reason: String)
    case notRequired
    case required(AppActionApprovalReceipt)
}

public enum AppActionCoordinatorOutcome: Equatable, Sendable { case blockedPendingApproval, approved(AppActionApprovalReceipt), rejected }

public final class AppActionCoordinator: @unchecked Sendable {
    // Approval evidence is intentionally process-local. Bound retention keeps
    // private canonical bindings from growing without limit; eviction only
    // makes old receipts fail closed and never rebinds them.
    static let approvalBindingRetentionLimit = 256

    private let policyEngine: PolicyEngine
    private let approvalManager: ApprovalManager
    private let auditLog: AuditLog
    private let sensitiveDataDetector: (any SensitiveDataDetecting)?
    private let approvalPolicy: AppActionApprovalPolicy?
    private let approvalBindings: LockedBox<ApprovalBindingRegistry>

    private struct PolicyContext {
        let decision: PolicyDecision
        let effectiveClassification: DataClassification
        let findings: [SensitiveDataFinding]
    }

    private struct ApprovalBinding: Equatable {
        let draftID: UUID
        let draftFingerprint: String
        let effectiveDataSensitivity: DataSensitivityLevel
    }

    private struct ApprovalBindingRegistry {
        let capacity: Int
        var bindings: [String: ApprovalBinding] = [:]
        var insertionOrder: [String] = []

        mutating func register(_ binding: ApprovalBinding, requestID: String) -> Bool {
            guard capacity > 0,
                  !requestID.isEmpty,
                  bindings[requestID] == nil else {
                return false
            }

            bindings[requestID] = binding
            insertionOrder.append(requestID)

            if insertionOrder.count > capacity {
                let evictedRequestID = insertionOrder.removeFirst()
                bindings.removeValue(forKey: evictedRequestID)
            }
            return true
        }

        func binding(for requestID: String) -> ApprovalBinding? {
            bindings[requestID]
        }
    }

    public init(
        riskScorer: RiskScorer = RiskScorer(),
        approvalManager: ApprovalManager = ApprovalManager(),
        auditLog: AuditLog = AuditLog(),
        sensitiveDataDetector: (any SensitiveDataDetecting)? = nil,
        approvalPolicy: AppActionApprovalPolicy? = nil
    ) {
        policyEngine = PolicyEngine(riskScorer: riskScorer)
        self.approvalManager = approvalManager
        self.auditLog = auditLog
        self.sensitiveDataDetector = sensitiveDataDetector
        self.approvalPolicy = approvalPolicy
        approvalBindings = LockedBox(
            ApprovalBindingRegistry(capacity: Self.approvalBindingRetentionLimit)
        )
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
        guard receipt.status == .approved, receipt.mayContinueRouting else { return .blocked(reason: "Approval receipt denied.") }

        let binding = ApprovalBinding(
            draftID: draft.id,
            draftFingerprint: draft.fingerprint,
            effectiveDataSensitivity: context.effectiveClassification.level
        )
        let registered = approvalBindings.withValue {
            $0.register(binding, requestID: receipt.requestID)
        }
        guard registered else {
            auditLog.record(.init(type: .blocked, message: "Approval binding identity unavailable.", dataSensitivity: context.effectiveClassification.level))
            return .blocked(reason: "Approval binding identity unavailable.")
        }

        return .required(
            .init(
                draftID: draft.id,
                effectiveDataSensitivity: context.effectiveClassification.level,
                approvalReceipt: receipt
            )
        )
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
            guard let approvalReceipt,
                  approvalReceipt.approvalReceipt.status == .approved,
                  approvalReceipt.approvalReceipt.mayContinueRouting,
                  receiptMatches(
                    approvalReceipt,
                    draft: draft,
                    effectiveDataSensitivity: context.effectiveClassification.level
                  ) else {
                auditLog.record(.init(type: .approvalRequired, message: "Approval receipt is stale, missing, or not explicitly approved.", dataSensitivity: context.effectiveClassification.level))
                return .blockedPendingApproval
            }
            auditLog.record(.init(type: .policyDecision, message: "Draft approved without execution.", dataSensitivity: context.effectiveClassification.level))
            return .approved(approvalReceipt)
        }

        let notRequiredReceipt = AppActionApprovalReceipt(
            draftID: draft.id,
            effectiveDataSensitivity: context.effectiveClassification.level,
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

    private func receiptMatches(
        _ receipt: AppActionApprovalReceipt,
        draft: AppActionDraft,
        effectiveDataSensitivity: DataSensitivityLevel
    ) -> Bool {
        let binding = approvalBindings.withValue {
            $0.binding(for: receipt.approvalReceipt.requestID)
        }
        guard let binding else {
            return false
        }
        return receipt.draftID == binding.draftID
            && binding.draftID == draft.id
            && binding.draftFingerprint == draft.fingerprint
            && receipt.effectiveDataSensitivity == binding.effectiveDataSensitivity
            && binding.effectiveDataSensitivity == effectiveDataSensitivity
    }

    private func approvalRequired(for draft: AppActionDraft, decision: PolicyDecision) -> Bool {
        decision.requiresApproval || (approvalPolicy?.requiresApproval(for: draft.actionKind) ?? false)
    }

    private func policyContext(for draft: AppActionDraft, privacyMode: PrivacyMode) -> PolicyContext {
        let payloadDetection = requiredSensitiveDataDetection(
            in: draft.payloadSummary,
            supplementalDetector: sensitiveDataDetector
        )
        let targetDetection = requiredSensitiveDataDetection(
            in: draft.targetDescription,
            supplementalDetector: sensitiveDataDetector
        )
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
