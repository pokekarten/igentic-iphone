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

    public init(isAllowed: Bool, requiresApproval: Bool, reason: String) {
        self.isAllowed = isAllowed
        self.requiresApproval = requiresApproval
        self.reason = reason
    }
}

public struct PolicyEngine: Sendable {
    public init() {}

    public func decide(_ request: PolicyRequest) -> PolicyDecision {
        if request.privacyMode == .localOnly && request.requestedDelegationTarget != .none && request.requestedDelegationTarget != .localDevice {
            return PolicyDecision(isAllowed: false, requiresApproval: false, reason: "Local Only blocks non-local delegation.")
        }

        if request.dataClassification.level.blocksAutomaticExternalDelegation && request.requestedDelegationTarget != .none && request.requestedDelegationTarget != .localDevice {
            return PolicyDecision(isAllowed: false, requiresApproval: true, reason: "Restricted sensitive data cannot be delegated automatically.")
        }

        let requiresApproval = request.dataClassification.level.requiresExplicitApproval || request.actionRisk.requiresApproval

        return PolicyDecision(isAllowed: true, requiresApproval: requiresApproval, reason: "Policy allows task with current safeguards.")
    }
}
