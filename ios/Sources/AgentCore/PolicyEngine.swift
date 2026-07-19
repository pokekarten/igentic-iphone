import Foundation

public struct PolicyRequest: Equatable, Sendable {
    public let privacyMode: PrivacyMode
    public let dataClassification: DataClassification
    public let actionRisk: ActionRisk
    public let requestedDelegationTarget: DelegationTarget
    /// Detector findings for the current task, if any.
    ///
    /// These findings are informational input for `RiskScorer` only. They do not
    /// bypass or replace the policy gates derived from privacy mode, data
    /// classification, or action risk.
    public let sensitiveDataFindings: [SensitiveDataFinding]

    public init(
        privacyMode: PrivacyMode,
        dataClassification: DataClassification,
        actionRisk: ActionRisk,
        requestedDelegationTarget: DelegationTarget,
        sensitiveDataFindings: [SensitiveDataFinding] = []
    ) {
        self.privacyMode = privacyMode
        self.dataClassification = dataClassification
        self.actionRisk = actionRisk
        self.requestedDelegationTarget = requestedDelegationTarget
        self.sensitiveDataFindings = sensitiveDataFindings
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
    case externalProviderRequiresApproval
}

public struct PolicyDecision: Equatable, Sendable {
    public let isAllowed: Bool
    public let requiresApproval: Bool
    public let reasonCode: PolicyDecisionReason
    public let reason: String
    /// Informational risk signal from `RiskScorer`.
    ///
    /// This is intentionally metadata-only for the current project phase.
    /// `isAllowed` and `requiresApproval` are derived solely from
    /// `dataClassification`, `actionRisk`, and `requestedDelegationTarget`
    /// (see `PolicyEngine.decide`), never from `riskScore`.
    /// `RiskScore.requiresExplicitApproval` is a candidate signal for a
    /// possible future policy, not an active gate.
    ///
    /// This is deliberately pinned by
    /// `SmokeTests.testPolicyRiskScoreDoesNotAddApprovalByItself`. Do not
    /// make `riskScore` influence `isAllowed`/`requiresApproval` without
    /// first updating that test name and assertion to match the new
    /// intent — it exists specifically to catch this change.
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
                delegationTarget: request.requestedDelegationTarget,
                sensitiveDataFindings: request.sensitiveDataFindings
            )
        )

        if request.privacyMode == .localOnly,
           request.requestedDelegationTarget == .externalProvider {
            return PolicyDecision(
                isAllowed: false,
                requiresApproval: false,
                reasonCode: .localOnlyBlocksNonLocalDelegation,
                reason: "Local Only blocks non-local delegation.",
                riskScore: riskScore
            )
        }

        if request.dataClassification.level.blocksAutomaticExternalDelegation,
           request.requestedDelegationTarget != .none,
           request.requestedDelegationTarget != .localDevice {
            return PolicyDecision(
                isAllowed: false,
                requiresApproval: false,
                reasonCode: .restrictedDataBlocksAutomaticExternalDelegation,
                reason: "Restricted sensitive data cannot be delegated automatically.",
                riskScore: riskScore
            )
        }

        if request.privacyMode == .localOnly,
           request.requestedDelegationTarget != .none,
           request.requestedDelegationTarget != .localDevice {
            return PolicyDecision(
                isAllowed: false,
                requiresApproval: false,
                reasonCode: .localOnlyBlocksNonLocalDelegation,
                reason: "Local Only blocks non-local delegation.",
                riskScore: riskScore
            )
        }

        let externalProviderRequiresApproval = request.requestedDelegationTarget == .externalProvider
        let dataRequiresApproval = request.dataClassification.level.requiresExplicitApproval
        let actionRequiresApproval = request.actionRisk.requiresApproval
        let requiresApproval = externalProviderRequiresApproval || dataRequiresApproval || actionRequiresApproval

        return PolicyDecision(
            isAllowed: true,
            requiresApproval: requiresApproval,
            reasonCode: reasonCode(
                dataRequiresApproval: dataRequiresApproval,
                actionRequiresApproval: actionRequiresApproval,
                externalProviderRequiresApproval: externalProviderRequiresApproval
            ),
            reason: "Policy allows task with current safeguards.",
            riskScore: riskScore
        )
    }

    private func reasonCode(
        dataRequiresApproval: Bool,
        actionRequiresApproval: Bool,
        externalProviderRequiresApproval: Bool
    ) -> PolicyDecisionReason {
        switch (externalProviderRequiresApproval, dataRequiresApproval, actionRequiresApproval) {
        case (true, _, _):
            return .externalProviderRequiresApproval
        case (false, false, false):
            return .allowedWithCurrentSafeguards
        case (false, true, false):
            return .dataRequiresApproval
        case (false, false, true):
            return .actionRequiresApproval
        case (false, true, true):
            return .dataAndActionRequireApproval
        }
    }
}