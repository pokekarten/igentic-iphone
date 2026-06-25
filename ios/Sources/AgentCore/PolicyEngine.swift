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

public enum PolicyDecisionReason: String, Equatable, Sendable {
    case unspecified
    case localOnlyBlocksNonLocalDelegation
    case restrictedDataBlocksAutomaticExternalDelegation
    case allowedWithCurrentSafeguards
    case dataRequiresApproval
    case actionRequiresApproval
    case dataAndActionRequireApproval
}

public struct PolicyDecision: Equatable, Sendable {
    public let isAllowed: Bool
    public let requiresApproval: Bool
    public let reasonCode: PolicyDecisionReason
    public let reason: String
    public let riskScore: RiskScore

    public init(
        isAllowed: Bool,
        requiresApproval: Bool,
        reasonCode: PolicyDecisionReason = .unspecified,
        reason: String,
        riskScore: RiskScore = RiskScore(value: 1, reasons: ["Risk metadata not provided."])
    ) {
        self.isAllowed = isAllowed
        self.requiresApproval = requiresApproval
        self.reasonCode = reasonCode
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

        if request.privacyMode == .localOnly && request.requestedDelegationTarget.leavesLocalDevice {
            return PolicyDecision(
                isAllowed: false,
                requiresApproval: false,
                reasonCode: .localOnlyBlocksNonLocalDelegation,
                reason: "Local Only blocks non-local delegation.",
                riskScore: riskScore
            )
        }

        if request.dataClassification.level.blocksAutomaticExternalDelegation && request.requestedDelegationTarget.leavesLocalDevice {
            return PolicyDecision(
                isAllowed: false,
                requiresApproval: true,
                reasonCode: .restrictedDataBlocksAutomaticExternalDelegation,
                reason: "Restricted sensitive data cannot be delegated automatically.",
                riskScore: riskScore
            )
        }

        let dataRequiresApproval = request.dataClassification.level.requiresExplicitApproval
        let actionRequiresApproval = request.actionRisk.requiresApproval
        let requiresApproval = dataRequiresApproval || actionRequiresApproval

        return PolicyDecision(
            isAllowed: true,
            requiresApproval: requiresApproval,
            reasonCode: reasonCode(
                dataRequiresApproval: dataRequiresApproval,
                actionRequiresApproval: actionRequiresApproval
            ),
            reason: "Policy allows task with current safeguards.",
            riskScore: riskScore
        )
    }

    private func reasonCode(
        dataRequiresApproval: Bool,
        actionRequiresApproval: Bool
    ) -> PolicyDecisionReason {
        switch (dataRequiresApproval, actionRequiresApproval) {
        case (false, false):
            return .allowedWithCurrentSafeguards
        case (true, false):
            return .dataRequiresApproval
        case (false, true):
            return .actionRequiresApproval
        case (true, true):
            return .dataAndActionRequireApproval
        }
    }
}
