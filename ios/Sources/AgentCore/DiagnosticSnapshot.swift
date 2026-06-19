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
            "generatedAt=\(generatedAt.timeIntervalSince1970)",
            "privacyMode=\(privacyMode.rawValue)",
            "policyAllowed=\(policy.isAllowed)",
            "policyRequiresApproval=\(policy.requiresApproval)",
            "approvalStatus=\(approval.status.rawValue)",
            "approvalMayContinueRouting=\(approval.mayContinueRouting)",
            "auditEventCount=\(audit.eventCount)",
            "auditHighestSensitivity=\(audit.highestDataSensitivity.rawValue)",
            "delegationOutcome=\(delegation.outcome.rawValue)",
            "riskValue=\(risk.value)",
            "riskRequiresApproval=\(risk.requiresExplicitApproval)",
            "riskReasonCount=\(risk.reasonCount)",
        ]
    }
}

public struct PolicyDecisionSummary: Equatable, Sendable {
    public let isAllowed: Bool
    public let requiresApproval: Bool

    public init(isAllowed: Bool, requiresApproval: Bool) {
        self.isAllowed = isAllowed
        self.requiresApproval = requiresApproval
    }

    public init(_ decision: PolicyDecision) {
        self.init(
            isAllowed: decision.isAllowed,
            requiresApproval: decision.requiresApproval
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
        self.eventCount = max(0, eventCount)
        self.highestDataSensitivity = highestDataSensitivity
    }

    public init(events: [AuditEvent]) {
        self.init(
            eventCount: events.count,
            highestDataSensitivity: events.map(\.dataSensitivity).max() ?? .publicData
        )
    }
}

public enum DelegationOutcome: String, Equatable, Sendable {
    case blocked
    case requiresApproval
    case allowedMetadataOnly
}

public struct DelegationDecisionSummary: Equatable, Sendable {
    public let outcome: DelegationOutcome

    public init(outcome: DelegationOutcome) {
        self.outcome = outcome
    }

    public init(_ decision: DelegationDecision) {
        switch decision {
        case .blocked:
            self.init(outcome: .blocked)
        case .requiresApproval:
            self.init(outcome: .requiresApproval)
        case .allowedMetadataOnly:
            self.init(outcome: .allowedMetadataOnly)
        }
    }
}

public struct RiskScoreSummary: Equatable, Sendable {
    public let value: Int
    public let requiresExplicitApproval: Bool
    public let reasonCount: Int

    public init(value: Int, requiresExplicitApproval: Bool, reasonCount: Int) {
        self.value = min(10, max(1, value))
        self.requiresExplicitApproval = requiresExplicitApproval
        self.reasonCount = max(0, reasonCount)
    }

    public init(_ score: RiskScore) {
        self.init(
            value: score.value,
            requiresExplicitApproval: score.requiresExplicitApproval,
            reasonCount: score.reasons.count
        )
    }
}
