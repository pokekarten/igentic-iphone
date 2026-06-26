import XCTest
@testable import AgentCore

final class ApprovalReceiptTests: XCTestCase {
    func testPendingReceiptBlocksRouting() {
        let manager = ApprovalManager(defaultStatus: .pending)
        let receipt = manager.approvalReceipt(for: ApprovalRequest(taskSummary: "t", dataClassification: .publicDefault, actionRisk: .read, reason: "pending"))
        XCTAssertEqual(receipt.status, .pending)
        XCTAssertFalse(receipt.mayContinueRouting)
        XCTAssertFalse(receipt.requestID.isEmpty)
    }

    func testApprovedReceiptAllowsRouting() {
        let manager = ApprovalManager(defaultStatus: .approved)
        let receipt = manager.approvalReceipt(for: ApprovalRequest(taskSummary: "t", dataClassification: .publicDefault, actionRisk: .read, reason: "approved"))
        XCTAssertTrue(receipt.mayContinueRouting)
        XCTAssertFalse(receipt.requestID.isEmpty)
    }

    func testRejectedReceiptBlocksRouting() {
        let manager = ApprovalManager(defaultStatus: .rejected)
        let receipt = manager.approvalReceipt(for: ApprovalRequest(taskSummary: "t", dataClassification: .publicDefault, actionRisk: .read, reason: "rejected"))
        XCTAssertEqual(receipt.status, .rejected)
        XCTAssertFalse(receipt.mayContinueRouting)
        XCTAssertFalse(receipt.requestID.isEmpty)
    }

    func testRequestApprovalReturnsConfiguredStatus() {
        let manager = ApprovalManager(defaultStatus: .approved)
        let status = manager.requestApproval(ApprovalRequest(taskSummary: "t", dataClassification: .publicDefault, actionRisk: .read, reason: "approved"))
        XCTAssertEqual(status, .approved)
    }
}