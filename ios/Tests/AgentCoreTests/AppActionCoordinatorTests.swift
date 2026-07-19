import XCTest
@testable import AgentCore

final class AppActionCoordinatorTests: XCTestCase {
    func testPolicyBlockIsRespected() {
        let auditLog = AuditLog()
        let coordinator = AppActionCoordinator(
            approvalManager: ApprovalManager(defaultStatus: .approved),
            auditLog: auditLog
        )
        let draft = AppActionDraft(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            actionKind: .sendMessage,
            targetDescription: "example-contact",
            payloadSummary: "synthetic message",
            dataClassification: .publicDefault,
            actionRisk: .read
        )

        let outcome = coordinator.perform(draft, privacyMode: .localOnly)

        XCTAssertEqual(outcome, .rejected)
        XCTAssertTrue(auditLog.allEvents().contains { $0.type == .blocked })
    }

    func testMissingApprovalBlocksExecution() {
        let coordinator = AppActionCoordinator(
            approvalManager: ApprovalManager(defaultStatus: .approved)
        )
        let draft = AppActionDraft(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            actionKind: .deleteRecord,
            targetDescription: "example-record-001",
            payloadSummary: "synthetic delete payload",
            dataClassification: .publicDefault,
            actionRisk: .execute
        )

        let outcome = coordinator.perform(draft, privacyMode: .trustedDevices)

        XCTAssertEqual(outcome, .blockedPendingApproval)
    }

    func testApprovedSyntheticDraftCreatesAuditEntryWithoutSideEffect() {
        let auditLog = AuditLog()
        let coordinator = AppActionCoordinator(
            approvalManager: ApprovalManager(defaultStatus: .approved),
            auditLog: auditLog
        )
        let draft = AppActionDraft(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            actionKind: .deleteRecord,
            targetDescription: "example-record-002",
            payloadSummary: "synthetic delete payload",
            dataClassification: .publicDefault,
            actionRisk: .execute
        )

        let approvalReceipt = coordinator.approvalReceipt(for: draft, privacyMode: .trustedDevices)
        XCTAssertNotNil(approvalReceipt)

        let outcome = coordinator.perform(
            draft,
            privacyMode: .trustedDevices,
            approvalReceipt: approvalReceipt
        )

        switch outcome {
        case let .approved(receipt):
            XCTAssertEqual(receipt.draftID, draft.id)
            XCTAssertEqual(receipt.actionKind, draft.actionKind)
        default:
            XCTFail("Expected approved outcome")
        }

        XCTAssertGreaterThan(auditLog.allEvents().count, 0)
        XCTAssertFalse(auditLog.allEvents().contains { $0.type == .blocked })
        XCTAssertEqual(auditLog.count(ofType: .routeSelected), 0)
    }

    func testChangedPayloadInvalidatesReceipt() {
        let coordinator = AppActionCoordinator(
            approvalManager: ApprovalManager(defaultStatus: .approved)
        )
        let sharedID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
        let approvedDraft = AppActionDraft(
            id: sharedID,
            actionKind: .deleteRecord,
            targetDescription: "example-record-003",
            payloadSummary: "payload-a",
            dataClassification: .publicDefault,
            actionRisk: .execute
        )
        let staleReceipt = coordinator.approvalReceipt(for: approvedDraft, privacyMode: .trustedDevices)
        XCTAssertNotNil(staleReceipt)

        let changedDraft = AppActionDraft(
            id: sharedID,
            actionKind: .deleteRecord,
            targetDescription: "example-record-003",
            payloadSummary: "payload-b",
            dataClassification: .publicDefault,
            actionRisk: .execute
        )

        let outcome = coordinator.perform(
            changedDraft,
            privacyMode: .trustedDevices,
            approvalReceipt: staleReceipt
        )

        XCTAssertEqual(outcome, .blockedPendingApproval)
    }
}
