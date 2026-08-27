import XCTest
@testable import AgentCore

final class AppActionDraftFingerprintTests: XCTestCase {
    private let sharedID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

    private func draft(target: String, payload: String) -> AppActionDraft {
        AppActionDraft(
            id: sharedID,
            actionKind: .deleteRecord,
            targetDescription: target,
            payloadSummary: payload,
            dataClassification: .publicDefault,
            actionRisk: .execute
        )
    }

    func testFingerprintDistinguishesDelimiterShiftAcrossTargetAndPayload() {
        let first = draft(target: "alpha|beta", payload: "gamma")
        let second = draft(target: "alpha", payload: "beta|gamma")

        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(first.fingerprint, second.fingerprint)
    }

    func testApprovalReceiptCannotReplayAcrossDelimiterCollisionDrafts() {
        let coordinator = AppActionCoordinator(
            approvalManager: ApprovalManager(defaultStatus: .approved)
        )
        let approvedDraft = draft(target: "alpha|beta", payload: "gamma")
        let changedDraft = draft(target: "alpha", payload: "beta|gamma")
        let receipt = coordinator.approvalReceipt(
            for: approvedDraft,
            privacyMode: .trustedDevices
        )

        XCTAssertNotNil(receipt)
        XCTAssertEqual(
            coordinator.perform(
                changedDraft,
                privacyMode: .trustedDevices,
                approvalReceipt: receipt
            ),
            .blockedPendingApproval
        )
    }
}
