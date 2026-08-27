import XCTest
@testable import AgentCore

final class AppActionCoordinatorTests: XCTestCase {
    private func draft(
        id: String,
        kind: AppActionDraft.ActionKind,
        payload: String,
        target: String = "example-target",
        classification: DataClassification = .publicDefault,
        risk: ActionRisk = .execute
    ) -> AppActionDraft {
        .init(
            id: UUID(uuidString: id)!,
            actionKind: kind,
            targetDescription: target,
            payloadSummary: payload,
            dataClassification: classification,
            actionRisk: risk
        )
    }

    func testPolicyBlockIsRespected() {
        let coordinator = AppActionCoordinator(approvalManager: .init(defaultStatus: .approved), auditLog: .init())
        XCTAssertEqual(coordinator.perform(draft(id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", kind: .sendMessage, payload: "msg", risk: .read), privacyMode: .localOnly), .rejected)
    }

    func testMissingApprovalBlocksExecution() {
        let coordinator = AppActionCoordinator(approvalManager: .init(defaultStatus: .approved))
        XCTAssertEqual(coordinator.perform(draft(id: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB", kind: .deleteRecord, payload: "delete"), privacyMode: .trustedDevices), .blockedPendingApproval)
    }

    func testRequiredApprovalRejectsNotRequiredManagerStatus() {
        let coordinator = AppActionCoordinator(approvalManager: .init(defaultStatus: .notRequired))
        let action = draft(id: "ABABABAB-ABAB-ABAB-ABAB-ABABABABABAB", kind: .deleteRecord, payload: "delete")

        switch coordinator.approvalEvaluation(for: action, privacyMode: .trustedDevices) {
        case .blocked(let reason):
            XCTAssertEqual(reason, "Approval receipt denied.")
        case .notRequired, .required:
            XCTFail("A required approval must not accept an ApprovalManager .notRequired result.")
        }

        XCTAssertNil(coordinator.approvalReceipt(for: action, privacyMode: .trustedDevices))
    }

    func testRequiredApprovalRejectsNotRequiredReceiptEvenWhenMayContinueRoutingIsTrue() {
        let coordinator = AppActionCoordinator(approvalManager: .init(defaultStatus: .approved))
        let action = draft(id: "CDCDCDCD-CDCD-CDCD-CDCD-CDCDCDCDCDCD", kind: .deleteRecord, payload: "delete")
        let invalidReceipt = AppActionApprovalReceipt(
            draftID: action.id,
            fingerprint: action.fingerprint,
            approvalReceipt: ApprovalReceipt(
                status: .notRequired,
                requestID: "synthetic-not-required",
                reasonCode: "synthetic regression receipt",
                mayContinueRouting: true
            )
        )

        XCTAssertEqual(
            coordinator.perform(action, privacyMode: .trustedDevices, approvalReceipt: invalidReceipt),
            .blockedPendingApproval
        )
    }

    func testApprovalEvaluationDistinguishesBlockedFromNotRequired() {
        let coordinator = AppActionCoordinator(approvalManager: .init(defaultStatus: .approved), auditLog: .init())
        let allowedDraft = draft(id: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF", kind: .deleteRecord, payload: "safe cleanup", risk: .read)
        let blockedDraft = draft(id: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF", kind: .sendMessage, payload: "Please use IBAN DE89 3704 0044 0532 0130 00", risk: .read)

        switch coordinator.approvalEvaluation(for: allowedDraft, privacyMode: .trustedDevices) {
        case .notRequired:
            break
        default:
            XCTFail("Expected notRequired for an allowed draft without approval requirement")
        }

        switch coordinator.approvalEvaluation(for: blockedDraft, privacyMode: .trustedDevices) {
        case .blocked(let reason):
            XCTAssertFalse(reason.isEmpty)
        default:
            XCTFail("Expected blocked for a sensitive draft")
        }
    }

    func testApprovalNotRequiredByPolicyBypassesApprovalManager() {
        let coordinator = AppActionCoordinator(approvalManager: .init(defaultStatus: .approved), auditLog: .init())
        let draft = draft(id: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF", kind: .deleteRecord, payload: "safe cleanup", risk: .read)

        XCTAssertNil(coordinator.approvalReceipt(for: draft, privacyMode: .trustedDevices))

        switch coordinator.perform(draft, privacyMode: .trustedDevices) {
        case .approved(let receipt):
            XCTAssertEqual(receipt.draftID, draft.id)
            XCTAssertEqual(receipt.fingerprint, draft.fingerprint)
            XCTAssertEqual(receipt.approvalReceipt.status, .notRequired)
            XCTAssertTrue(receipt.approvalReceipt.mayContinueRouting)
        default:
            XCTFail("Expected direct approval without an approval requirement")
        }
    }

    func testConfiguredApprovalPolicyCanRequireApprovalForFastPathAction() {
        let policy = AppActionApprovalPolicy(rules: [
            .init(actionKind: .sendMessage, requiresApproval: true, note: "Outbound messages should be reviewed."),
            .init(actionKind: .deleteRecord, requiresApproval: true),
            .init(actionKind: .updateRecord, requiresApproval: true),
            .init(actionKind: .exportData, requiresApproval: true)
        ])
        let coordinator = AppActionCoordinator(
            approvalManager: .init(defaultStatus: .approved),
            approvalPolicy: policy
        )
        let draft = draft(id: "DDDDDDDD-CCCC-BBBB-AAAA-EEEEEEEEEEEE", kind: .sendMessage, payload: "hello", risk: .read)

        let approval = coordinator.approvalReceipt(for: draft, privacyMode: .trustedDevices)
        XCTAssertNotNil(approval)
        XCTAssertEqual(coordinator.perform(draft, privacyMode: .trustedDevices), .blockedPendingApproval)
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

    func testChangedTargetInvalidatesReceipt() {
        let coordinator = AppActionCoordinator(approvalManager: .init(defaultStatus: .approved))
        let id = "11111111-2222-3333-4444-555555555555"
        let approval = coordinator.approvalReceipt(
            for: draft(id: id, kind: .deleteRecord, payload: "payload-a", target: "target-a"),
            privacyMode: .trustedDevices
        )

        XCTAssertNotNil(approval)
        XCTAssertEqual(
            coordinator.perform(
                draft(id: id, kind: .deleteRecord, payload: "payload-a", target: "target-b"),
                privacyMode: .trustedDevices,
                approvalReceipt: approval
            ),
            .blockedPendingApproval
        )
    }

    func testChangedRiskInvalidatesReceipt() {
        let coordinator = AppActionCoordinator(approvalManager: .init(defaultStatus: .approved))
        let id = "22222222-3333-4444-5555-666666666666"
        let approval = coordinator.approvalReceipt(
            for: draft(id: id, kind: .deleteRecord, payload: "payload-a", risk: .execute),
            privacyMode: .trustedDevices
        )

        XCTAssertNotNil(approval)
        XCTAssertEqual(
            coordinator.perform(
                draft(id: id, kind: .deleteRecord, payload: "payload-a", risk: .critical),
                privacyMode: .trustedDevices,
                approvalReceipt: approval
            ),
            .blockedPendingApproval
        )
    }

    func testChangedClassificationInvalidatesReceipt() {
        let coordinator = AppActionCoordinator(approvalManager: .init(defaultStatus: .approved))
        let id = "33333333-4444-5555-6666-777777777777"
        let approval = coordinator.approvalReceipt(
            for: draft(id: id, kind: .deleteRecord, payload: "payload-a", classification: .publicDefault),
            privacyMode: .trustedDevices
        )
        let highlyPrivate = DataClassification(
            level: .highlyPrivateData,
            reason: "Synthetic classification change for receipt invalidation testing."
        )

        XCTAssertNotNil(approval)
        XCTAssertEqual(
            coordinator.perform(
                draft(id: id, kind: .deleteRecord, payload: "payload-a", classification: highlyPrivate),
                privacyMode: .trustedDevices,
                approvalReceipt: approval
            ),
            .blockedPendingApproval
        )
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
