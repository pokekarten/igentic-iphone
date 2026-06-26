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

public struct ApprovalManager: Sendable {
    private let defaultStatus: ApprovalStatus

    public init(defaultStatus: ApprovalStatus = .pending) {
        self.defaultStatus = defaultStatus
    }

    /// Placeholder policy.
    ///
    /// This currently returns the configured default status.
    /// Future implementations can evaluate RiskScore, DataClassification
    /// or an interactive approval flow here.
    private func evaluate(_ request: ApprovalRequest) -> ApprovalStatus {
        defaultStatus
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