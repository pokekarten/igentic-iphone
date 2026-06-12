import Foundation

public struct PolicyRequest: Equatable, Sendable {
    public let privacyMode: PrivacyMode
    public let dataClassification: DataClassification
    public let actionRisk: ActionRisk
    public let requestedDelegationTarget: DelegationTarget

    public init(
        privacyMode: PrivacyMode,
        dataClassification: DataClassification,
        actionRisk: ActionRisk,
        requestedDelegationTarget: DelegationTarget
    ) {
        self.privacyMode = privacyMode
        self.dataClassification = dataClassification
        self.actionRisk = actionRisk
        self.requestedDelegationTarget = requestedDelegationTarget
    }
}

public struct PolicyDecision: Equatable, Sendable {
    public let isAllowed: Bool
    public let requiresApproval: Bool
    public let reason: String
    public let riskScore: RiskScore

    public init(
        isAllowed: Bool,
        requiresApproval: Bool,
        reason: String,
        riskScore: RiskScore = RiskScore(value: 1, reasons: ["Risk metadata not provided."])
    ) {
        self.isAllowed = isAllowed
        self.requiresApproval = requiresApproval
        self.reason = reason
        self.riskScore = riskScore
    }
}

public struct PolicyEngine: Sendable {
    private let riskScorer: RiskScorer

    public init(riskScorer: RiskScorer = RiskScorer()) {
        self.riskScorer = riskScorer
    }

    public func decide(_ request: PolicyRequest) -> PolicyDecision {
        let riskScore = riskScorer.score(
            RiskScoringRequest(
                privacyMode: request.privacyMode,
                dataClassification: request.dataClassification,
                actionRisk: request.actionRisk,
                delegationTarget: request.requestedDelegationTarget
            )
        )

        if request.privacyMode == .localOnly && request.requestedDelegationTarget != .none && request.requestedDelegationTarget != .localDevice {
            return PolicyDecision(
                isAllowed: false,
                requiresApproval: false,
                reason: "Local Only blocks non-local delegation.",
                riskScore: riskScore
            )
        }

        if request.dataClassification.level.blocksAutomaticExternalDelegation && request.requestedDelegationTarget != .none && request.requestedDelegationTarget != .localDevice {
            return PolicyDecision(
                isAllowed: false,
                requiresApproval: true,
                reason: "Restricted sensitive data cannot be delegated automatically.",
                riskScore: riskScore
            )
        }

        let requiresApproval = request.dataClassification.level.requiresExplicitApproval || request.actionRisk.requiresApproval

        return PolicyDecision(
            isAllowed: true,
            requiresApproval: requiresApproval,
            reason: "Policy allows task with current safeguards.",
            riskScore: riskScore
        )
    }
}
