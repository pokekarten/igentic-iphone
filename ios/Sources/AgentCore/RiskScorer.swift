import Foundation

public struct RiskScoringRequest: Equatable, Sendable {
    public let privacyMode: PrivacyMode
    public let dataClassification: DataClassification
    public let actionRisk: ActionRisk
    public let delegationTarget: DelegationTarget
    public let sensitiveDataFindings: [SensitiveDataFinding]

    public init(
        privacyMode: PrivacyMode,
        dataClassification: DataClassification,
        actionRisk: ActionRisk,
        delegationTarget: DelegationTarget,
        sensitiveDataFindings: [SensitiveDataFinding] = []
    ) {
        self.privacyMode = privacyMode
        self.dataClassification = dataClassification
        self.actionRisk = actionRisk
        self.delegationTarget = delegationTarget
        self.sensitiveDataFindings = sensitiveDataFindings
    }
}

public struct RiskScore: Equatable, Sendable {
    public let value: Int
    public let reasons: [String]

    public init(value: Int, reasons: [String]) {
        self.value = min(10, max(1, value))
        self.reasons = reasons
    }

    public var requiresExplicitApproval: Bool {
        value >= 7
    }
}

public struct RiskScorer: Sendable {
    public init() {}

    public func score(_ request: RiskScoringRequest) -> RiskScore {
        var value = request.dataClassification.level.rawValue + 1
        var reasons = ["Data classification: \(request.dataClassification.level)."]

        let actionContribution = contribution(for: request.actionRisk)
        if actionContribution > 0 {
            value += actionContribution
            reasons.append("Action risk contributes \(actionContribution) point(s): \(request.actionRisk.rawValue).")
        }

        let delegationContribution = contribution(for: request.delegationTarget)
        if delegationContribution > 0 {
            value += delegationContribution
            reasons.append("Delegation target contributes \(delegationContribution) point(s): \(request.delegationTarget.rawValue).")
        }

        let privacyContribution = contribution(for: request.privacyMode, delegationTarget: request.delegationTarget)
        if privacyContribution > 0 {
            value += privacyContribution
            reasons.append("Privacy mode contributes \(privacyContribution) point(s): \(request.privacyMode.rawValue).")
        }

        for finding in request.sensitiveDataFindings {
            let findingContribution = contribution(for: finding.category)
            value += findingContribution
            reasons.append("Sensitive category contributes \(findingContribution) point(s): \(finding.category.rawValue).")
        }

        return RiskScore(value: value, reasons: reasons)
    }

    private func contribution(for actionRisk: ActionRisk) -> Int {
        switch actionRisk {
        case .read, .prepare:
            return 0
        case .execute:
            return 2
        case .destructive, .externalShare:
            return 3
        case .critical:
            return 5
        }
    }

    private func contribution(for delegationTarget: DelegationTarget) -> Int {
        switch delegationTarget {
        case .none, .localDevice:
            return 0
        case .trustedMac, .homeServer:
            return 1
        case .privateCloudCompute:
            return 2
        case .externalProvider:
            return 3
        }
    }

    private func contribution(for privacyMode: PrivacyMode, delegationTarget: DelegationTarget) -> Int {
        switch privacyMode {
        case .localOnly:
            return delegationTarget == .none || delegationTarget == .localDevice ? 0 : 3
        case .trustedDevices:
            return delegationTarget == .externalProvider ? 1 : 0
        case .externalAI:
            return 2
        }
    }

    private func contribution(for category: SensitiveDataCategory) -> Int {
        switch category {
        case .iban:
            return 3
        case .emailAddress, .phoneNumber:
            return 1
        }
    }
}
