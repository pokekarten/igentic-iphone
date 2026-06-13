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

    public func requestApproval(_ request: ApprovalRequest) -> ApprovalStatus {
        defaultStatus
    }

    public func approvalReceipt(for request: ApprovalRequest) -> ApprovalReceipt {
        ApprovalReceipt(
            status: defaultStatus,
            requestID: "approval-\(defaultStatus.rawValue)",
            reasonCode: request.reason,
            mayContinueRouting: defaultStatus == .approved || defaultStatus == .notRequired
        )
    }
}
