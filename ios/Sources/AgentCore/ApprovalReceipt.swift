import Foundation

public struct ApprovalReceipt: Equatable, Sendable {
    public let status: ApprovalStatus
    public let requestID: String
    public let reasonCode: String
    public let mayContinueRouting: Bool

    public init(
        status: ApprovalStatus,
        requestID: String,
        reasonCode: String,
        mayContinueRouting: Bool
    ) {
        self.status = status
        self.requestID = requestID
        self.reasonCode = reasonCode
        self.mayContinueRouting = mayContinueRouting
    }
}
