import XCTest
@testable import AgentCore

final class ApprovalReceiptTests: XCTestCase {
    func testPendingReceiptBlocksRouting() {
        let manager = ApprovalManager(defaultStatus: .pending)
        let receipt = manager.approvalReceipt(for: ApprovalRequest(taskSummary: "t", dataClassification: .publicDefault, actionRisk: .read, reason: "pending"))
        XCTAssertEqual(receipt.status, .pending)
        XCTAssertFalse(receipt.mayContinueRouting)
    }

    func testApprovedReceiptAllowsRouting() {
        let manager = ApprovalManager(defaultStatus: .approved)
        let receipt = manager.approvalReceipt(for: ApprovalRequest(taskSummary: "t", dataClassification: .publicDefault, actionRisk: .read, reason: "approved"))
        XCTAssertTrue(receipt.mayContinueRouting)
    }

    func testRejectedReceiptBlocksRouting() {
        let manager = ApprovalManager(defaultStatus: .rejected)
        let receipt = manager.approvalReceipt(for: ApprovalRequest(taskSummary: "t", dataClassification: .publicDefault, actionRisk: .read, reason: "rejected"))
        XCTAssertEqual(receipt.status, .rejected)
        XCTAssertFalse(receipt.mayContinueRouting)
    }
}
