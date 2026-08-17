import XCTest
@testable import AgentCore

final class AppActionApprovalFloorTests: XCTestCase {
    private func draft(
        id: String,
        kind: AppActionDraft.ActionKind,
        payload: String = "synthetic-safe-payload",
        classification: DataClassification = .publicDefault,
        risk: ActionRisk = .read
    ) -> AppActionDraft {
        .init(
            id: UUID(uuidString: id)!,
            actionKind: kind,
            targetDescription: "synthetic-target",
            payloadSummary: payload,
            dataClassification: classification,
            actionRisk: risk
        )
    }

    private func policy(
        for actionKind: AppActionDraft.ActionKind,
        requiresApproval: Bool
    ) -> AppActionApprovalPolicy {
        .init(rules: [
            .init(actionKind: actionKind, requiresApproval: requiresApproval)
        ])
    }

    func testSetupDefaultCannotWaiveExternalProviderApprovalForSendMessage() {
        let coordinator = AppActionCoordinator(
            approvalManager: .init(defaultStatus: .approved),
            approvalPolicy: .setupDefault
        )
        let candidate = draft(
            id: "11111111-1111-1111-1111-111111111111",
            kind: .sendMessage,
            risk: .read
        )

        XCTAssertNotNil(coordinator.approvalReceipt(for: candidate, privacyMode: .trustedDevices))
        XCTAssertEqual(
            coordinator.perform(candidate, privacyMode: .trustedDevices),
            .blockedPendingApproval
        )
    }

    func testConfiguredFalseCannotWaiveRiskBasedApprovalFloor() {
        let coordinator = AppActionCoordinator(
            approvalManager: .init(defaultStatus: .approved),
            approvalPolicy: policy(for: .deleteRecord, requiresApproval: false)
        )
        let risks: [ActionRisk] = [.execute, .destructive, .externalShare, .critical]

        for (index, risk) in risks.enumerated() {
            let candidate = draft(
                id: String(format: "22222222-2222-2222-2222-%012d", index + 1),
                kind: .deleteRecord,
                risk: risk
            )

            XCTAssertNotNil(
                coordinator.approvalReceipt(for: candidate, privacyMode: .trustedDevices),
                "Expected PolicyEngine approval floor for risk \(risk.rawValue)"
            )
            XCTAssertEqual(
                coordinator.perform(candidate, privacyMode: .trustedDevices),
                .blockedPendingApproval,
                "Configured false must not waive risk \(risk.rawValue)"
            )
        }
    }

    func testConfiguredFalseCannotWaiveHighlyPrivateDataApprovalFloor() {
        let coordinator = AppActionCoordinator(
            approvalManager: .init(defaultStatus: .approved),
            approvalPolicy: policy(for: .deleteRecord, requiresApproval: false)
        )
        let highlyPrivate = DataClassification(
            level: .highlyPrivateData,
            reason: "Synthetic high-private regression fixture."
        )
        let candidate = draft(
            id: "33333333-3333-3333-3333-333333333333",
            kind: .deleteRecord,
            classification: highlyPrivate,
            risk: .read
        )

        XCTAssertNotNil(coordinator.approvalReceipt(for: candidate, privacyMode: .trustedDevices))
        XCTAssertEqual(
            coordinator.perform(candidate, privacyMode: .trustedDevices),
            .blockedPendingApproval
        )
    }

    func testConfiguredTrueCanAddApprovalToOtherwiseFastPathAction() {
        let coordinator = AppActionCoordinator(
            approvalManager: .init(defaultStatus: .approved),
            approvalPolicy: policy(for: .updateRecord, requiresApproval: true)
        )
        let candidate = draft(
            id: "44444444-4444-4444-4444-444444444444",
            kind: .updateRecord,
            risk: .read
        )

        XCTAssertNotNil(coordinator.approvalReceipt(for: candidate, privacyMode: .trustedDevices))
        XCTAssertEqual(
            coordinator.perform(candidate, privacyMode: .trustedDevices),
            .blockedPendingApproval
        )
    }

    func testConfiguredFalseCannotBypassPolicyBlock() {
        let coordinator = AppActionCoordinator(
            approvalManager: .init(defaultStatus: .approved),
            approvalPolicy: policy(for: .sendMessage, requiresApproval: false)
        )
        let candidate = draft(
            id: "55555555-5555-5555-5555-555555555555",
            kind: .sendMessage,
            risk: .read
        )

        switch coordinator.approvalEvaluation(for: candidate, privacyMode: .localOnly) {
        case .blocked(let reason):
            XCTAssertFalse(reason.isEmpty)
        default:
            XCTFail("Expected PolicyEngine block to remain authoritative")
        }
        XCTAssertEqual(coordinator.perform(candidate, privacyMode: .localOnly), .rejected)
    }

    func testApprovalReceiptRemainsBoundToExactDraft() {
        let coordinator = AppActionCoordinator(
            approvalManager: .init(defaultStatus: .approved),
            approvalPolicy: policy(for: .deleteRecord, requiresApproval: false)
        )
        let id = "66666666-6666-6666-6666-666666666666"
        let original = draft(
            id: id,
            kind: .deleteRecord,
            payload: "original-payload",
            risk: .execute
        )
        let receipt = coordinator.approvalReceipt(for: original, privacyMode: .trustedDevices)
        let changed = draft(
            id: id,
            kind: .deleteRecord,
            payload: "changed-payload",
            risk: .execute
        )

        XCTAssertNotNil(receipt)
        XCTAssertEqual(
            coordinator.perform(
                changed,
                privacyMode: .trustedDevices,
                approvalReceipt: receipt
            ),
            .blockedPendingApproval
        )
    }
}
