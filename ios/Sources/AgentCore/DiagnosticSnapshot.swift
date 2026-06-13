import Foundation

public struct DiagnosticSnapshot: Equatable, Sendable {
    public let generatedAt: Date
    public let privacyMode: PrivacyMode
    public let policy: PolicyDecisionSummary
    public let approval: ApprovalStatusSummary
    public let audit: AuditSummary
    public let delegation: DelegationDecisionSummary
    public let risk: RiskScoreSummary

    public init(
        generatedAt: Date = Date(),
        privacyMode: PrivacyMode,
        policy: PolicyDecisionSummary,
        approval: ApprovalStatusSummary,
        audit: AuditSummary,
        delegation: DelegationDecisionSummary,
        risk: RiskScoreSummary
    ) {
        self.generatedAt = generatedAt
        self.privacyMode = privacyMode
        self.policy = policy
        self.approval = approval
        self.audit = audit
        self.delegation = delegation
        self.risk = risk
    }

    public var metadataLines: [String] {
        [
            "privacyMode=\(privacyMode.rawValue)",
            "policyAllowed=\(policy.isAllowed)",
            "policyRequiresApproval=\(policy.requiresApproval)",
            "approvalStatus=\(approval.status.rawValue)",
            "approvalMayContinueRouting=\(approval.mayContinueRouting)",
            "auditEventCount=\(audit.eventCount)",
            "delegationAllowed=\(delegation.isAllowed)",
            "delegationRequiresApproval=\(delegation.requiresApproval)",
            "riskValue=\(risk.value)",
            "riskRequiresApproval=\(risk.requiresExplicitApproval)"
        ]
    }
}

public struct PolicyDecisionSummary: Equatable, Sendable {
    public let isAllowed: Bool
    public let requiresApproval: Bool
    public let reasonCode: String

    public init(isAllowed: Bool, requiresApproval: Bool, reasonCode: String) {
        self.isAllowed = isAllowed
        self.requiresApproval = requiresApproval
        self.reasonCode = reasonCode
    }

    public init(_ decision: PolicyDecision) {
        self.init(
            isAllowed: decision.isAllowed,
            requiresApproval: decision.requiresApproval,
            reasonCode: decision.reason
        )
    }
}

public struct ApprovalStatusSummary: Equatable, Sendable {
    public let status: ApprovalStatus
    public let mayContinueRouting: Bool

    public init(status: ApprovalStatus, mayContinueRouting: Bool) {
        self.status = status
        self.mayContinueRouting = mayContinueRouting
    }

    public init(_ receipt: ApprovalReceipt) {
        self.init(
            status: receipt.status,
            mayContinueRouting: receipt.mayContinueRouting
        )
    }
}

public struct AuditSummary: Equatable, Sendable {
    public let eventCount: Int
    public let highestDataSensitivity: DataSensitivityLevel

    public init(eventCount: Int, highestDataSensitivity: DataSensitivityLevel) {
        self.eventCount = eventCount
        self.highestDataSensitivity = highestDataSensitivity
    }

    public init(events: [AuditEvent]) {
        let highest = events.map(\.dataSensitivity).max() ?? .publicData
        self.init(eventCount: events.count, highestDataSensitivity: highest)
    }
}

public struct DelegationDecisionSummary: Equatable, Sendable {
    public let isAllowed: Bool
    public let requiresApproval: Bool
    public let reasonCode: String

    public init(isAllowed: Bool, requiresApproval: Bool, reasonCode: String) {
        self.isAllowed = isAllowed
        self.requiresApproval = requiresApproval
        self.reasonCode = reasonCode
    }

    public init(_ decision: DelegationDecision) {
        switch decision {
        case .allowedMetadataOnly(let reason):
            self.init(isAllowed: true, requiresApproval: false, reasonCode: reason)
        case .blocked(let reason):
            self.init(isAllowed: false, requiresApproval: false, reasonCode: reason)
        case .requiresApproval(let reason):
            self.init(isAllowed: false, requiresApproval: true, reasonCode: reason)
        }
    }
}

public struct RiskScoreSummary: Equatable, Sendable {
    public let value: Int
    public let requiresExplicitApproval: Bool
    public let reasonCount: Int

    public init(value: Int, requiresExplicitApproval: Bool, reasonCount: Int) {
        self.value = value
        self.requiresExplicitApproval = requiresExplicitApproval
        self.reasonCount = reasonCount
    }

    public init(_ score: RiskScore) {
        self.init(
            value: score.value,
            requiresExplicitApproval: score.requiresExplicitApproval,
            reasonCount: score.reasons.count
        )
    }
}
