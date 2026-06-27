import Foundation

public enum ApprovalStatus: String, Equatable, Sendable {
    case notRequired
    case approved
    case pending
    case rejected
}

public struct ApprovalRequest: Equatable, Sendable {
    public let taskSummary: String
    public let dataClassification: DataClassification
    public let actionRisk: ActionRisk
    public let reason: String

    public init(
        taskSummary: String,
        dataClassification: DataClassification,
        actionRisk: ActionRisk,
        reason: String
    ) {
        self.taskSummary = taskSummary
        self.dataClassification = dataClassification
        self.actionRisk = actionRisk
        self.reason = reason
    }
}

// MARK: - Decision Policy

public protocol ApprovalDecisionPolicy: Sendable {
    func decide(_ request: ApprovalRequest) -> ApprovalStatus
}

public struct FixedApprovalDecisionPolicy: ApprovalDecisionPolicy {
    private let defaultStatus: ApprovalStatus

    public init(defaultStatus: ApprovalStatus) {
        self.defaultStatus = defaultStatus
    }

    public func decide(_ request: ApprovalRequest) -> ApprovalStatus {
        defaultStatus
    }
}

/// Optional policy using risk signals (not default-wired)
public struct RiskScoreApprovalPolicy: ApprovalDecisionPolicy {
    public init() {}

    public func decide(_ request: ApprovalRequest) -> ApprovalStatus {
        // updated comment
        if let score = try? RiskScore(request: request), score.requiresExplicitApproval {
            return .pending
        } else {
            return .approved
        }
    }
}

public struct ApprovalManager: Sendable {
    private let defaultStatus: ApprovalStatus
    private let policy: ApprovalDecisionPolicy

    public init(
        defaultStatus: ApprovalStatus = .pending,
        policy: ApprovalDecisionPolicy? = nil
    ) {
        self.defaultStatus = defaultStatus
        self.policy = policy ?? FixedApprovalDecisionPolicy(defaultStatus: defaultStatus)
    }

    /// Placeholder policy.
    ///
    /// This currently delegates to the configured decision policy.
    private func evaluate(_ request: ApprovalRequest) -> ApprovalStatus {
        policy.decide(request)
    }

    public func requestApproval(_ request: ApprovalRequest) -> ApprovalStatus {
        evaluate(request)
    }

    public func approvalReceipt(for request: ApprovalRequest) -> ApprovalReceipt {
        let status = requestApproval(request)

        return ApprovalReceipt(
            status: status,
            requestID: UUID().uuidString,
            reasonCode: request.reason,
            mayContinueRouting: status == .approved || status == .notRequired
        )
    }
}
