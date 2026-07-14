import XCTest
@testable import AgentCore

final class AgentKernelApprovalReceiptWiringTests: XCTestCase {
    func testKernelReturnsApprovalReceiptWhenApprovalIsRequired() {
        let kernel = AgentKernel(approvalManager: ApprovalManager(defaultStatus: .pending))
        let task = TaskRequest(
            userText: "Please approve this local action.",
            intent: .requestApproval,
            dataClassification: .publicDefault,
            actionRisk: .execute,
            requestedDelegationTarget: .localDevice
        )

        let response = kernel.handle(task, privacyMode: .trustedDevices)

        XCTAssertTrue(response.policyDecision.isAllowed)
        XCTAssertTrue(response.policyDecision.requiresApproval)
        XCTAssertEqual(response.approvalStatus, .pending)
        XCTAssertEqual(response.route, .approvalRequired(reason: "Approval is required before routing."))
        XCTAssertNotNil(response.approvalReceipt)
        XCTAssertEqual(response.approvalReceipt?.status, .pending)
        XCTAssertEqual(response.approvalReceipt?.mayContinueRouting, false)
        XCTAssertEqual(response.approvalReceipt?.reasonCode, response.policyDecision.reason)
    }

    func testDiagnosticSnapshotUsesKernelApprovalReceipt() {
        let producer = DiagnosticSnapshotProducer(approvalManager: ApprovalManager(defaultStatus: .pending))
        let task = TaskRequest(
            userText: "Please approve this local action.",
            intent: .requestApproval,
            dataClassification: .publicDefault,
            actionRisk: .execute,
            requestedDelegationTarget: .localDevice
        )

        let snapshot = producer.produceSnapshot(
            for: task,
            privacyMode: .trustedDevices,
            generatedAt: Date(timeIntervalSince1970: 123)
        )

        XCTAssertEqual(snapshot.generatedAt, Date(timeIntervalSince1970: 123))
        XCTAssertEqual(snapshot.policy.isAllowed, true)
        XCTAssertEqual(snapshot.policy.requiresApproval, true)
        XCTAssertEqual(snapshot.approval.status, .pending)
        XCTAssertFalse(snapshot.approval.mayContinueRouting)
        XCTAssertEqual(snapshot.metadataLines.first, "generatedAt=123.0")
        XCTAssertTrue(snapshot.metadataLines.contains("approvalStatus=pending"))
    }

    func testKernelLeavesApprovalReceiptNilOnFastPath() {
        let kernel = AgentKernel()
        let task = TaskRequest(
            userText: "Summarize the note.",
            intent: .summarizeNote,
            dataClassification: .publicDefault,
            actionRisk: .prepare,
            requestedDelegationTarget: .localDevice
        )

        let response = kernel.handle(task, privacyMode: .localOnly)

        XCTAssertTrue(response.policyDecision.isAllowed)
        XCTAssertFalse(response.policyDecision.requiresApproval)
        XCTAssertEqual(response.approvalStatus, .notRequired)
        XCTAssertNil(response.approvalReceipt)
        XCTAssertEqual(response.route, .localTool(name: "summarizeNote", reason: "Note summarization must stay local unless policy allows delegation."))
    }
}