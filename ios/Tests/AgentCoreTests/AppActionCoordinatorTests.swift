import XCTest
@testable import AgentCore

final class AppActionCoordinatorTests: XCTestCase {
    private func draft(id: String, kind: AppActionDraft.ActionKind, payload: String, risk: ActionRisk = .execute) -> AppActionDraft {
        .init(id: UUID(uuidString: id)!, actionKind: kind, targetDescription: "example-target", payloadSummary: payload, dataClassification: .publicDefault, actionRisk: risk)
    }

    func testPolicyBlockIsRespected() {
        let coordinator = AppActionCoordinator(approvalManager: .init(defaultStatus: .approved), auditLog: .init())
        XCTAssertEqual(coordinator.perform(draft(id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", kind: .sendMessage, payload: "msg", risk: .read), privacyMode: .localOnly), .rejected)
    }

    func testMissingApprovalBlocksExecution() {
        let coordinator = AppActionCoordinator(approvalManager: .init(defaultStatus: .approved))
        XCTAssertEqual(coordinator.perform(draft(id: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB", kind: .deleteRecord, payload: "delete"), privacyMode: .trustedDevices), .blockedPendingApproval)
    }

    func testApprovedSyntheticDraftCreatesAuditEntryWithoutSideEffect() {
        let log = AuditLog(); let coordinator = AppActionCoordinator(approvalManager: .init(defaultStatus: .approved), auditLog: log)
        let draft = draft(id: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC", kind: .deleteRecord, payload: "payload-a")
        let approval = coordinator.approvalReceipt(for: draft, privacyMode: .trustedDevices)
        XCTAssertNotNil(approval)
        switch coordinator.perform(draft, privacyMode: .trustedDevices, approvalReceipt: approval) {
        case .approved(let receipt): XCTAssertEqual(receipt.draftID, draft.id)
        default: XCTFail("Expected approval")
        }
        XCTAssertTrue(log.count(ofType: .policyDecision) > 0)
        XCTAssertEqual(log.count(ofType: .routeSelected), 0)
    }

    func testChangedPayloadInvalidatesReceipt() {
        let coordinator = AppActionCoordinator(approvalManager: .init(defaultStatus: .approved))
        let id = "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD"
        let approval = coordinator.approvalReceipt(for: draft(id: id, kind: .deleteRecord, payload: "payload-a"), privacyMode: .trustedDevices)
        XCTAssertEqual(coordinator.perform(draft(id: id, kind: .deleteRecord, payload: "payload-b"), privacyMode: .trustedDevices, approvalReceipt: approval), .blockedPendingApproval)
    }

    func testSensitivePayloadEscalatesClassificationAndBlocksExternalDelegation() {
        let log = AuditLog()
        let coordinator = AppActionCoordinator(approvalManager: .init(defaultStatus: .approved), auditLog: log)
        let benignDraft = draft(id: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE", kind: .sendMessage, payload: "hello there", risk: .read)
        let sensitiveDraft = draft(id: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF", kind: .sendMessage, payload: "Please use IBAN DE89 3704 0044 0532 0130 00", risk: .read)

        let benignApproval = coordinator.approvalReceipt(for: benignDraft, privacyMode: .trustedDevices)
        XCTAssertNotNil(benignApproval)
        XCTAssertEqual(coordinator.perform(benignDraft, privacyMode: .trustedDevices, approvalReceipt: benignApproval), .approved(benignApproval!))

        XCTAssertNil(coordinator.approvalReceipt(for: sensitiveDraft, privacyMode: .trustedDevices))
        XCTAssertEqual(coordinator.perform(sensitiveDraft, privacyMode: .trustedDevices), .rejected)

        let blockedEvents = log.allEvents().filter { $0.type == .blocked }
        XCTAssertTrue(blockedEvents.contains(where: { $0.dataSensitivity == .restrictedSensitiveData }))
    }
}
