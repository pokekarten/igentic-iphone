import Foundation

// MARK: - Default v2 Implementations (no-op safe defaults)

public struct NoOpRuleEngine: ApprovalRuleEngine {
    public init() {}

    public func evaluate(_ request: ApprovalRequest) -> RuleResult {
        RuleResult(allowsProceeding: true, reasons: [])
    }
}

public struct SimpleRiskEngine: RiskScoringEngine {
    public init() {}

    public func score(_ request: ApprovalRequest) -> Double {
        switch request.actionRisk {
        case .low: return 0.1
        case .medium: return 0.5
        case .high: return 0.9
        }
    }
}

public struct NoOpAsyncApprovalHandler: AsyncApprovalHandler {
    public init() {}

    public func requestApproval(_ request: ApprovalRequest) async -> Bool {
        true
    }
}

public extension DefaultApprovalDecisionEngine {
    static func live(policy: ApprovalDecisionPolicy) -> DefaultApprovalDecisionEngine {
        DefaultApprovalDecisionEngine(
            ruleEngine: NoOpRuleEngine(),
            riskEngine: SimpleRiskEngine(),
            policy: policy,
            asyncHandler: nil
        )
    }
}
