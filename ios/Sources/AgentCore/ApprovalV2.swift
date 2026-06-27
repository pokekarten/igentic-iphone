import Foundation

// MARK: - v2 Decision Engine

public protocol ApprovalDecisionEngine: Sendable {
    func evaluate(_ request: ApprovalRequest) async -> ApprovalStatus
}

public protocol ApprovalRuleEngine: Sendable {
    func evaluate(_ request: ApprovalRequest) -> RuleResult
}

public struct RuleResult: Sendable {
    public let allowsProceeding: Bool
    public let reasons: [String]

    public init(allowsProceeding: Bool, reasons: [String]) {
        self.allowsProceeding = allowsProceeding
        self.reasons = reasons
    }
}

public protocol RiskScoringEngine: Sendable {
    func score(_ request: ApprovalRequest) -> Double
}

public protocol AsyncApprovalHandler: Sendable {
    func requestApproval(_ request: ApprovalRequest) async -> Bool
}

public final class DefaultApprovalDecisionEngine: ApprovalDecisionEngine {

    private let ruleEngine: ApprovalRuleEngine
    private let riskEngine: RiskScoringEngine
    private let policy: ApprovalDecisionPolicy
    private let asyncHandler: AsyncApprovalHandler?

    public init(
        ruleEngine: ApprovalRuleEngine,
        riskEngine: RiskScoringEngine,
        policy: ApprovalDecisionPolicy,
        asyncHandler: AsyncApprovalHandler? = nil
    ) {
        self.ruleEngine = ruleEngine
        self.riskEngine = riskEngine
        self.policy = policy
        self.asyncHandler = asyncHandler
    }

    public func evaluate(_ request: ApprovalRequest) async -> ApprovalStatus {

        let rule = ruleEngine.evaluate(request)
        guard rule.allowsProceeding else {
            return .rejected
        }

        _ = riskEngine.score(request)

        let decision = policy.decide(request)

        if decision == .pending, let asyncHandler {
            let approved = await asyncHandler.requestApproval(request)
            return approved ? .approved : .rejected
        }

        return decision
    }
}
